import AppKit

/// Finds installed applications.
public protocol AppLocating: Sendable {
    func app(at url: URL) -> AppInfo?
    func app(bundleID: String) -> AppInfo?
    func installedApps() -> [AppInfo]
}

/// `AppLocating` backed by the file system and `NSWorkspace`.
public struct SystemAppLocator: AppLocating {
    public static let defaultDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]

    private let directories: [URL]

    public init(directories: [URL] = Self.defaultDirectories) {
        self.directories = directories
    }

    public func app(at url: URL) -> AppInfo? {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name.removeLast(4) }
        return AppInfo(bundleID: bundleID, name: name, url: url)
    }

    public func app(bundleID: String) -> AppInfo? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).flatMap(app(at:))
    }

    /// Apps in the standard folders and one level of subfolders (e.g. `/Applications/Utilities`),
    /// one per bundle ID, sorted by name.
    public func installedApps() -> [AppInfo] {
        var seen = Set<String>()
        return directories
            .flatMap { appURLs(in: $0, depth: 1) }
            .compactMap(app(at:))
            .filter { seen.insert($0.bundleID).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func appURLs(in directory: URL, depth: Int) -> [URL] {
        let items = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return items.flatMap { item -> [URL] in
            if item.pathExtension == "app" { return [item] }
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            return isDirectory && depth > 0 ? appURLs(in: item, depth: depth - 1) : []
        }
    }
}
