import DefaultlyCore
import Foundation

/// Persists the user's custom formats.
struct CustomFormatStore {
    private let defaults: UserDefaults
    private let key = "customFormats"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Skips entries that no longer decode instead of dropping the whole list.
    func load() -> [CustomFormat] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([LossyEntry].self, from: data)
        else { return [] }
        return entries.compactMap(\.format)
    }

    func save(_ formats: [CustomFormat]) {
        defaults.set(try? JSONEncoder().encode(formats), forKey: key)
    }

    private struct LossyEntry: Decodable {
        let format: CustomFormat?

        init(from decoder: Decoder) throws {
            format = try? CustomFormat(from: decoder)
        }
    }
}
