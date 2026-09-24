import Foundation

/// An installed application that can open files.
public struct AppInfo: Identifiable, Hashable, Sendable {
    public let bundleID: String
    public let name: String
    public let url: URL

    public var id: String { bundleID }

    public init(bundleID: String, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        self.url = url
    }

    /// Two copies of the same app (same bundle ID) count as the same app.
    public func isSameApp(as other: AppInfo?) -> Bool {
        bundleID == other?.bundleID
    }
}
