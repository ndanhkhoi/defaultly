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
    /// Which pending changes start checked.
    public enum Inclusion: Sendable {
        /// Only formats the target app declares, so nothing surprising happens by default.
        case supportedOnly
        /// Everything, when the user already chose each change (e.g. restoring a backup).
        case all
        /// Nothing, when the list is a set of suggestions to pick from.
        case none
    }

    /// Pending changes that make `target(format)` the default for each format.
    /// Formats already opened by their target, or without a target, are left out.
    public static func items(
        for formats: [FileFormat],
        statuses: [FileExtension: FormatStatus],
        including inclusion: Inclusion = .supportedOnly,
        target: (FileFormat) -> AppInfo?
    ) -> [PlanItem] {
        formats.compactMap { format in
            guard let app = target(format) else { return nil }
            let status = statuses[format.ext]
            guard !app.isSameApp(as: status?.current) else { return nil }
            let isSupported = status?.supports(app) ?? false
            let isIncluded = switch inclusion {
            case .supportedOnly: isSupported
            case .all: true
            case .none: false
            }
            return PlanItem(format: format, target: app, current: status?.current, isSupported: isSupported, isIncluded: isIncluded)
        }
    }

    public static func items(
        for formats: [FileFormat],
        assigning app: AppInfo,
        statuses: [FileExtension: FormatStatus],
        including inclusion: Inclusion = .supportedOnly
    ) -> [PlanItem] {
        items(for: formats, statuses: statuses, including: inclusion) { _ in app }
    }

    /// A recomputed plan keeps the user's checkboxes for the changes that are still pending.
    public static func keepingChoices(of previous: [PlanItem], in items: [PlanItem]) -> [PlanItem] {
        let choices = Dictionary(previous.map { ($0.id, $0.isIncluded) }, uniquingKeysWith: { first, _ in first })
        return items.map { item in
            var item = item
            item.isIncluded = choices[item.id] ?? item.isIncluded
            return item
        }
    }
}
