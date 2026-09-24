import DefaultlyCore
import Foundation

/// Translations for strings only known at runtime, such as catalog names.
/// Static UI text goes through SwiftUI's `LocalizedStringKey` instead.
enum L10n {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

extension FileFormat {
    var displayName: String { L10n.string(name) }
}

extension FileCategory {
    var displayName: String { L10n.string(name) }
}
