import DefaultlyCore
import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        List(selection: $navigation.sidebar) {
            Section {
                Label("Quick Setup", systemImage: "wand.and.stars")
                    .tag(SidebarItem.quickSetup)
                Label("All Formats", systemImage: "square.grid.2x2")
                    .badge(model.library.allFormats.count)
                    .tag(SidebarItem.allFormats)
                Label("Apps", systemImage: "square.stack.3d.up")
                    .badge(model.installedApps.count)
                    .tag(SidebarItem.apps)
            }
            Section("Categories") {
                ForEach(model.library.categories) { category in
                    Label {
                        Text(verbatim: category.displayName)
                    } icon: {
                        Image(systemName: category.symbol).foregroundStyle(category.tint.color)
                    }
                    .badge(category.formats.count)
                    .tag(SidebarItem.category(category.id))
                }
            }
            Section("Yours") {
                Label {
                    Text(verbatim: model.library.customCategory.displayName)
                } icon: {
                    Image(systemName: model.library.customCategory.symbol)
                }
                .badge(model.library.customCategory.formats.count)
                .tag(SidebarItem.custom)
            }
        }
        .listStyle(.sidebar)
    }
}
