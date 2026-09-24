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
final class FakeLaunchServices: LaunchServicesClient, @unchecked Sendable {
    struct Failure: LocalizedError { var errorDescription: String? { "boom" } }

    private let lock = NSLock()
    private var defaults: [FileExtension: URL]
    private var calls: [(FileExtension, AssignmentMethod)] = []
    private let candidates: [FileExtension: [URL]]
    private let ownedByOthers: Set<FileExtension>
    private let rejected: Set<FileExtension>
    private let failing: Set<FileExtension>
    private let declining: Set<FileExtension>

    init(
        defaults: [FileExtension: URL] = [:],
        candidates: [FileExtension: [URL]] = [:],
        ownedByOthers: Set<FileExtension> = [],
        rejected: Set<FileExtension> = [],
        failing: Set<FileExtension> = [],
        declining: Set<FileExtension> = []
    ) {
        self.defaults = defaults
        self.candidates = candidates
        self.ownedByOthers = ownedByOthers
        self.rejected = rejected
        self.failing = failing
        self.declining = declining
    }

    /// Which methods were used for an extension, in order.
    func methods(for ext: FileExtension) -> [AssignmentMethod] {
        lock.withLock { calls.filter { $0.0 == ext }.map(\.1) }
    }

    func defaultApplication(for ext: FileExtension) -> URL? {
        lock.withLock { defaults[ext] }
    }

    func applications(for ext: FileExtension) -> [URL] {
        candidates[ext] ?? []
    }

    func setDefaultApplication(_ app: AppInfo, for ext: FileExtension, using method: AssignmentMethod) async throws {
        lock.withLock { calls.append((ext, method)) }
        if failing.contains(ext) { throw Failure() }
        if method == .interactive, declining.contains(ext) { throw LaunchServicesError.declined }
        if rejected.contains(ext) || (method == .instant && ownedByOthers.contains(ext)) { return }
        lock.withLock { defaults[ext] = app.url }
    }
}
