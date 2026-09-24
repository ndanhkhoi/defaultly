import DefaultlyCore
import SwiftUI

/// Pending changes grouped by category, each with a checkbox. Shared by every review screen.
struct ChangeReviewList: View {
    @Environment(AppModel.self) private var model
    @Binding var items: [PlanItem]
    /// Show the target app on each row when changes go to different apps.
    var showsTarget = false

    var body: some View {
        ForEach(groups, id: \.id) { group in
            Section {
                ForEach(group.items) { item in
                    Toggle(isOn: isIncluded(item.id)) {
                        ChangeRow(item: item, tint: model.tint(for: item.format), showsTarget: showsTarget)
                    }
                    .toggleStyle(.checkbox)
                }
            } header: {
                HStack {
                    Text(verbatim: group.name)
                    Spacer()
                    let allIncluded = group.items.allSatisfy(\.isIncluded)
                    Button {
                        setIncluded(!allIncluded, for: Set(group.items.map(\.id)))
                    } label: {
                        if allIncluded { Text("Deselect All") } else { Text("Select All") }
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
            }
        }
    }

    /// Bound by ID rather than index, so replacing `items` with a shorter list can't go out of range.
    private func isIncluded(_ id: FileExtension) -> Binding<Bool> {
        Binding(
            get: { items.first { $0.id == id }?.isIncluded ?? false },
            set: { setIncluded($0, for: [id]) }
        )
    }

    private func setIncluded(_ isIncluded: Bool, for ids: Set<FileExtension>) {
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isIncluded = isIncluded
        }
    }

    private var groups: [(id: String, name: String, items: [PlanItem])] {
        var order: [String] = []
        var itemsByCategory: [String: [PlanItem]] = [:]
        for item in items {
            let id = item.format.categoryID
            if itemsByCategory[id] == nil { order.append(id) }
            itemsByCategory[id, default: []].append(item)
        }
        return order.map { id in
            let name = model.library.category(id: id)?.displayName ?? id
            return (id, name, itemsByCategory[id] ?? [])
        }
    }
}

/// A list row: takes plain values and never reads the environment (see `FormatRow`).
private struct ChangeRow: View {
    let item: PlanItem
    let tint: Color
    let showsTarget: Bool

    var body: some View {
        HStack(spacing: 8) {
            ExtensionBadge(ext: item.format.ext, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.format.displayName).lineLimit(1)
                HStack(spacing: 4) {
                    AppLabel(app: item.current, iconSize: 12)
                    if showsTarget {
                        Image(systemName: "arrow.right").accessibilityLabel(Text("to"))
                        AppLabel(app: item.target, iconSize: 12)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !item.isSupported {
                    Label("\(item.target.name) doesn't list this format", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("The app doesn't declare support. macOS may refuse the change, or the app may not open these files correctly.")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The pinned bottom bar of every review screen (Fitts's law: large, always in the same place).
struct ApplyBar: View {
    @Environment(AppModel.self) private var model
    let items: [PlanItem]
    /// Changes outside `items` that Apply also makes, such as custom formats a backup re-creates.
    var otherChanges = 0
    var cancel: (() -> Void)?
    let apply: () -> Void

    var body: some View {
        let included = items.filter(\.isIncluded).count + otherChanges
        HStack(spacing: 12) {
            Text("\(included) of \(items.count + otherChanges) selected")
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
            if let cancel {
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
            }
            Button(action: apply) {
                HStack(spacing: 6) {
                    if model.isApplying { ProgressView().controlSize(.small) }
                    Text("Apply \(included) Changes")
                }
            }
            .glassButton(prominent: true)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(included == 0 || model.isApplying)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
