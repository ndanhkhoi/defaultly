import Foundation

enum AppLanguage: String {
    case system
    case english = "en"
    case vietnamese = "vi"
}

/// The app's own language override, which macOS reads from `AppleLanguages` at launch.
enum LanguagePreference {
    private static let key = "AppleLanguages"

    /// The choice the running app started with; later changes only apply after a relaunch.
    static let atLaunch = current

    static var current: AppLanguage {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let languages = UserDefaults.standard.persistentDomain(forName: bundleID)?[key] as? [String],
              let first = languages.first
        else { return .system }
        return first.hasPrefix("vi") ? .vietnamese : .english
    }

    static func set(_ language: AppLanguage) {
        if language == .system {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set([language.rawValue], forKey: key)
        }
    }
}
