import DefaultlyCore
import Foundation

/// Persists the user's custom formats.
struct CustomFormatStore {
    private let defaults: UserDefaults
    private let key = "customFormats"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [CustomFormat] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CustomFormat].self, from: data)) ?? []
    }

    func save(_ formats: [CustomFormat]) {
        defaults.set(try? JSONEncoder().encode(formats), forKey: key)
    }
}
