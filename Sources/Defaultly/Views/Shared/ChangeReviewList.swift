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
                ForEach(group.indices, id: \.self) { index in
                    Toggle(isOn: $items[index].isIncluded) {
                        ChangeRow(item: items[index], showsTarget: showsTarget)
                    }
                    .toggleStyle(.checkbox)
                }
            } header: {
                HStack {
                    Text(verbatim: group.name)
                    Spacer()
                    let allIncluded = group.indices.allSatisfy { items[$0].isIncluded }
                    Button {
                        for index in group.indices { items[index].isIncluded = !allIncluded }
                    } label: {
                        if allIncluded { Text("Deselect All") } else { Text("Select All") }
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
            }
        }
    }

    private var groups: [(id: String, name: String, indices: [Int])] {
        var order: [String] = []
        var indicesByCategory: [String: [Int]] = [:]
        for (index, item) in items.enumerated() {
            let id = item.format.categoryID
            if indicesByCategory[id] == nil { order.append(id) }
            indicesByCategory[id, default: []].append(index)
        }
        return order.map { id in
            let name = model.library.category(id: id)?.displayName ?? id
            return (id, name, indicesByCategory[id] ?? [])
        }
    }
}

private struct ChangeRow: View {
    @Environment(AppModel.self) private var model
    let item: PlanItem
    let showsTarget: Bool

    var body: some View {
        HStack(spacing: 8) {
            ExtensionBadge(ext: item.format.ext, tint: model.tint(for: item.format))
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
    var cancel: (() -> Void)?
    let apply: () -> Void

    var body: some View {
        let included = items.filter(\.isIncluded).count
        HStack(spacing: 12) {
            Text("\(included) of \(items.count) selected")
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
