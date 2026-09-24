import Foundation

/// A color family used to tell categories apart; the UI maps it to a concrete color.
public enum CategoryTint: Sendable {
    case blue, green, orange, red, brown, gray, cyan, indigo, teal, pink, purple, yellow, mint
}

/// A file format the app can manage. `name` is English and doubles as the localization key.
public struct FileFormat: Identifiable, Hashable, Sendable {
    public let ext: FileExtension
    public let name: String
    public let categoryID: String
    public let isCustom: Bool

    public var id: FileExtension { ext }

    public init(ext: FileExtension, name: String, categoryID: String, isCustom: Bool = false) {
        self.ext = ext
        self.name = name
        self.categoryID = categoryID
        self.isCustom = isCustom
    }
}

/// A group of related formats shown together in the sidebar and Quick Setup.
public struct FileCategory: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// SF Symbol name.
    public let symbol: String
    public let tint: CategoryTint
    public let formats: [FileFormat]

    public init(id: String, name: String, symbol: String, tint: CategoryTint, formats: [FileFormat]) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.tint = tint
        self.formats = formats
    }
}

/// A format the user added. A nil `name` falls back to the system description.
public struct CustomFormat: Codable, Hashable, Sendable {
    public var ext: FileExtension
    public var name: String?
    public var categoryID: String

    public init(ext: FileExtension, name: String? = nil, categoryID: String = FormatLibrary.customCategoryID) {
        self.ext = ext
        self.name = name
        self.categoryID = categoryID
    }
}
