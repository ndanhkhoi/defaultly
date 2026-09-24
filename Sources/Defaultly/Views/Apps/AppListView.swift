import DefaultlyCore
import SwiftUI

/// Apps content column: apps that are defaults first, then everything else installed.
struct AppListView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        let counts = model.defaultCounts
        let apps = filteredApps
        let defaults = apps.filter { counts[$0.bundleID, default: 0] > 0 }
        let others = apps.filter { counts[$0.bundleID, default: 0] == 0 }

        Group {
            if apps.isEmpty {
                ContentUnavailableView.search(text: navigation.searchText)
            } else {
                List(selection: $navigation.appSelection) {
                    if !defaults.isEmpty {
                        Section("Default Apps") {
                            ForEach(defaults) { AppRow(app: $0, count: counts[$0.bundleID, default: 0]).tag($0.bundleID) }
                        }
                    }
                    if !others.isEmpty {
                        Section("Other Apps") {
                            ForEach(others) { AppRow(app: $0, count: 0).tag($0.bundleID) }
                        }
                    }
                }
            }
        }
        .navigationTitle(Text("Apps"))
        .navigationSubtitle(Text("\(model.installedApps.count) installed"))
    }

    private var filteredApps: [AppInfo] {
        let query = navigation.searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.installedApps }
        return model.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query)
        }
    }
}

private struct AppRow: View {
    let app: AppInfo
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(app: app, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: app.name).lineLimit(1)
                Group {
                    if count > 0 {
                        Text("Default for \(count) formats")
                    } else {
                        Text("Not a default app")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
