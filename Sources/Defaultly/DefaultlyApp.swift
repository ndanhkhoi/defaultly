import AppKit
import DefaultlyCore
import SwiftUI

@main
struct DefaultlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.live()
    @State private var navigation = Navigation()

    var body: some Scene {
        Window("Defaultly", id: "main") {
            RootView()
                .environment(model)
                .environment(navigation)
                .frame(minWidth: 960, minHeight: 560)
        }
        .defaultSize(width: 1240, height: 780)
        .commands { DefaultlyCommands(model: model, navigation: navigation) }

        Settings {
            SettingsView()
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
