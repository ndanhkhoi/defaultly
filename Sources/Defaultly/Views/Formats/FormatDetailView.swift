import DefaultlyCore
import SwiftUI
import UniformTypeIdentifiers

/// Everything about one format, with the most common actions first.
struct FormatDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.undoManager) private var undoManager
    let format: FileFormat

    private let visibleApps = 4

    var body: some View {
        let status = model.statuses[format.ext]
        let others = (status?.candidates ?? []).filter { !$0.isSameApp(as: status?.current) }

        Form {
            Section {
                HStack(spacing: 12) {
                    ExtensionBadge(ext: format.ext, tint: model.tint(for: format), isLarge: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: format.displayName).font(.title3.weight(.semibold))
                        Text(verbatim: model.category(of: format)?.displayName ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Opens With") {
                if model.inFlight.contains(format.ext) {
                    HStack { ProgressView().controlSize(.small); Text("Applying…") }
                } else if let app = status?.current {
                    HStack(spacing: 10) {
                        AppIconView(app: app, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: app.name).font(.headline)
                            Text(verbatim: app.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
                            .controlSize(.small)
                    }
                } else {
                    Label("No app is set to open this format yet.", systemImage: "exclamationmark.triangle")
                }
            }

            Section {
                if others.isEmpty {
                    Text("No other installed app says it can open this format.")
                        .foregroundStyle(.secondary)
                }
                ForEach(others.prefix(visibleApps)) { app in
                    candidateRow(app)
                }
                if others.count > visibleApps {
                    DisclosureGroup("\(others.count - visibleApps) More Apps") {
                        ForEach(others.dropFirst(visibleApps)) { app in
                            candidateRow(app)
                        }
                    }
                }
                Button("Choose Another App…") {
                    if let app = AppChoice.pickApp(model: model, navigation: navigation) { makeDefault(app) }
                }
                .disabled(model.isApplying)
            } header: {
                Text("Other Apps That Can Open It")
            }

            if let related = model.relatedFormats(to: format) {
                Section("Related Formats") {
                    Text("\(related.app.name) can also open \(related.formats.count) related formats that currently open with other apps.")
                        .fixedSize(horizontal: false, vertical: true)
                    FormatBadges(formats: related.formats)
                    Button("Use \(related.app.name) for These Too") {
                        let assignments = related.formats.map { Assignment(ext: $0.ext, app: related.app) }
                        let title = AppModel.title(setting: related.app, count: assignments.count)
                        Task { await model.apply(assignments, named: title, undoManager: undoManager) }
                    }
                    .disabled(model.isApplying)
                }
            }

            Section {
                DisclosureGroup("Technical Details") {
                    TechnicalDetails(ext: format.ext)
                }
            }

            if let custom = model.customFormat(for: format.ext) {
                Section {
                    Button("Edit Custom Format…") { navigation.sheet = .editCustomFormat(custom) }
                    Button("Remove from Custom Formats", role: .destructive) {
                        model.removeCustomFormats([format.ext], undoManager: undoManager)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func candidateRow(_ app: AppInfo) -> some View {
        HStack(spacing: 8) {
            AppLabel(app: app, iconSize: 22)
            Spacer()
            Button("Make Default") { makeDefault(app) }
                .controlSize(.small)
                .disabled(model.isApplying)
        }
    }

    private func makeDefault(_ app: AppInfo) {
        let title = AppModel.title(setting: app, count: 1)
        Task { await model.apply([Assignment(ext: format.ext, app: app)], named: title, undoManager: undoManager) }
    }
}

private struct TechnicalDetails: View {
    let ext: FileExtension

    var body: some View {
        let types = ext.contentTypes
        LabeledContent("Content Types") {
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(types, id: \.identifier) { type in
                    Text(verbatim: type.identifier).font(.caption.monospaced())
                }
                if types.isEmpty { Text(verbatim: "—") }
            }
            .textSelection(.enabled)
        }
        LabeledContent("System Description") {
            Text(verbatim: ext.systemDescription ?? "—").textSelection(.enabled)
        }
        LabeledContent("MIME Type") {
            Text(verbatim: types.first?.preferredMIMEType ?? "—").font(.caption.monospaced()).textSelection(.enabled)
        }
    }
}
