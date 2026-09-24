import AppKit
import DefaultlyCore
import SwiftUI

@main
struct DefaultlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.live()
    @State private var navigation = Navigation()
    @State private var updates = UpdateController.live()

    var body: some Scene {
        Window("Defaultly", id: "main") {
            RootView()
                .environment(model)
                .environment(navigation)
                .environment(updates)
                .frame(minWidth: 960, minHeight: 560)
        }
        .defaultSize(width: 1240, height: 780)
        .commands { DefaultlyCommands(model: model, navigation: navigation, updates: updates) }

        Window("Release Notes", id: ReleaseNotesScreen.windowID) {
            ReleaseNotesScreen()
                .environment(updates)
        }
        .defaultSize(width: 600, height: 680)

        Settings {
            SettingsView()
                .environment(updates)
        }
    }
}

extension AppModel {
    /// Composition root: the only place system implementations are chosen.
    static func live() -> AppModel {
        let locator = SystemAppLocator()
        return AppModel(
            service: AssociationService(launchServices: SystemLaunchServices(), apps: locator),
            locator: locator,
            store: CustomFormatStore()
        )
    }
}

extension UpdateController {
    /// Composition root for updates: GitHub releases of this repository, staged in the app's caches folder.
    static func live() -> UpdateController {
        let bundle = Bundle.main
        let versionString = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let appName = bundle.infoDictionary?["CFBundleName"] as? String ?? "Defaultly"
        let bundleID = bundle.bundleIdentifier ?? "io.github.ndanhkhoi.defaultly"
        let source = GitHubReleaseClient(releasesURL: ProjectLinks.releasesAPI, appName: appName, appVersion: versionString ?? "dev")
        let installer = UpdateInstaller(
            source: source,
            bundleID: bundleID,
            signature: CodeSignature.running,
            stagingFolder: URL.cachesDirectory.appending(path: bundleID).appending(path: "Update")
        )
        return UpdateController(
            currentVersion: versionString.flatMap(AppVersion.init),
            appURL: bundle.bundleURL,
            source: source,
            installer: installer,
            preferences: UpdatePreferences(),
            presenter: UpdateWindow(),
            relaunch: { Relaunch.now(onFailure: $0) }
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when launched as a bare executable (`swift run`); harmless in the app bundle.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
