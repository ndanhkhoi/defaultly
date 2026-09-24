import Foundation

/// A portable snapshot of the user's associations and custom formats.
public struct AssociationBackup: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var ext: FileExtension
        public var bundleID: String
        /// Kept for humans reading the file and for messages when the app is missing.
        public var appName: String
    }

    public enum BackupError: LocalizedError, Equatable {
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                String(localized: "This backup was made by a newer version of Defaultly (format \(version)).", bundle: .main)
            }
        }
    }

    public static let currentVersion = 1

    public var version: Int
    public var createdAt: Date
    public var associations: [Entry]
    public var customFormats: [CustomFormat]

    public init(statuses: [FileExtension: FormatStatus], customFormats: [CustomFormat], createdAt: Date = Date()) {
        version = Self.currentVersion
        self.createdAt = createdAt
        self.customFormats = customFormats
        associations = statuses
            .compactMap { ext, status in
                status.current.map { Entry(ext: ext, bundleID: $0.bundleID, appName: $0.name) }
            }
            .sorted { $0.ext < $1.ext }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> AssociationBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(AssociationBackup.self, from: data)
        guard backup.version <= currentVersion else { throw BackupError.unsupportedVersion(backup.version) }
        return backup
    }
}

/// What restoring a backup would change.
public struct RestorePreview: Sendable {
    public let backup: AssociationBackup
    public let items: [PlanItem]
    /// Entries whose app is not installed on this Mac.
    public let missingApps: [AssociationBackup.Entry]
    /// Custom formats from the backup that do not exist yet.
    public let newCustomFormats: [CustomFormat]

    /// `library` must already include the backup's custom formats so their entries can be shown.
    public init(
        backup: AssociationBackup,
        library: FormatLibrary,
        existingCustomFormats: [CustomFormat],
        statuses: [FileExtension: FormatStatus],
        apps: any AppLocating
    ) {
        self.backup = backup
        let existing = Set(existingCustomFormats.map(\.ext))
        newCustomFormats = backup.customFormats.filter { !existing.contains($0.ext) && library.format(for: $0.ext)?.isCustom == true }

        var targets: [FileExtension: AppInfo] = [:]
        var missing: [AssociationBackup.Entry] = []
        for entry in backup.associations {
            if let app = apps.app(bundleID: entry.bundleID) {
                targets[entry.ext] = app
            } else {
                missing.append(entry)
            }
        }
        missingApps = missing
        let formats = backup.associations.compactMap { library.format(for: $0.ext) }
        items = PlanBuilder.items(for: formats, statuses: statuses) { targets[$0.ext] }
            .map { item in
                // Restoring is explicit: include everything the user had before, supported or not.
                var item = item
                item.isIncluded = true
                return item
            }
    }
}
