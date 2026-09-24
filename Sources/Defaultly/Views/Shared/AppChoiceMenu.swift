import DefaultlyCore
import SwiftUI

/// "Open With" for one or more formats: ranked supporting apps, then any other app.
/// Toolbar items and menus are hosted by AppKit, so dependencies are passed in, not read from the
/// environment (see `FormatRow`).
struct AppChoiceMenu: View {
    let formats: [FileFormat]
    let model: AppModel
    let navigation: Navigation
    let undoManager: UndoManager?

    var body: some View {
        Menu {
            AppChoiceMenuItems(formats: formats, model: model, navigation: navigation, undoManager: undoManager)
        } label: {
            Label("Open With", systemImage: "arrow.up.forward.app")
        }
        .disabled(formats.isEmpty || model.isApplying)
        .help("Choose the app that opens the selected formats")
    }
}

struct AppChoiceMenuItems: View {
    let formats: [FileFormat]
    let model: AppModel
    let navigation: Navigation
    let undoManager: UndoManager?

    private let visibleCount = 8

    var body: some View {
        let ranked = model.supportingApps(for: formats)
        ForEach(ranked.prefix(visibleCount)) { entry in
            button(for: entry)
        }
        if ranked.count > visibleCount {
            Menu("More Apps") {
                ForEach(ranked.dropFirst(visibleCount)) { entry in
                    button(for: entry)
                }
            }
        }
        if !ranked.isEmpty {
            Divider()
        }
        Button("Other App…") {
            if let app = AppChoice.pickApp(model: model, navigation: navigation) {
                assign(app)
            }
        }
    }

    private func button(for entry: AppCount) -> some View {
        Button {
            assign(entry.app)
        } label: {
            Label {
                if formats.count > 1 {
                    Text("\(entry.app.name) (\(entry.count) of \(formats.count))")
                } else {
                    Text(verbatim: entry.app.name)
                }
            } icon: {
                AppMenuIcon(app: entry.app)
            }
        }
    }

    private func assign(_ app: AppInfo) {
        let assignments = formats.map { Assignment(ext: $0.ext, app: app) }
        let title = AppModel.title(setting: app, count: formats.count)
        Task { await model.apply(assignments, named: title, undoManager: undoManager) }
    }
}

@MainActor
enum AppChoice {
    /// Shows the app picker; reports anything that is not an app instead of failing silently.
    static func pickApp(model: AppModel, navigation: Navigation) -> AppInfo? {
        guard let url = AppPicker.chooseApp() else { return nil }
        if let app = model.app(at: url) { return app }
        navigation.alert = AlertRoute(
            title: String(localized: "That Item Can't Open Files"),
            message: String(localized: "“\(url.lastPathComponent)” isn't an app that macOS can use as a default. Choose an app from the Applications folder.")
        )
        return nil
    }
}
