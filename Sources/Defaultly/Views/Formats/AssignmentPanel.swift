import DefaultlyCore
import SwiftUI

/// Pick one app for a group of formats, review the pending changes, then apply.
/// Used for multi-selection, category quick setup, and the Quick Setup screen.
struct AssignmentPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.undoManager) private var undoManager
    let title: String
    let subtitle: String
    let formats: [FileFormat]

    @State private var chosenApp: AppInfo?
    @State private var items: [PlanItem] = []

    private let visibleApps = 4

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title).font(.title3.weight(.semibold))
                    Text(verbatim: subtitle).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            if let chosenApp {
                review(for: chosenApp)
            } else {
                choices
            }
        }
        .formStyle(.grouped)
        .bottomActionBar {
            if chosenApp != nil, !items.isEmpty {
                ApplyBar(items: items, cancel: reset, apply: apply)
            }
        }
        .onChange(of: formats) { reset() }
    }

    @ViewBuilder
    private var choices: some View {
        let ranked = model.supportingApps(for: formats)
        Section("Suggested Apps") {
            if ranked.isEmpty {
                Text("No installed app says it supports these formats. You can still choose any app.")
                    .foregroundStyle(.secondary)
            }
            ForEach(ranked.prefix(visibleApps)) { entry in
                suggestionRow(entry)
            }
            if ranked.count > visibleApps {
                DisclosureGroup("\(ranked.count - visibleApps) More Apps") {
                    ForEach(ranked.dropFirst(visibleApps)) { entry in
                        suggestionRow(entry)
                    }
                }
            }
            Button("Choose Another App…") {
                if let app = AppChoice.pickApp(model: model, navigation: navigation) { choose(app) }
            }
        }

        Section("Currently Opens With") {
            let defaults = model.currentDefaults(for: formats)
            ForEach(defaults) { entry in
                LabeledContent {
                    Text("\(entry.count) formats").monospacedDigit()
                } label: {
                    AppLabel(app: entry.app)
                }
            }
            let unassigned = formats.count - defaults.reduce(0) { $0 + $1.count }
            if unassigned > 0 {
                LabeledContent {
                    Text("\(unassigned) formats").monospacedDigit()
                } label: {
                    Label("No default app", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }

    private func suggestionRow(_ entry: AppCount) -> some View {
        HStack(spacing: 8) {
            AppIconView(app: entry.app, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: entry.app.name)
                Text("Supports \(entry.count) of \(formats.count) formats")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Review") { choose(entry.app) }
                .glassButton()
                .disabled(model.isApplying)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func review(for app: AppInfo) -> some View {
        Section {
            HStack(spacing: 8) {
                AppIconView(app: app, size: 28)
                Text("Open these formats with \(app.name)").font(.headline)
                Spacer()
                Button("Change App", action: reset)
            }
        }
        if items.isEmpty {
            Section {
                Label("\(app.name) already opens all of these formats.", systemImage: "checkmark.circle")
            }
        } else {
            ChangeReviewList(items: $items)
        }
    }

    private func choose(_ app: AppInfo) {
        chosenApp = app
        items = PlanBuilder.items(for: formats, assigning: app, statuses: model.statuses)
    }

    private func reset() {
        chosenApp = nil
        items = []
    }

    private func apply() {
        guard let app = chosenApp else { return }
        let plan = items
        let title = AppModel.title(setting: app, count: plan.filter(\.isIncluded).count)
        Task {
            await model.apply(plan, named: title, undoManager: undoManager)
            reset()
        }
    }
}
