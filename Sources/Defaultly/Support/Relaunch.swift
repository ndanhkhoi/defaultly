import AppKit

/// Starts a new instance of the app bundle, then quits this one once the new one has launched.
enum Relaunch {
    /// Only the bundled app can be relaunched, not a bare `swift run` executable.
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    /// Keeps this copy running, and calls `onFailure`, if the new one couldn't start.
    @MainActor
    static func now(onFailure: @escaping @MainActor () -> Void = {}) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            let started = error == nil
            DispatchQueue.main.async {
                if started { NSApp.terminate(nil) } else { onFailure() }
            }
        }
    }
}
