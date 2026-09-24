import Foundation

/// A release version such as `1.2.3`, compared number by number, so `1.10.0` is newer than `1.9.0`.
public struct AppVersion: Hashable, Comparable, Sendable, CustomStringConvertible {
    /// Always three numbers: `1.2` is stored as `1.2.0`.
    public let components: [Int]

    /// Accepts `1.2.3`, `v1.2.3`, `1.2` or `1`. Pre-release suffixes such as `1.2.3-beta` aren't versions here.
    public init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let number = Int(part) else { return nil }
            numbers.append(number)
        }
        components = numbers + Array(repeating: 0, count: 3 - numbers.count)
    }

    public var description: String {
        components.map(String.init).joined(separator: ".")
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}
