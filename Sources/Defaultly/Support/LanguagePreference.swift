import AppKit
import SwiftUI

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

    /// Relaunching only makes sense for the bundled app, not for `swift run`.
    static var canRelaunch: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            // Keep this copy running if the new one couldn't start.
            guard error == nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
