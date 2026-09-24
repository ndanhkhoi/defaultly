import Foundation
import UniformTypeIdentifiers

/// A normalized filename extension: lowercase, without the leading dot (e.g. `docx`).
public struct FileExtension: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let rawValue: String

    /// Accepts user input such as `docx`, `.DOCX` or `*.docx`.
    /// Returns nil when the input cannot be a single filename extension.
    public init?(_ input: String) {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("*") { value.removeFirst() }
        if value.hasPrefix(".") { value.removeFirst() }
        guard (1...32).contains(value.count),
              value.unicodeScalars.allSatisfy(Self.allowedCharacters.contains)
        else { return nil }
        rawValue = value
    }

    /// `.docx`
    public var description: String { "." + rawValue }

    public static func < (lhs: FileExtension, rhs: FileExtension) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    private static let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_+")
}

// MARK: - Parsing lists

public extension FileExtension {
    struct ParsedList: Equatable, Sendable {
        public let valid: [FileExtension]
        public let invalid: [String]
    }

    /// Splits input on commas, semicolons and whitespace.
    /// Keeps the first occurrence of each valid extension, in input order.
    static func parseList(_ input: String) -> ParsedList {
        let separators = CharacterSet(charactersIn: ",;").union(.whitespacesAndNewlines)
        var valid: [FileExtension] = []
        var invalid: [String] = []
        for token in input.components(separatedBy: separators) where !token.isEmpty {
            if let ext = FileExtension(token) {
                if !valid.contains(ext) { valid.append(ext) }
            } else {
                invalid.append(token)
            }
        }
        return ParsedList(valid: valid, invalid: invalid)
    }
}

// MARK: - Uniform Type Identifiers

public extension FileExtension {
    /// Every content type macOS associates with this extension; the preferred one comes first.
    var contentTypes: [UTType] {
        var types: [UTType] = []
        if let preferred = UTType(filenameExtension: rawValue) { types.append(preferred) }
        for type in UTType.types(tag: rawValue, tagClass: .filenameExtension, conformingTo: nil)
        where !type.isDynamic && !types.contains(type) {
            types.append(type)
        }
        return types
    }

    /// The system's localized description, when some installed app or macOS declares the type.
    var systemDescription: String? {
        UTType(filenameExtension: rawValue)?.localizedDescription
    }

    /// A display name for formats that have none: the system description, or `KT` for `.kt`.
    var fallbackName: String {
        systemDescription ?? rawValue.uppercased()
    }
}

// MARK: - Codable (as a plain string)

extension FileExtension: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let ext = FileExtension(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid file extension: \(raw)")
        }
        self = ext
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
