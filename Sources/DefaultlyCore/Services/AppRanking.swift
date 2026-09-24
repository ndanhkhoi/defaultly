import Foundation

/// An app together with how many formats of a group it relates to.
public struct AppCount: Identifiable, Hashable, Sendable {
    public let app: AppInfo
    public let count: Int

    public var id: String { app.bundleID }
}

/// Orders apps for suggestions.
public enum AppRanking {
    /// Apps that declare support for the formats, most formats first.
    public static func supporting(_ formats: [FileFormat], statuses: [FileExtension: FormatStatus]) -> [AppCount] {
        rank(formats.flatMap { statuses[$0.ext]?.candidates ?? [] })
    }

    /// Apps that currently open the formats, most formats first; the first one is the "mostly" app.
    public static func defaults(for formats: [FileFormat], statuses: [FileExtension: FormatStatus]) -> [AppCount] {
        rank(formats.compactMap { statuses[$0.ext]?.current })
    }

    private static func rank(_ apps: [AppInfo]) -> [AppCount] {
        var counts: [String: Int] = [:]
        var firstSeen: [String: AppInfo] = [:]
        for app in apps {
            counts[app.bundleID, default: 0] += 1
            if firstSeen[app.bundleID] == nil { firstSeen[app.bundleID] = app }
        }
        return firstSeen.values
            .map { AppCount(app: $0, count: counts[$0.bundleID] ?? 0) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.app.name.localizedStandardCompare($1.app.name) == .orderedAscending }
    }
}
