import DefaultlyCore
import SwiftUI

/// Explains each format that did not change, with a way forward for each one.
struct IssuesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let summary: ApplySummary
    let undoManager: UndoManager?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Some Formats Weren't Changed", systemImage: "exclamationmark.triangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(verbatim: summary.message).foregroundStyle(.secondary)
            }
            .padding(16)

            List(summary.issues) { issue in
                let format = model.library.format(for: issue.assignment.ext)
                IssueRow(
                    issue: issue,
                    name: format?.displayName ?? issue.assignment.ext.description,
                    tint: format.map(model.tint(for:)) ?? .gray,
                    isApplying: model.isApplying
                ) {
                    chooseAnotherApp(for: issue.assignment.ext)
                }
            }

            HStack {
                Button("Retry All") {
                    Task { await model.retry(summary, undoManager: undoManager) }
                    dismiss()
                }
                .disabled(model.isApplying)
                Spacer()
                Button("Done") { dismiss() }
                    .glassButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 560, height: 440)
    }

    private func chooseAnotherApp(for ext: FileExtension) {
        guard let app = AppChoice.pickApp(model: model, navigation: navigation) else { return }
        Task { await model.apply([Assignment(ext: ext, app: app)], named: AppModel.title(setting: app, count: 1), undoManager: undoManager) }
        dismiss()
    }
}

/// A list row: takes plain values and never reads the environment (see `FormatRow`).
private struct IssueRow: View {
    let issue: AssignmentOutcome
    let name: String
    let tint: Color
    let isApplying: Bool
    let chooseAnotherApp: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ExtensionBadge(ext: issue.assignment.ext, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: name).font(.headline)
                Text(verbatim: reason).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Choose Another App…", action: chooseAnotherApp)
                .controlSize(.small)
                .disabled(isApplying)
        }
        .padding(.vertical, 4)
    }

    private var reason: String {
        let app = issue.assignment.app.name
        switch issue.result {
        case .applied:
            return ""
        case .notAccepted(let actual):
            let kept = actual?.name ?? String(localized: "no app")
            return String(localized: "macOS kept \(kept). Another app may own this format, or the change wasn't confirmed. Retry and allow it when macOS asks, or choose another app.")
        case .failed(let message):
            return String(localized: "Couldn't set \(app): \(message)")
        }
    }
}
