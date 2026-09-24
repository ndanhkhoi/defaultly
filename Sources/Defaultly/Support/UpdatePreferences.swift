import DefaultlyCore
import Foundation

/// Update settings and bookkeeping, in the app's defaults.
struct UpdatePreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var automaticallyChecks: Bool {
        get { defaults.object(forKey: Key.automaticallyChecks) as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: Key.automaticallyChecks) }
    }

    var automaticallyInstalls: Bool {
        get { defaults.bool(forKey: Key.automaticallyInstalls) }
        nonmutating set { defaults.set(newValue, forKey: Key.automaticallyInstalls) }
    }

    var lastCheck: Date? {
        get { defaults.object(forKey: Key.lastCheck) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Key.lastCheck) }
    }

    /// Automatic checks don't offer this version again; a newer one is offered.
    var skippedVersion: AppVersion? {
        get { defaults.string(forKey: Key.skippedVersion).flatMap(AppVersion.init) }
        nonmutating set { defaults.set(newValue?.description, forKey: Key.skippedVersion) }
    }

    /// The version that ran last, to tell an update from a fresh install.
    var lastLaunchedVersion: AppVersion? {
        get { defaults.string(forKey: Key.lastLaunchedVersion).flatMap(AppVersion.init) }
        nonmutating set { defaults.set(newValue?.description, forKey: Key.lastLaunchedVersion) }
    }

    private enum Key {
        static let automaticallyChecks = "automaticallyChecksForUpdates"
        static let automaticallyInstalls = "automaticallyInstallsUpdates"
        static let lastCheck = "lastUpdateCheck"
        static let skippedVersion = "skippedUpdateVersion"
        static let lastLaunchedVersion = "lastLaunchedVersion"
    }
}
