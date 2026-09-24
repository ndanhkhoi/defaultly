import AppKit
import SwiftUI

/// The Software Update window. AppKit rather than a SwiftUI scene so the controller can open it from a background
/// check, and so it isn't restored at the next launch: after an update relaunches the app, there is nothing to show.
@MainActor
final class UpdateWindow: NSObject, NSWindowDelegate, UpdatePresenting {
    var onClose: (@MainActor () -> Void)?
    private var window: NSWindow?

    func show(_ controller: UpdateController) {
        if window == nil {
            let hosting = NSHostingController(rootView: UpdateView(controller: controller))
            // The window follows the content's size as the phase changes.
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.title = String(localized: "Software Update")
            window.isRestorable = false
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(hosting.view.fittingSize)
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
