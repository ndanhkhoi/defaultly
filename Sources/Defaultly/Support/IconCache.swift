import AppKit

/// App icons are expensive to load and requested on every render, so keep them.
@MainActor
final class IconCache {
    static let shared = IconCache()

    private let icons = NSCache<NSURL, NSImage>()
    private let menuIcons = NSCache<NSURL, NSImage>()

    func icon(for url: URL) -> NSImage {
        if let cached = icons.object(forKey: url as NSURL) { return cached }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons.setObject(icon, forKey: url as NSURL)
        return icon
    }

    /// Menus draw images at their intrinsic size, so they need a 16 pt copy.
    func menuIcon(for url: URL) -> NSImage {
        if let cached = menuIcons.object(forKey: url as NSURL) { return cached }
        let icon = (icon(for: url).copy() as? NSImage) ?? NSImage()
        icon.size = NSSize(width: 16, height: 16)
        menuIcons.setObject(icon, forKey: url as NSURL)
        return icon
    }
}
