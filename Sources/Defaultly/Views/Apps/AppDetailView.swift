import DefaultlyCore
import SwiftUI

/// Apps inspector column: what an app opens now, and formats to suggest for it.
struct AppDetailView: View {
    @Environment(AppModel.self) private var model
    let bundleID: String?

    var body: some View {
        if let app = model.installedApps.first(where: { $0.bundleID == bundleID }) {
            AppDetailContent(app: app).id(app.bundleID)
        } else {
            ContentUnavailableView(
                "No App Selected",
                systemImage: "app.badge.checkmark",
                description: Text("Select an app to see the formats it opens and the formats it could open.")
            )
        }
    }
}

private struct AppDetailContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.undoManager) private var undoManager
    let app: AppInfo

    @State private var suggestions: [PlanItem] = []
    @State private var isLoading = true

    var body: some View {
        let opened = model.formats(openedBy: app)
        Form {
            Section {
                HStack(spacing: 12) {
                    AppIconView(app: app, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: app.name).font(.title3.weight(.semibold))
                        Text(verbatim: app.bundleID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app.url]) }
                        .controlSize(.small)
                }
                .padding(.vertical, 2)
            }

            Section {
                if opened.isEmpty {
                    Text("\(app.name) isn't the default app for any format yet.")
                        .foregroundStyle(.secondary)
                } else {
                    FormatBadges(formats: opened, limit: 60)
                }
            } header: {
                Text("Default for \(opened.count) formats")
            }

            if isLoading {
                Section {
                    HStack { ProgressView().controlSize(.small); Text("Finding formats \(app.name) can open…") }
                }
            } else if suggestions.isEmpty {
                Section("Suggested Formats") {
                    Text("Nothing to suggest: \(app.name) already opens every format it supports.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    Text("\(app.name) can open these formats, but another app opens them now. Check the ones to switch.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text("Suggested Formats")
                }
                ChangeReviewList(items: $suggestions)
            }
        }
        .formStyle(.grouped)
        .bottomActionBar {
            if !suggestions.isEmpty {
                ApplyBar(items: suggestions) {
                    let plan = suggestions
                    let title = AppModel.title(setting: app, count: plan.filter(\.isIncluded).count)
                    Task { await model.apply(plan, named: title, undoManager: undoManager) }
                }
            }
        }
        .task(id: model.revision) {
            suggestions = PlanBuilder.keepingChoices(of: suggestions, in: await model.suggestions(for: app))
            isLoading = false
        }
    }
}
