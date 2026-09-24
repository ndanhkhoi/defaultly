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
            let content = UpdateView(controller: controller)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { [weak self] size in self?.fit(size) }
            let hosting = NSHostingController(rootView: content)
            // The window follows the content's size as the phase changes, but through `fit(_:)` rather than the
            // hosting controller's constraints: with those, macOS 27 kept resizing the window until AppKit aborted.
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable]
            window.title = String(localized: "Software Update")
            window.isRestorable = false
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(hosting.sizeThatFits(in: CGSize(width: CGFloat.infinity, height: .infinity)))
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Resizes the window to its content, keeping its top edge in place.
    private func fit(_ size: CGSize) {
        guard let window else { return }
        var frame = window.frameRect(forContentRect: CGRect(origin: window.frame.origin, size: size))
        frame.origin.y = window.frame.maxY - frame.height
        guard frame != window.frame else { return }
        window.setFrame(frame, display: true)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
