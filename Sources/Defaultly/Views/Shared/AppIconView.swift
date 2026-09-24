import DefaultlyCore
import SwiftUI

struct AppIconView: View {
    let app: AppInfo?
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let app {
                Image(nsImage: IconCache.shared.icon(for: app.url))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Icon + name of an app, or a clear "none" state.
struct AppLabel: View {
    let app: AppInfo?
    var iconSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 6) {
            AppIconView(app: app, size: iconSize)
            if let app {
                Text(verbatim: app.name).lineLimit(1)
            } else {
                Text("None").foregroundStyle(.secondary)
            }
        }
    }
}

/// App icon for menus, which render images at their intrinsic size.
struct AppMenuIcon: View {
    let app: AppInfo

    var body: some View {
        Image(nsImage: IconCache.shared.menuIcon(for: app.url))
    }
}
