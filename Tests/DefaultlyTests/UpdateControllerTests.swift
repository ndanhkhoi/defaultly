import DefaultlyCore
import Foundation
import Testing
@testable import Defaultly

/// The update state machine, with a fake release feed, installer, window and relaunch.
@MainActor
struct UpdateControllerTests {
    @Test func anAutomaticCheckOffersANewVersionInTheWindow() async {
        let harness = Harness()
        harness.controller.checkIfDue()
        #expect(harness.controller.phase == .checking)
        await harness.finishWork()
        #expect(harness.availableVersion == "1.1.0")
        #expect(harness.presenter.shows == 1)
    }

    @Test(arguments: [false, true])
    func anAutomaticCheckStaysQuietWhenUpToDateOrOffline(offline: Bool) async {
        let harness = Harness(releases: offline ? .failure(.server(status: 503)) : .success([Harness.release("1.0.0")]))
        harness.controller.checkIfDue()
        await harness.finishWork()
        #expect(harness.controller.phase == .idle)
        #expect(harness.presenter.shows == 0)
    }

    @Test func checksAtMostOnceADay() async {
        let harness = Harness(releases: .success([]))
        harness.controller.checkIfDue()
        await harness.finishWork()
        harness.controller.checkIfDue()
        #expect(harness.controller.work == nil)
        harness.controller.checkIfDue(now: .now.addingTimeInterval(UpdateSchedule.interval + 60))
        #expect(harness.controller.phase == .checking)
        await harness.finishWork()
    }

    @Test func skippedVersionsStayQuietUnlessAskedFor() async {
        let harness = Harness()
        harness.controller.checkIfDue()
        await harness.finishWork()
        harness.controller.skip()
        #expect(harness.controller.phase == .idle)

        harness.controller.checkIfDue(now: .now.addingTimeInterval(UpdateSchedule.interval + 60))
        await harness.finishWork()
        #expect(harness.controller.phase == .idle)
        #expect(harness.presenter.shows == 1)

        harness.controller.checkNow()
        await harness.finishWork()
        #expect(harness.availableVersion == "1.1.0")
    }

    @Test func cancelStopsAnAutomaticCheckWithoutOpeningTheWindow() async {
        let harness = Harness(sourceDelay: .seconds(10))
        harness.controller.checkIfDue()
        harness.controller.cancel()
        await harness.finishWork()
        #expect(harness.controller.phase == .idle)
        #expect(harness.presenter.shows == 0)
        #expect(harness.controller.lastCheck == nil)
    }

    @Test func aBackgroundDownloadWaitsForQuit() async {
        let harness = Harness(automaticallyInstalls: true)
        harness.controller.checkIfDue()
        // Restarting the timer, as reopening the main window does, doesn't stop the download.
        harness.controller.start()
        await harness.finishWork()
        #expect(harness.isReady)
        #expect(harness.presenter.shows == 0)
        #expect(harness.installer.installs == 0)
        harness.controller.installOnQuit()
        #expect(harness.installer.installs == 1)
    }

    @Test(arguments: [false, true])
    func turningAutomaticInstallsOffDropsTheBackgroundDownload(viaChecks: Bool) async {
        let harness = Harness(automaticallyInstalls: true)
        harness.controller.checkIfDue()
        await harness.finishWork()
        #expect(harness.isReady)
        if viaChecks { harness.controller.automaticallyChecks = false } else { harness.controller.automaticallyInstalls = false }
        #expect(harness.controller.phase == .idle)
        harness.controller.installOnQuit()
        #expect(harness.installer.installs == 0)
    }

    @Test func installRunsOnceThenRelaunches() async {
        let harness = Harness()
        harness.controller.checkNow()
        await harness.finishWork()
        harness.controller.install()
        harness.controller.install()
        await harness.finishWork()
        #expect(harness.installer.prepares == 1)
        #expect(harness.installer.installs == 1)
        #expect(harness.relauncher.count == 1)
        #expect(harness.controller.phase == .installed(AppVersion("1.1.0")!))
        #expect(!harness.presenter.isVisible)
    }

    @Test func aFailedRelaunchSaysTheUpdateIsInstalled() async {
        let harness = Harness(relaunchFails: true)
        harness.controller.checkNow()
        await harness.finishWork()
        harness.controller.install()
        await harness.finishWork()
        #expect(harness.controller.phase == .installed(AppVersion("1.1.0")!))
        #expect(harness.presenter.isVisible)
    }

    @Test func aFailedInstallIsShownEvenAfterTheWindowWasClosed() async {
        let harness = Harness(prepareError: .checksumMismatch)
        harness.controller.checkNow()
        await harness.finishWork()
        harness.controller.install()
        harness.controller.dismiss()
        await harness.finishWork()
        guard case .failed(_, let update) = harness.controller.phase else {
            Issue.record("expected a failure, got \(harness.controller.phase)")
            return
        }
        #expect(update?.release.version == AppVersion("1.1.0"))
        #expect(harness.presenter.isVisible)
        #expect(harness.installer.installs == 0)
    }

    @Test func closingTheWindowMidDownloadAsksBeforeRelaunching() async {
        let harness = Harness()
        harness.controller.checkNow()
        await harness.finishWork()
        harness.controller.install()
        harness.controller.dismiss()
        await harness.finishWork()
        #expect(harness.isReady)
        #expect(harness.presenter.isVisible)
        #expect(harness.installer.installs == 0)
        #expect(harness.relauncher.count == 0)
        // "Install on Quit" keeps its promise, whatever the automatic settings say.
        harness.controller.automaticallyInstalls = true
        harness.controller.automaticallyInstalls = false
        harness.controller.automaticallyChecks = false
        #expect(harness.isReady)
        harness.controller.installOnQuit()
        #expect(harness.installer.installs == 1)
    }

    @Test func reopeningTheWindowMidDownloadStillRelaunches() async {
        let harness = Harness(prepareDelay: .milliseconds(50))
        harness.controller.checkNow()
        await harness.finishWork()
        harness.controller.install()
        harness.controller.dismiss()
        harness.controller.checkNow()
        await harness.finishWork()
        #expect(harness.installer.installs == 1)
        #expect(harness.relauncher.count == 1)
    }

    @Test func aFailedInstallOnQuitIsExplainedAtTheNextLaunch() async {
        let defaults = Harness.defaults()
        let quitting = Harness(installError: .invalidSignature, automaticallyInstalls: true, defaults: defaults)
        quitting.controller.checkIfDue()
        await quitting.finishWork()
        quitting.controller.installOnQuit()
        #expect(quitting.installer.installs == 1)

        let relaunched = Harness(automaticallyInstalls: true, defaults: defaults)
        relaunched.controller.checkIfDue()
        await relaunched.finishWork()
        guard case .failed(_, let update) = relaunched.controller.phase else {
            Issue.record("expected the failure, got \(relaunched.controller.phase)")
            return
        }
        #expect(update?.release.version == AppVersion("1.1.0"))
        #expect(relaunched.presenter.isVisible)
        #expect(relaunched.installer.prepares == 0)

        // Shown once: the next check downloads it again.
        relaunched.controller.dismiss()
        relaunched.controller.checkIfDue(now: .now.addingTimeInterval(UpdateSchedule.interval + 60))
        await relaunched.finishWork()
        #expect(relaunched.isReady)
    }

    @Test func aFailedInstallOnQuitIsExplainedEvenWithAutomaticChecksOffAndTheVersionSkipped() async {
        let defaults = Harness.defaults()
        let quitting = Harness(installError: .invalidSignature, defaults: defaults)
        quitting.controller.checkIfDue()
        await quitting.finishWork()
        quitting.controller.skip()
        quitting.controller.checkNow()
        await quitting.finishWork()
        quitting.controller.install()
        quitting.controller.dismiss()
        await quitting.finishWork()
        quitting.controller.automaticallyChecks = false
        quitting.controller.installOnQuit()
        #expect(quitting.installer.installs == 1)

        let relaunched = Harness(defaults: defaults)
        relaunched.controller.checkIfDue()
        await relaunched.finishWork()
        guard case .failed(_, let update) = relaunched.controller.phase else {
            Issue.record("expected the failure, got \(relaunched.controller.phase)")
            return
        }
        #expect(update?.release.version == AppVersion("1.1.0"))

        // Shown once: automatic checks stay off after that.
        relaunched.controller.dismiss()
        relaunched.controller.checkIfDue(now: .now.addingTimeInterval(UpdateSchedule.interval + 60))
        #expect(relaunched.controller.phase == .idle)
    }

    @Test func cancellingADownloadOffersTheUpdateAgain() async {
        let harness = Harness(prepareDelay: .seconds(10))
        harness.controller.checkNow()
        await harness.finishWork()
        harness.controller.install()
        harness.controller.cancel()
        await harness.finishWork()
        #expect(harness.availableVersion == "1.1.0")
        #expect(harness.installer.installs == 0)
    }

    @Test func relaunchingForALanguageInstallsAReadyUpdateFirst() async {
        let harness = Harness(automaticallyInstalls: true)
        harness.controller.checkIfDue()
        await harness.finishWork()
        harness.controller.relaunchApp()
        #expect(harness.installer.installs == 1)
        #expect(harness.relauncher.count == 1)
    }

    @Test func whatsNewOnlyAfterAnUpdate() {
        #expect(Harness(current: "1.1.0", lastLaunched: "1.0.0").controller.takeWhatsNew())
        #expect(!Harness(current: "1.1.0", lastLaunched: nil).controller.takeWhatsNew())
        #expect(!Harness(current: "1.1.0", lastLaunched: "1.1.0").controller.takeWhatsNew())
        let updated = Harness(current: "1.1.0", lastLaunched: "1.0.0").controller
        #expect(updated.takeWhatsNew())
        #expect(!updated.takeWhatsNew())
    }
}

// MARK: - Fakes

@MainActor
private struct Harness {
    let controller: UpdateController
    let presenter = FakePresenter()
    let installer: FakeInstaller
    let relauncher: FakeRelauncher

    init(
        current: String = "1.0.0",
        releases: Result<[Release], UpdateError> = .success([release("1.1.0"), release("1.0.0")]),
        sourceDelay: Duration = .zero,
        prepareDelay: Duration = .zero,
        prepareError: UpdateError? = nil,
        installError: UpdateError? = nil,
        automaticallyInstalls: Bool = false,
        relaunchFails: Bool = false,
        lastLaunched: String? = nil,
        defaults: UserDefaults = Harness.defaults()
    ) {
        let preferences = UpdatePreferences(defaults: defaults)
        preferences.automaticallyInstalls = automaticallyInstalls
        preferences.lastLaunchedVersion = lastLaunched.flatMap(AppVersion.init)
        let app = FileManager.default.temporaryDirectory.appendingPathComponent("defaultly-controller-\(UUID().uuidString)/Defaultly.app")
        try? FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        installer = FakeInstaller(delay: prepareDelay, error: prepareError, installError: installError)
        relauncher = FakeRelauncher(fails: relaunchFails)
        let relauncher = relauncher
        controller = UpdateController(
            currentVersion: AppVersion(current),
            appURL: app,
            source: FakeFeed(releases: releases, delay: sourceDelay),
            installer: installer,
            preferences: preferences,
            presenter: presenter,
            relaunch: { relauncher.relaunch(onFailure: $0) }
        )
    }

    var availableVersion: String? {
        if case .available(let update) = controller.phase { update.release.version.description } else { nil }
    }

    var isReady: Bool {
        if case .ready = controller.phase { true } else { false }
    }

    func finishWork() async {
        await controller.work?.value
    }

    /// Fresh defaults; pass the same ones to a second harness to stand for the next launch.
    static func defaults() -> UserDefaults {
        UserDefaults(suiteName: "defaultly-tests-\(UUID().uuidString)")!
    }

    static func release(_ version: String) -> Release {
        let base = URL(string: "https://example.com/v\(version)/")!
        return Release(
            version: AppVersion(version)!, notes: "- Changes in \(version)", publishedAt: nil, pageURL: base,
            archiveURL: base.appendingPathComponent("Defaultly-\(version).zip"),
            checksumsURL: base.appendingPathComponent("SHA256SUMS.txt")
        )
    }
}

@MainActor
private final class FakePresenter: UpdatePresenting {
    var onClose: (@MainActor () -> Void)?
    private(set) var shows = 0
    private(set) var isVisible = false

    func show(_ controller: UpdateController) {
        shows += 1
        isVisible = true
    }

    func close() {
        guard isVisible else { return }
        isVisible = false
        onClose?()
    }
}

@MainActor
private final class FakeRelauncher {
    let fails: Bool
    private(set) var count = 0

    init(fails: Bool) {
        self.fails = fails
    }

    func relaunch(onFailure: @escaping @MainActor () -> Void) {
        count += 1
        if fails { onFailure() }
    }
}

private struct FakeFeed: ReleaseSource {
    let releases: Result<[Release], UpdateError>
    let delay: Duration

    func releases() async throws -> [Release] {
        try await Task.sleep(for: delay)
        return try releases.get()
    }

    func data(from url: URL) async throws -> Data { throw UpdateError.server(status: 404) }

    func download(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        throw UpdateError.server(status: 404)
    }
}

private final class FakeInstaller: UpdateInstalling, @unchecked Sendable {
    private let delay: Duration
    private let error: UpdateError?
    private let installError: UpdateError?
    private let lock = NSLock()
    private var prepareCount = 0
    private var installCount = 0

    init(delay: Duration, error: UpdateError?, installError: UpdateError?) {
        self.delay = delay
        self.error = error
        self.installError = installError
    }

    var prepares: Int { lock.withLock { prepareCount } }
    var installs: Int { lock.withLock { installCount } }

    func prepare(_ release: Release, progress: @escaping @Sendable (Double) -> Void) async throws -> PreparedUpdate {
        lock.withLock { prepareCount += 1 }
        try await Task.sleep(for: delay)
        if let error { throw error }
        progress(1)
        return PreparedUpdate(release: release, appURL: URL(fileURLWithPath: "/nonexistent/staged/Defaultly.app"))
    }

    func install(_ update: PreparedUpdate, replacing appURL: URL) throws {
        lock.withLock { installCount += 1 }
        if let installError { throw installError }
    }
}
