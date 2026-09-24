import DefaultlyCore
import SwiftUI

/// Sidebar → content → inspector.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 300)
        } content: {
            ContentColumn()
                .navigationSplitViewColumnWidth(min: 360, ideal: 500, max: 800)
        } detail: {
            DetailColumn()
                .navigationSplitViewColumnWidth(min: 320, ideal: 400)
        }
        .searchable(
            text: $navigation.searchText,
            placement: .sidebar,
            prompt: navigation.sidebar == .apps ? Text("Search Apps") : Text("Search Formats")
        )
        .searchSuggestions {
            if navigation.isSearchingFormats {
                ForEach(model.library.search(navigation.searchText) { $0.displayName }.prefix(6)) { format in
                    Label {
                        Text(verbatim: "\(format.ext.description)  \(format.displayName)")
                    } icon: {
                        Image(systemName: model.category(of: format)?.symbol ?? "doc")
                    }
                    .searchCompletion(format.ext.rawValue)
                }
            }
        }
        .toolbar { MainToolbar() }
        .sheet(item: $navigation.sheet) { route in
            switch route {
            case .newCustomFormats(let prefill): CustomFormatSheet(mode: .add(prefill: prefill))
            case .editCustomFormat(let format): CustomFormatSheet(mode: .edit(format))
            // Sheets get the main window's undo manager so their changes stay undoable after closing.
            case .restore(let preview): RestoreSheet(preview: preview, undoManager: undoManager)
            case .issues(let summary): IssuesSheet(summary: summary, undoManager: undoManager)
            }
        }
        .alert(
            navigation.alert?.title ?? "",
            isPresented: Binding(get: { navigation.alert != nil }, set: { if !$0 { navigation.alert = nil } }),
            presenting: navigation.alert
        ) { alert in
            if let actionTitle = alert.actionTitle, let action = alert.action {
                Button(actionTitle) { action() }
            }
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(verbatim: alert.message)
        }
        .task { await model.loadIfNeeded() }
        // Picking a sidebar item leaves a format search; revealing a format clears it first anyway.
        .onChange(of: navigation.sidebar) { navigation.searchText = "" }
    }
}

private struct ContentColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation

    var body: some View {
        Group {
            if !model.hasLoaded {
                ProgressView { Text("Reading file associations…") }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let scope = navigation.formatScope {
                FormatTableView(scope: scope)
            } else if navigation.sidebar == .quickSetup {
                SetupListView()
            } else if navigation.sidebar == .apps {
                AppListView()
            } else {
                ContentUnavailableView("Choose a Section", systemImage: "sidebar.left")
            }
        }
        .overlay(alignment: .bottom) { ActivityOverlay() }
    }
}

private struct DetailColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation

    var body: some View {
        if !model.hasLoaded {
            Color.clear
        } else if let scope = navigation.formatScope {
            FormatInspector(scope: scope)
        } else if navigation.sidebar == .quickSetup {
            SetupDetailView(setup: navigation.setupSelection)
        } else if navigation.sidebar == .apps {
            AppDetailView(bundleID: navigation.appSelection)
        } else {
            Color.clear
        }
    }
}

private struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.isLoading && model.hasLoaded {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await model.reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Read file associations again (⌘R)")
                .disabled(model.isApplying)
            }
            Menu {
                Button("Export Backup…") { BackupFlow(model: model, navigation: navigation).export() }
                Button("Restore from Backup…") { Task { await BackupFlow(model: model, navigation: navigation).restore() } }
            } label: {
                Label("Backup", systemImage: "externaldrive")
            }
            .help("Export or restore your file associations")
            .disabled(!model.hasLoaded || model.isApplying)
        }
    }
}
