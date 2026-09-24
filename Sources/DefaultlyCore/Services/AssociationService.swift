import Foundation

/// Reads and changes which app opens each format, verifying every change.
public struct AssociationService: Sendable {
    private let launchServices: any LaunchServicesClient
    private let apps: any AppLocating
    private let verificationTimeout: Duration

    /// `verificationTimeout` bounds how long to wait for LaunchServices to report a change.
    public init(launchServices: any LaunchServicesClient, apps: any AppLocating, verificationTimeout: Duration = .seconds(3)) {
        self.launchServices = launchServices
        self.apps = apps
        self.verificationTimeout = verificationTimeout
    }

    public func statuses(for extensions: [FileExtension]) -> [FileExtension: FormatStatus] {
        var cache: [URL: AppInfo?] = [:]
        func resolve(_ url: URL) -> AppInfo? {
            if let cached = cache[url] { return cached }
            let app = apps.app(at: url)
            cache[url] = app
            return app
        }

        var result: [FileExtension: FormatStatus] = [:]
        for ext in extensions {
            var seen = Set<String>()
            let candidates = launchServices.applications(for: ext)
                .compactMap(resolve)
                .filter { seen.insert($0.bundleID).inserted }
            result[ext] = FormatStatus(
                current: launchServices.defaultApplication(for: ext).flatMap(resolve),
                candidates: candidates
            )
        }
        return result
    }

    /// Writes every assignment instantly, waits for LaunchServices to confirm, then retries the
    /// ones macOS ignored through the interactive API (where macOS may ask the user to allow it).
    public func apply(_ assignments: [Assignment]) async -> ApplyReport {
        var previous: [FileExtension: AppInfo] = [:]
        for assignment in assignments {
            previous[assignment.ext] = currentApp(for: assignment.ext)
        }

        var failures: [FileExtension: String] = [:]
        for assignment in assignments {
            do {
                try await launchServices.setDefaultApplication(assignment.app, for: assignment.ext, using: .instant)
            } catch {
                failures[assignment.ext] = error.localizedDescription
            }
        }

        var unconfirmed = await awaitConfirmation(of: assignments.filter { failures[$0.ext] == nil })
        for assignment in unconfirmed {
            // Declining the macOS prompt also lands here; the outcome then reports the app macOS kept.
            try? await launchServices.setDefaultApplication(assignment.app, for: assignment.ext, using: .interactive)
        }
        unconfirmed = await awaitConfirmation(of: unconfirmed)
        let rejected = Set(unconfirmed.map(\.ext))

        return ApplyReport(outcomes: assignments.map { assignment in
            let result: AssignmentOutcome.Result
            if let message = failures[assignment.ext] {
                result = .failed(message: message)
            } else if rejected.contains(assignment.ext) {
                result = .notAccepted(actual: currentApp(for: assignment.ext))
            } else {
                result = .applied
            }
            return AssignmentOutcome(assignment: assignment, previous: previous[assignment.ext], result: result)
        })
    }

    public func app(at url: URL) -> AppInfo? {
        apps.app(at: url)
    }

    /// LaunchServices takes up to a second or two to report a change; returns what never showed up.
    private func awaitConfirmation(of assignments: [Assignment]) async -> [Assignment] {
        let deadline = ContinuousClock.now + verificationTimeout
        var pending = assignments
        while true {
            pending = pending.filter { !$0.app.isSameApp(as: currentApp(for: $0.ext)) }
            if pending.isEmpty || ContinuousClock.now >= deadline { return pending }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func currentApp(for ext: FileExtension) -> AppInfo? {
        launchServices.defaultApplication(for: ext).flatMap(apps.app(at:))
    }
}
