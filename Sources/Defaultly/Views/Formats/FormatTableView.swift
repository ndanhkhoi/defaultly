import DefaultlyCore
import SwiftUI

struct FormatRow: Identifiable {
    let format: FileFormat
    let status: FormatStatus?

    var id: FileExtension { format.ext }
    var ext: String { format.ext.rawValue }
    var appName: String { status?.current?.name ?? "" }
}

/// The content column for format lists: a sortable, multi-select table.
struct FormatTableView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    let scope: FormatScope

    @State private var sortOrder = [KeyPathComparator(\FormatRow.ext)]

    var body: some View {
        @Bindable var navigation = navigation
        let formats = model.formats(in: scope)
        let rows = formats.map { FormatRow(format: $0, status: model.statuses[$0.ext]) }
        let sortedRows = isSearch ? rows : rows.sorted(using: sortOrder)

        Group {
            if rows.isEmpty {
                emptyState
            } else {
                Table(sortedRows, selection: $navigation.formatSelection, sortOrder: $sortOrder) {
                    TableColumn("Format", value: \.ext) { row in
                        FormatCell(format: row.format, showsCategory: showsCategory)
                    }
                    .width(min: 180, ideal: 260)
                    TableColumn("Opens With", value: \.appName) { row in
                        DefaultAppCell(status: row.status, isApplying: model.inFlight.contains(row.format.ext))
                    }
                    .width(min: 140, ideal: 200)
                }
                .contextMenu(forSelectionType: FileExtension.self) { selection in
                    FormatContextMenu(formats: formats.filter { selection.contains($0.ext) })
                }
            }
        }
        .navigationTitle(title)
        .navigationSubtitle(Text("\(formats.count) formats"))
        .toolbar {
            ToolbarItemGroup {
                AppChoiceMenu(formats: formats.filter { navigation.formatSelection.contains($0.ext) })
                Button {
                    navigation.sheet = .newCustomFormats(prefill: "")
                } label: {
                    Label("Add Custom Format", systemImage: "plus")
                }
                .help("Add a file extension that isn't in the catalog")
            }
        }
    }

    private var isSearch: Bool {
        if case .search = scope { true } else { false }
    }

    private var showsCategory: Bool {
        switch scope {
        case .all, .search, .custom: true
        case .category: false
        }
    }

    private var title: String {
        switch scope {
        case .all: String(localized: "All Formats")
        case .category(let id): model.library.category(id: id)?.displayName ?? ""
        case .custom: model.library.customCategory.displayName
        case .search: String(localized: "Search Results")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch scope {
        case .search(let query):
            ContentUnavailableView {
                Label("No Formats Match “\(query)”", systemImage: "magnifyingglass")
            } description: {
                Text("Check the spelling, or add it as your own format.")
            } actions: {
                if let ext = FileExtension(query), model.library.format(for: ext) == nil {
                    Button("Add \(ext.description) as Custom Format") {
                        navigation.sheet = .newCustomFormats(prefill: ext.rawValue)
                    }
                    .glassButton(prominent: true)
                }
            }
        default:
            ContentUnavailableView {
                Label("No Custom Formats", systemImage: "tag")
            } description: {
                Text("Add any file extension that isn't in the catalog, then choose which app opens it.")
            } actions: {
                Button("Add Custom Format…") {
                    navigation.sheet = .newCustomFormats(prefill: "")
                }
                .glassButton(prominent: true)
            }
        }
    }
}

private struct FormatCell: View {
    @Environment(AppModel.self) private var model
    let format: FileFormat
    let showsCategory: Bool

    var body: some View {
        HStack(spacing: 8) {
            ExtensionBadge(ext: format.ext, tint: model.tint(for: format))
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: format.displayName).lineLimit(1)
                if showsCategory, let category = model.category(of: format) {
                    Text(verbatim: category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DefaultAppCell: View {
    let status: FormatStatus?
    let isApplying: Bool

    var body: some View {
        if isApplying {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Applying…").foregroundStyle(.secondary)
            }
        } else if let app = status?.current {
            AppLabel(app: app)
        } else {
            Label("No default app", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        }
    }
}

/// Row actions; the same "Open With" items as the toolbar.
private struct FormatContextMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.undoManager) private var undoManager
    let formats: [FileFormat]

    var body: some View {
        if !formats.isEmpty {
            Menu("Open With") {
                AppChoiceMenuItems(formats: formats)
            }
            Divider()
            if formats.count == 1, let format = formats.first {
                if let app = model.statuses[format.ext]?.current {
                    Button("Show \(app.name) in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([app.url])
                    }
                }
                if let custom = model.customFormat(for: format.ext) {
                    Button("Edit Custom Format…") { navigation.sheet = .editCustomFormat(custom) }
                }
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(formats.map(\.ext.description).joined(separator: " "), forType: .string)
            } label: {
                if formats.count == 1 { Text("Copy Extension") } else { Text("Copy Extensions") }
            }
            let custom = formats.filter(\.isCustom)
            if !custom.isEmpty {
                Divider()
                Button("Remove from Custom Formats", role: .destructive) {
                    model.removeCustomFormats(Set(custom.map(\.ext)), undoManager: undoManager)
                }
            }
        }
    }
}
