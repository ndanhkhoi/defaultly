import DefaultlyCore
import SwiftUI

/// Floating status for applying, success (with Undo) and errors (with recovery).
struct ActivityOverlay: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        Group {
            switch model.activity {
            case .idle:
                EmptyView()
            case .applying(let title, let count):
                capsule {
                    ProgressView().controlSize(.small)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Applying \(count) changes…").font(.callout.weight(.medium))
                        Text(verbatim: title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            case .finished(let summary):
                finished(summary)
            }
        }
        .padding(.bottom, 14)
        .padding(.horizontal, 14)
        .animation(.snappy, value: model.activity)
    }

    private func finished(_ summary: ApplySummary) -> some View {
        capsule {
            Image(systemName: summary.hasIssues ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(summary.hasIssues ? Color.orange : Color.green)
                .imageScale(.large)
                .accessibilityHidden(true)
            Text(verbatim: summary.message)
                .font(.callout.weight(.medium))
                .lineLimit(2)
            if summary.hasIssues {
                Button("Details") { navigation.sheet = .issues(summary) }
                    .glassButton()
                Button("Retry") { Task { await model.retry(summary, undoManager: undoManager) } }
                    .glassButton()
                    .disabled(model.isApplying)
            } else if summary.offersUndo, isLatestUndo(summary) {
                Button("Undo") {
                    // Re-check at click time: another undoable action may have happened since.
                    if isLatestUndo(summary) { undoManager?.undo() }
                    model.activity = .idle
                }
                .glassButton()
            }
            Button {
                model.activity = .idle
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Dismiss")
            .accessibilityLabel(Text("Dismiss"))
        }
        .task(id: summary.id) {
            guard !summary.hasIssues else { return }
            try? await Task.sleep(for: .seconds(8))
            if model.activity == .finished(summary) { model.activity = .idle }
        }
    }

    /// The toast's Undo must undo this change, not whatever happens to be on top of the stack.
    private func isLatestUndo(_ summary: ApplySummary) -> Bool {
        undoManager?.canUndo == true && undoManager?.undoActionName == summary.title
    }

    private func capsule(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 10, content: content)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .floatingGlass(in: Capsule())
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .contain)
    }
}
