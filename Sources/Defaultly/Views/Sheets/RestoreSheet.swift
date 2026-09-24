import DefaultlyCore
import SwiftUI

/// Previews a backup before restoring it.
struct RestoreSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let preview: RestorePreview
    let undoManager: UndoManager?

    @State private var items: [PlanItem] = []

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restore Backup").font(.title3.weight(.semibold))
                        Text("Created \(preview.backup.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(preview.backup.associations.count) formats")
                            .foregroundStyle(.secondary)
                    }
                    if !preview.newCustomFormats.isEmpty {
                        Label(
                            "Adds \(preview.newCustomFormats.count) custom formats: \(preview.newCustomFormats.map(\.ext.description).joined(separator: " "))",
                            systemImage: "tag"
                        )
                    }
                    if !preview.missingApps.isEmpty {
                        DisclosureGroup {
                            ForEach(preview.missingApps, id: \.ext) { entry in
                                LabeledContent(entry.ext.description, value: entry.appName)
                            }
                        } label: {
                            Label(
                                "\(preview.missingApps.count) formats will be skipped because their app isn't installed.",
                                systemImage: "exclamationmark.triangle"
                            )
                        }
                    }
                    if items.isEmpty {
                        Label("Everything already matches this backup.", systemImage: "checkmark.circle")
                    }
                }
                ChangeReviewList(items: $items, showsTarget: true)
            }
            .formStyle(.grouped)

            ApplyBar(items: items, cancel: { dismiss() }) {
                let plan = items
                Task {
                    await model.restore(preview, items: plan, undoManager: undoManager)
                    dismiss()
                }
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 480, idealHeight: 620)
        .onAppear { items = preview.items }
    }
}
