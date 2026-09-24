import Foundation
import Testing
@testable import DefaultlyCore

struct FormatLibraryTests {
    @Test func mergesCustomFormatsIntoTheirCategory() {
        let library = FormatLibrary(custom: [CustomFormat(ext: .ext("kts2"), name: "Kotlin Script 2", categoryID: "code")])
        let code = library.category(id: "code")
        #expect(code?.formats.last?.ext == .ext("kts2"))
        #expect(library.customCategory.formats.map(\.ext) == [.ext("kts2")])
        #expect(library.format(for: .ext("kts2"))?.isCustom == true)
    }

    @Test func ignoresCustomFormatsThatDuplicateTheCatalog() {
        let library = FormatLibrary(custom: [CustomFormat(ext: .ext("png"), name: "Mine")])
        #expect(library.customCategory.formats.isEmpty)
        #expect(library.format(for: .ext("png"))?.name == "PNG Image")
    }

    @Test func dropsDuplicateCustomFormatsAndFilesUnknownCategoriesUnderCustom() {
        let library = FormatLibrary(custom: [
            CustomFormat(ext: .ext("zzq"), name: "One", categoryID: "nope"),
            CustomFormat(ext: .ext("zzq"), name: "Two"),
        ])
        #expect(library.customCategory.formats.count == 1)
        #expect(library.format(for: .ext("zzq"))?.categoryID == FormatLibrary.customCategoryID)
        #expect(library.allFormats.filter { $0.ext == .ext("zzq") }.count == 1)
    }

    @Test func fallsBackToUppercasedExtensionWithoutAName() {
        let library = FormatLibrary(custom: [CustomFormat(ext: .ext("zzqx"), name: "  ")])
        #expect(library.format(for: .ext("zzqx"))?.name == "ZZQX")
    }

    @Test func searchRanksExactThenPrefixThenName() {
        let results = FormatLibrary().search(".doc").map(\.ext.rawValue)
        #expect(results.first == "doc")
        #expect(results.prefix(4).contains("docx"))
        #expect(FormatLibrary().search("*.PNG").first?.ext == .ext("png"))
    }

    @Test func searchMatchesLocalizedNames() {
        let results = FormatLibrary().search("bảng tính") { $0.categoryID == "spreadsheets" ? "Bảng tính" : $0.name }
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.categoryID == "spreadsheets" })
    }

    @Test func searchIgnoresAccents() {
        let results = FormatLibrary().search("bang tinh") { $0.categoryID == "spreadsheets" ? "Bảng tính" : $0.name }
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.categoryID == "spreadsheets" })
    }

    @Test func emptySearchReturnsNothing() {
        #expect(FormatLibrary().search("  ").isEmpty)
    }
}
