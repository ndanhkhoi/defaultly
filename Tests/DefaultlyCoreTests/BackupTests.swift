import Foundation
import Testing
@testable import DefaultlyCore

struct BackupTests {
    let statuses: [FileExtension: FormatStatus] = [
        .ext("pdf"): FormatStatus(current: .preview, candidates: [.preview]),
        .ext("docx"): FormatStatus(current: .word, candidates: [.word, .libre]),
        .ext("zzq"): FormatStatus(current: nil, candidates: []),
    ]
    let custom = [CustomFormat(ext: .ext("zzq"), name: "Mine", categoryID: "code")]

    @Test func capturesCurrentDefaultsSorted() {
        let backup = AssociationBackup(statuses: statuses, customFormats: custom)
        #expect(backup.associations.map(\.ext) == [.ext("docx"), .ext("pdf")])
        #expect(backup.associations.first?.bundleID == AppInfo.word.bundleID)
        #expect(backup.customFormats == custom)
    }

    @Test func roundTripsThroughJSON() throws {
        let backup = AssociationBackup(statuses: statuses, customFormats: custom, createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        let decoded = try AssociationBackup.decode(backup.encoded())
        #expect(decoded == backup)
    }

    @Test func rejectsBackupsFromNewerVersions() throws {
        var backup = AssociationBackup(statuses: [:], customFormats: [])
        backup.version = AssociationBackup.currentVersion + 1
        let data = try backup.encoded()
        #expect(throws: AssociationBackup.BackupError.unsupportedVersion(backup.version)) {
            try AssociationBackup.decode(data)
        }
    }

    @Test func previewListsChangesMissingAppsAndNewCustomFormats() {
        let backup = AssociationBackup(
            statuses: [
                .ext("docx"): FormatStatus(current: .libre, candidates: []),
                .ext("pdf"): FormatStatus(current: .preview, candidates: []),
                .ext("md"): FormatStatus(current: .fake("com.gone.App", "Gone"), candidates: []),
                .ext("zzq"): FormatStatus(current: .code, candidates: []),
            ],
            customFormats: custom
        )
        let library = FormatLibrary(custom: custom)
        let preview = RestorePreview(
            backup: backup,
            library: library,
            existingCustomFormats: [],
            statuses: statuses,
            apps: FakeAppLocator(apps: [.word, .libre, .preview, .code])
        )
        #expect(preview.items.map(\.id) == [.ext("docx"), .ext("zzq")])
        #expect(preview.items.allSatisfy { $0.isIncluded })
        #expect(preview.missingApps.map(\.appName) == ["Gone"])
        #expect(preview.newCustomFormats == custom)
    }
}
