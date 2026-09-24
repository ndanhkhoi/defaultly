import DefaultlyCore
import SwiftUI

/// Quick Setup inspector column.
struct SetupDetailView: View {
    @Environment(AppModel.self) private var model
    let setup: SetupTarget?

    var body: some View {
        switch setup {
        case .category(let id) where !(model.library.category(id: id)?.formats.isEmpty ?? true):
            if let category = model.library.category(id: id) {
                AssignmentPanel(
                    title: category.displayName,
                    subtitle: String(localized: "Choose one app for all \(category.formats.count) formats in this category."),
                    formats: category.formats
                )
                .id(id)
            }
        case .suite(let id):
            if let suite = model.suites.first(where: { $0.id == id }) {
                SuiteReviewView(suite: suite).id(id)
            }
        case .category, nil:
            // No setup chosen, or a category that became empty (e.g. its custom formats were removed).
            ContentUnavailableView(
                "Choose a Setup",
                systemImage: "wand.and.stars",
                description: Text("Pick a category or an app suite to switch many formats in one step. You'll review every change before it's applied.")
            )
        }
    }
}

/// Reviews what an app suite would change; each category goes to its suite app.
private struct SuiteReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    let suite: ResolvedSuite

    /// nil until the first plan is computed, so the screen never flashes "nothing to change".
    @State private var items: [PlanItem]?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    HStack(spacing: -10) {
                        ForEach(suite.apps) { AppIconView(app: $0, size: 40) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use \(suite.suite.name)").font(.title3.weight(.semibold))
                        Text("Open documents, spreadsheets and presentations with \(suite.apps.map(\.name).formatted(.list(type: .and))).")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
            if let items = Binding($items) {
                if items.wrappedValue.isEmpty {
                    Section {
                        Label("\(suite.suite.name) already opens all of these formats.", systemImage: "checkmark.circle")
                    }
                } else {
                    ChangeReviewList(items: items, showsTarget: suite.apps.count > 1)
                }
            } else {
                Section { ProgressView().controlSize(.small) }
            }
        }
        .formStyle(.grouped)
        .bottomActionBar {
            if let items, !items.isEmpty {
                ApplyBar(items: items) {
                    Task { await model.apply(items, named: String(localized: "Use \(suite.suite.name)"), undoManager: undoManager) }
                }
            }
        }
        .task(id: model.revision) {
            items = PlanBuilder.keepingChoices(of: items ?? [], in: plan())
        }
    }

    private func plan() -> [PlanItem] {
        let formats = suite.suite.members.flatMap { model.library.category(id: $0.categoryID)?.formats ?? [] }
        return PlanBuilder.items(for: formats, statuses: model.statuses) { suite.app(for: $0) }
    }
}
