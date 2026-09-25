import Foundation
@testable import DefaultlyCore

extension AppInfo {
    static func fake(_ bundleID: String, _ name: String, path: String? = nil) -> AppInfo {
        AppInfo(bundleID: bundleID, name: name, url: URL(fileURLWithPath: path ?? "/Applications/\(name).app"))
    }

    static let word = AppInfo.fake("com.microsoft.Word", "Microsoft Word")
    static let libre = AppInfo.fake("org.libreoffice.script", "LibreOffice")
    static let code = AppInfo.fake("com.microsoft.VSCode", "Visual Studio Code")
    static let preview = AppInfo.fake("com.apple.Preview", "Preview")
}

extension FileExtension {
    static func ext(_ raw: String) -> FileExtension { FileExtension(raw)! }
}

extension FileFormat {
    static func fake(_ ext: String, category: String = "documents", custom: Bool = false) -> FileFormat {
        FileFormat(ext: .ext(ext), name: ext.uppercased(), categoryID: category, isCustom: custom)
    }
}

/// Locates apps from a fixed list, keyed by URL and bundle ID.
struct FakeAppLocator: AppLocating {
    var apps: [AppInfo]

    func app(at url: URL) -> AppInfo? { apps.first { $0.url == url } }
    func app(bundleID: String) -> AppInfo? { apps.first { $0.bundleID == bundleID } }
    func installedApps() -> [AppInfo] { apps }
}

/// In-memory LaunchServices.
/// `ownedByOthers`: instant writes are ignored, interactive ones work (like types another app owns).
/// `rejected`: every write is ignored. `failing`: every write throws.
/// `declining`: the interactive write throws as if the user declined the system prompt.
/// `propagationDelay`: how long a write takes to show up in reads, as LaunchServices does.
/// `instantWritesAreSilent: false` behaves like macOS 27, where only the interactive write should be used.
final class FakeLaunchServices: LaunchServicesClient, @unchecked Sendable {
    struct Failure: LocalizedError { var errorDescription: String? { "boom" } }

    private let lock = NSLock()
    private var defaults: [FileExtension: URL]
    private var calls: [(FileExtension, AssignmentMethod)] = []
    private var settling: [(FileExtension, URL, ContinuousClock.Instant)] = []
    private let candidates: [FileExtension: [URL]]
    private let ownedByOthers: Set<FileExtension>
    private let rejected: Set<FileExtension>
    private let failing: Set<FileExtension>
    private let declining: Set<FileExtension>
    private let propagationDelay: Duration
    let instantWritesAreSilent: Bool

    init(
        defaults: [FileExtension: URL] = [:],
        candidates: [FileExtension: [URL]] = [:],
        ownedByOthers: Set<FileExtension> = [],
        rejected: Set<FileExtension> = [],
        failing: Set<FileExtension> = [],
        declining: Set<FileExtension> = [],
        propagationDelay: Duration = .zero,
        instantWritesAreSilent: Bool = true
    ) {
        self.defaults = defaults
        self.candidates = candidates
        self.ownedByOthers = ownedByOthers
        self.rejected = rejected
        self.failing = failing
        self.declining = declining
        self.propagationDelay = propagationDelay
        self.instantWritesAreSilent = instantWritesAreSilent
    }

    /// Which methods were used for an extension, in order.
    func methods(for ext: FileExtension) -> [AssignmentMethod] {
        lock.withLock { calls.filter { $0.0 == ext }.map(\.1) }
    }

    func defaultApplication(for ext: FileExtension) -> URL? {
        lock.withLock {
            settleDueWrites()
            return defaults[ext]
        }
    }

    func applications(for ext: FileExtension) -> [URL] {
        candidates[ext] ?? []
    }

    func setDefaultApplication(_ app: AppInfo, for ext: FileExtension, using method: AssignmentMethod) async throws {
        lock.withLock { calls.append((ext, method)) }
        if failing.contains(ext) { throw Failure() }
        if method == .interactive, declining.contains(ext) { throw LaunchServicesError.declined }
        if rejected.contains(ext) || (method == .instant && ownedByOthers.contains(ext)) { return }
        lock.withLock { settling.append((ext, app.url, .now + propagationDelay)) }
    }

    /// Applies writes whose delay has passed; call only under `lock`.
    private func settleDueWrites() {
        let now = ContinuousClock.now
        for (ext, url, visibleAt) in settling where visibleAt <= now { defaults[ext] = url }
        settling.removeAll { $0.2 <= now }
    }
}
