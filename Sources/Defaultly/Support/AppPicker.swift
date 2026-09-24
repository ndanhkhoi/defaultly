import AppKit
import UniformTypeIdentifiers

/// Lets the user pick any application, including ones LaunchServices does not suggest.
@MainActor
enum AppPicker {
    static func chooseApp() -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose an App")
        panel.prompt = String(localized: "Choose")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        return panel.runModal() == .OK ? panel.url : nil
    }
}
