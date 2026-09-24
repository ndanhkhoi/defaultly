import Foundation
import Testing
@testable import DefaultlyCore

struct CatalogTests {
    let categories = FileTypeCatalog.categories

    @Test func categoryIDsAreUniqueAndNotReserved() {
        let ids = categories.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(FormatLibrary.customCategoryID))
    }

    @Test func hasSeventeenNonEmptyCategories() {
        #expect(categories.count == 17)
        #expect(categories.allSatisfy { !$0.formats.isEmpty })
    }

    @Test func everyExtensionAppearsOnce() {
        let extensions = categories.flatMap { $0.formats.map(\.ext) }
        let duplicates = Dictionary(grouping: extensions, by: { $0 }).filter { $0.value.count > 1 }.keys
        #expect(duplicates.isEmpty, "Duplicated: \(duplicates.map(\.description))")
    }

    @Test func coversAtLeastThreeHundredFiftyFormats() {
        #expect(categories.flatMap(\.formats).count >= 350)
    }

    @Test func formatsPointAtTheirCategory() {
        for category in categories {
            #expect(category.formats.allSatisfy { $0.categoryID == category.id && !$0.isCustom })
        }
    }

    @Test func suitesReferenceExistingCategories() {
        let ids = Set(categories.map(\.id))
        #expect(AppSuite.all.allSatisfy { suite in suite.members.allSatisfy { ids.contains($0.categoryID) } })
    }

    @Test func everyCatalogNameHasAVietnameseTranslation() throws {
        let translations = try LocalizationFile.load("vi.lproj/Localizable.strings")
        let names = Set(categories.map(\.name) + categories.flatMap { $0.formats.map(\.name) } + [FormatLibrary().customCategory.name])
        let missing = names.filter { translations[$0] == nil }.sorted()
        #expect(missing.isEmpty, "Missing Vietnamese: \(missing)")
    }
}

enum LocalizationFile {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources")

    static func load(_ relativePath: String) throws -> [String: String] {
        let data = try Data(contentsOf: resources.appendingPathComponent(relativePath))
        return try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] ?? [:]
    }
}
