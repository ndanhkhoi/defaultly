import Foundation

/// The formats the app works with: the built-in catalog merged with the user's custom formats.
public struct FormatLibrary: Sendable {
    public static let customCategoryID = "custom"

    /// Built-in categories, each including the custom formats the user filed under it.
    public let categories: [FileCategory]
    /// All custom formats, whatever their category ("Custom Formats" in the sidebar).
    public let customCategory: FileCategory
    public let allFormats: [FileFormat]
    private let formatsByExtension: [FileExtension: FileFormat]

    public init(catalog: [FileCategory] = FileTypeCatalog.categories, custom: [CustomFormat] = []) {
        let builtIn = Set(catalog.flatMap { $0.formats.map(\.ext) })
        let categoryIDs = Set(catalog.map(\.id))
        var seen = Set<FileExtension>()
        let customFormats = custom
            .filter { !builtIn.contains($0.ext) && seen.insert($0.ext).inserted }
            .map { format in
                FileFormat(
                    ext: format.ext,
                    name: Self.displayName(for: format),
                    categoryID: categoryIDs.contains(format.categoryID) ? format.categoryID : Self.customCategoryID,
                    isCustom: true
                )
            }

        categories = catalog.map { category in
            FileCategory(
                id: category.id,
                name: category.name,
                symbol: category.symbol,
                tint: category.tint,
                formats: category.formats + customFormats.filter { $0.categoryID == category.id }
            )
        }
        customCategory = FileCategory(
            id: Self.customCategoryID,
            name: "Custom Formats",
            symbol: "tag",
            tint: .gray,
            formats: customFormats
        )
        allFormats = categories.flatMap(\.formats) + customFormats.filter { $0.categoryID == Self.customCategoryID }
        formatsByExtension = Dictionary(uniqueKeysWithValues: allFormats.map { ($0.ext, $0) })
    }

    public var allExtensions: [FileExtension] { allFormats.map(\.ext) }

    public func format(for ext: FileExtension) -> FileFormat? {
        formatsByExtension[ext]
    }

    /// Catalog categories plus the custom pseudo-category.
    public func category(id: String) -> FileCategory? {
        id == Self.customCategoryID ? customCategory : categories.first { $0.id == id }
    }

    /// Ranks exact extension matches first, then extension prefixes, then name matches.
    /// `localizedName` lets the UI match names in the user's language as well as in English;
    /// names match without accents, so "bang tinh" finds "Bảng tính".
    public func search(_ query: String, localizedName: (FileFormat) -> String = \.name) -> [FileFormat] {
        let needle = FileExtension.normalized(query)
        guard !needle.isEmpty else { return [] }

        func matchesName(_ name: String) -> Bool {
            name.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        func rank(_ format: FileFormat) -> Int? {
            let ext = format.ext.rawValue
            if ext == needle { return 0 }
            if ext.hasPrefix(needle) { return 1 }
            if matchesName(format.name) || matchesName(localizedName(format)) { return 2 }
            return nil
        }

        let ranked: [(format: FileFormat, rank: Int)] = allFormats.compactMap { format in
            rank(format).map { (format, $0) }
        }
        return ranked
            .sorted { lhs, rhs in lhs.rank != rhs.rank ? lhs.rank < rhs.rank : lhs.format.ext < rhs.format.ext }
            .map(\.format)
    }

    private static func displayName(for format: CustomFormat) -> String {
        if let name = format.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return format.ext.fallbackName
    }
}
