import AppKit
import DefaultlyCore
import Foundation
import Observation

/// Shows the controller's state; `UpdateWindow` in the app, a fake in tests.
@MainActor
protocol UpdatePresenting: AnyObject {
    /// Called when the window closes, whether the user closed it or `close()` did.
    var onClose: (@MainActor () -> Void)? { get set }
    func show(_ controller: UpdateController)
    func close()
}

/// Starts a new instance of the app; calls `onFailure` if it couldn't.
typealias Relauncher = @MainActor (_ onFailure: @escaping @MainActor () -> Void) -> Void

/// Checks for, downloads and installs new versions, and owns the Software Update window.
///
/// Automatic checks run at most once a day and stay silent unless there is an update. The user decides whether
/// to install it, unless they turned on automatic installs: then it is downloaded and verified in the background
/// and installed when the app quits. Every check and download runs as the single `work` task, so Cancel always
/// reaches it and two can never overlap.
@Observable
@MainActor
final class UpdateController {
    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(AvailableUpdate)
        /// `progress` is nil once the download is being verified and unpacked.
        case installing(AvailableUpdate, progress: Double?)
        /// Downloaded and verified, in the background or while the window was closed; installed when the app quits.
        case ready(PreparedUpdate, AvailableUpdate)
        /// Installed, but the new version couldn't be started.
        case installed(AppVersion)
        case failed(String, AvailableUpdate?)
    }

    private(set) var phase: Phase = .idle
    private(set) var lastCheck: Date?

    var automaticallyChecks: Bool {
        didSet {
            preferences.automaticallyChecks = automaticallyChecks
            if !automaticallyChecks { dropBackgroundUpdate() }
            start()
        }
    }

    var automaticallyInstalls: Bool {
        didSet {
            preferences.automaticallyInstalls = automaticallyInstalls
            if !automaticallyInstalls { dropBackgroundUpdate() }
        }
    }

    /// Nil when the running build has no version, such as `swift run`: there is nothing to update then.
    let currentVersion: AppVersion?
    /// Why this copy can't replace itself; updates are then offered as a download.
    let installProblem: InstallLocationProblem?

    /// The running check or download. Set exactly while the phase is `checking` or `installing`.
    @ObservationIgnored private(set) var work: Task<Void, Never>?
    @ObservationIgnored private let appURL: URL
    @ObservationIgnored private let source: any ReleaseSource
    @ObservationIgnored private let installer: any UpdateInstalling
    @ObservationIgnored private let preferences: UpdatePreferences
    @ObservationIgnored private let presenter: any UpdatePresenting
    @ObservationIgnored private let relaunch: Relauncher
    @ObservationIgnored private var schedule: Task<Void, Never>?
    /// The user is looking at the window, so results and errors are shown rather than kept quiet.
    @ObservationIgnored private var isInteractive = false
    /// The `ready` update was asked for with Install and Relaunch, so changing the automatic settings keeps it.
    @ObservationIgnored private var readyWasRequested = false
    @ObservationIgnored private var whatsNewPending: Bool

    init(
        currentVersion: AppVersion?,
        appURL: URL,
        source: any ReleaseSource,
        installer: any UpdateInstalling,
        preferences: UpdatePreferences,
        presenter: any UpdatePresenting,
        relaunch: @escaping Relauncher
    ) {
        self.currentVersion = currentVersion
        self.appURL = appURL
        self.source = source
        self.installer = installer
        self.preferences = preferences
        self.presenter = presenter
        self.relaunch = relaunch
        installProblem = UpdateInstaller.problem(installingAt: appURL)
        automaticallyChecks = preferences.automaticallyChecks
        automaticallyInstalls = preferences.automaticallyInstalls
        lastCheck = preferences.lastCheck

        let previous = preferences.lastLaunchedVersion
        whatsNewPending = if let previous, let currentVersion { currentVersion > previous } else { false }
        if let currentVersion { preferences.lastLaunchedVersion = currentVersion }

        presenter.onClose = { [weak self] in self?.windowDidClose() }
        _ = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.installOnQuit() }
        }
    }

    /// Starts, or restarts, the timer for daily automatic checks. Never interrupts a running check or download.
    func start() {
        schedule?.cancel()
        guard checksAutomatically, currentVersion != nil else { return }
        schedule = Task { [weak self] in
            // Let the main window and the first scan settle first.
            try? await Task.sleep(for: .seconds(5))
            // Holds the controller only while checking, so the loop ends once the controller is gone.
            while !Task.isCancelled, self != nil {
                self?.checkIfDue()
                try? await Task.sleep(for: .seconds(3600))
            }
        }
    }

    /// Starts an automatic check when one is due and nothing else is going on.
    func checkIfDue(now: Date = .now) {
        guard checksAutomatically, phase == .idle, UpdateSchedule.isDue(lastCheck: lastCheck, now: now) else { return }
        begin(.checking) { await $0.check() }
    }

    /// While turned on, and once after an install on quit failed, even if turned off since: to say why.
    private var checksAutomatically: Bool {
        automaticallyChecks || preferences.installFailure != nil
    }

    /// True once, on the first launch after an update (not after a fresh install).
    func takeWhatsNew() -> Bool {
        defer { whatsNewPending = false }
        return whatsNewPending
    }

    // MARK: - User actions

    /// Check for Updates…: shows the window, checking unless there is already something to show.
    func checkNow() {
        guard currentVersion != nil else { return }
        isInteractive = true
        switch phase {
        case .idle, .upToDate, .failed:
            begin(.checking) { await $0.check() }
        case .checking, .available, .installing, .ready, .installed:
            break
        }
        presenter.show(self)
    }

    /// Downloads, verifies and installs the available update, then relaunches.
    func install() {
        guard case .available(let update) = phase, installProblem == nil else { return }
        isInteractive = true
        begin(.installing(update, progress: 0)) { await $0.download(update, relaunching: true) }
    }

    /// Installs a background download now instead of on quit.
    func relaunchNow() {
        guard case .ready(let prepared, let update) = phase else { return }
        do {
            try finish(prepared)
        } catch {
            fail(error, update)
        }
    }

    /// Relaunches the app, for example to switch languages. A downloaded update is installed first, so the new
    /// instance runs it and quitting this one doesn't replace the bundle under it.
    func relaunchApp() {
        if case .ready = phase {
            relaunchNow()
        } else {
            relaunch {}
        }
    }

    func skip() {
        if case .available(let update) = phase { preferences.skippedVersion = update.release.version }
        dismiss()
    }

    func cancel() {
        work?.cancel()
    }

    func dismiss() {
        presenter.close()
    }

    func openReleasePage(_ update: AvailableUpdate?) {
        NSWorkspace.shared.open(update?.release.pageURL ?? ProjectLinks.releases)
        dismiss()
    }

    /// Quitting installs a download that is ready. Turning automatic installs or checks off drops a background
    /// download first, but not one asked for with Install and Relaunch.
    func installOnQuit() {
        guard case .ready(let prepared, _) = phase, installProblem == nil else { return }
        do {
            try installer.install(prepared, replacing: appURL)
        } catch {
            // Nothing can be shown while quitting: the next launch checks right away and says why.
            preferences.installFailure = error.localizedDescription
            preferences.lastCheck = nil
        }
    }

    #if DEBUG
    /// Shows a phase without checking or downloading, for `SmokeTest`.
    func showForSmokeTest(_ phase: Phase?) {
        guard let phase else {
            dismiss()
            self.phase = .idle
            return
        }
        self.phase = phase
        presenter.show(self)
    }
    #endif

    // MARK: - Checking and installing

    /// Runs `job` as the only check or download; does nothing while one is running.
    private func begin(_ phase: Phase, _ job: @escaping @MainActor (UpdateController) async -> Void) {
        guard work == nil else { return }
        self.phase = phase
        work = Task { [weak self] in
            guard let self else { return }
            await job(self)
            work = nil
        }
    }

    private func check() async {
        guard let currentVersion else { return }
        do {
            let releases = try await source.releases()
            try Task.checkCancellation()
            lastCheck = .now
            preferences.lastCheck = lastCheck
            let installFailure = preferences.installFailure
            preferences.installFailure = nil
            // Asking by hand, or having tried to install it, shows a skipped version again.
            let skipped = isInteractive || installFailure != nil ? nil : preferences.skippedVersion
            guard let update = AvailableUpdate(releases: releases, current: currentVersion, skipping: skipped) else {
                phase = isInteractive ? .upToDate : .idle
                return
            }
            if let installFailure {
                // Installing it on quit failed last time: say why instead of quietly downloading it again.
                phase = .failed(installFailure, update)
                presenter.show(self)
            } else if !isInteractive, automaticallyInstalls, installProblem == nil {
                await download(update, relaunching: false)
            } else {
                phase = .available(update)
                presenter.show(self)
            }
        } catch {
            if isInteractive, !Self.isCancellation(error) {
                phase = .failed(error.localizedDescription, nil)
            } else {
                phase = .idle
            }
        }
    }

    private func download(_ update: AvailableUpdate, relaunching: Bool) async {
        phase = .installing(update, progress: 0)
        do {
            // The closure only lives as long as the download.
            let prepared = try await installer.prepare(update.release) { fraction in
                Task { @MainActor in self.report(fraction, for: update) }
            }
            try Task.checkCancellation()
            if relaunching, isInteractive {
                try finish(prepared)
            } else {
                phase = .ready(prepared, update)
                readyWasRequested = relaunching
                // The window was closed while downloading: ask before relaunching rather than quitting unannounced.
                if relaunching { presenter.show(self) }
            }
        } catch let error where Self.isCancellation(error) {
            // Cancelled from the window: offer it again. A background download just stops.
            phase = isInteractive ? .available(update) : .idle
        } catch {
            if relaunching || isInteractive {
                fail(error, update)
            } else {
                phase = .idle
            }
        }
    }

    private func report(_ fraction: Double, for update: AvailableUpdate) {
        guard case .installing(let current, _) = phase, current == update else { return }
        phase = .installing(update, progress: fraction < 1 ? fraction : nil)
    }

    /// Installs, then starts the new version. If it can't start, the window says the update is installed.
    private func finish(_ prepared: PreparedUpdate) throws {
        try installer.install(prepared, replacing: appURL)
        phase = .installed(prepared.release.version)
        dismiss()
        relaunch { [weak self] in
            guard let self else { return }
            presenter.show(self)
        }
    }

    /// A failure the user asked about is shown, even if they closed the window in the meantime.
    private func fail(_ error: any Error, _ update: AvailableUpdate?) {
        phase = .failed(error.localizedDescription, update)
        presenter.show(self)
    }

    private func dropBackgroundUpdate() {
        if case .ready = phase, !readyWasRequested { phase = .idle }
    }

    private func windowDidClose() {
        isInteractive = false
        switch phase {
        case .upToDate, .failed, .available:
            phase = .idle
        case .idle, .checking, .installing, .ready, .installed:
            break
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}

extension InstallLocationProblem {
    var message: String {
        switch self {
        case .notAnApp:
            String(localized: "Updates can only be installed into the Defaultly app.")
        case .translocated:
            String(localized: "Move Defaultly to your Applications folder to install updates. macOS is running it from a temporary copy.")
        case .readOnly:
            String(localized: "You don't have permission to replace Defaultly where it is. Download the update instead.")
        }
    }
}
