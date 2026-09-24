import Foundation

/// One pending change, shown for review before it is applied.
public struct PlanItem: Identifiable, Hashable, Sendable {
    public let format: FileFormat
    public let target: AppInfo
    public let current: AppInfo?
    /// Whether the target app declares it can open this format.
    public let isSupported: Bool
    public var isIncluded: Bool

    public var id: FileExtension { format.ext }
    public var assignment: Assignment { Assignment(ext: format.ext, app: target) }
}

public enum PlanBuilder {
    /// Pending changes that make `target(format)` the default for each format.
    /// Formats already opened by their target, or without a target, are left out.
    /// Unsupported formats start excluded so nothing surprising happens by default.
    public static func items(
        for formats: [FileFormat],
        statuses: [FileExtension: FormatStatus],
        target: (FileFormat) -> AppInfo?
    ) -> [PlanItem] {
        formats.compactMap { format in
            guard let app = target(format) else { return nil }
            let status = statuses[format.ext]
            guard !app.isSameApp(as: status?.current) else { return nil }
            let isSupported = status?.supports(app) ?? false
            return PlanItem(format: format, target: app, current: status?.current, isSupported: isSupported, isIncluded: isSupported)
        }
    }

    public static func items(for formats: [FileFormat], assigning app: AppInfo, statuses: [FileExtension: FormatStatus]) -> [PlanItem] {
        items(for: formats, statuses: statuses) { _ in app }
    }
}
