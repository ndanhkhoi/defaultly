import Foundation

/// Which app opens a format today, and which apps declare they can open it.
public struct FormatStatus: Equatable, Sendable {
    public let current: AppInfo?
    /// In LaunchServices order (most relevant first), one entry per bundle ID.
    public let candidates: [AppInfo]

    public init(current: AppInfo?, candidates: [AppInfo]) {
        self.current = current
        self.candidates = candidates
    }

    public func supports(_ app: AppInfo) -> Bool {
        candidates.contains { $0.isSameApp(as: app) }
    }
}
