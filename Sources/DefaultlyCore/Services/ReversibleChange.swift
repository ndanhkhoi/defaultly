import Foundation

/// A batch of changes registered with an `UndoManager` as soon as it starts, so ⌘Z pressed while
/// it is still applying undoes this batch rather than the one before. Undo and Redo mirror each other.
public struct ReversibleChange: Sendable {
    public enum Direction: Sendable {
        case undo, redo

        var flipped: Direction { self == .undo ? .redo : .undo }
    }

    public let title: String
    private let report: Task<ApplyReport, Never>

    /// `report` is the apply in progress; its outcome decides what Undo and Redo reapply.
    public init(title: String, report: Task<ApplyReport, Never>) {
        self.title = title
        self.report = report
    }

    /// Undoing calls `perform(report.undoAssignments, .undo)` once the report is ready; the mirrored
    /// action is registered first, while the manager is still undoing, so it lands on the Redo stack.
    /// If the finished batch has nothing to revert, the entry is removed again.
    @MainActor
    public func register(
        on undoManager: UndoManager,
        perform: @escaping @MainActor (_ assignments: [Assignment], _ direction: Direction) async -> Void
    ) {
        let token = Token()
        register(.undo, on: undoManager, token: token, perform: perform)
        let report = report
        Task { @MainActor in
            if await report.value.undoAssignments.isEmpty {
                undoManager.removeAllActions(withTarget: token)
            }
        }
    }

    @MainActor
    private func register(
        _ direction: Direction,
        on undoManager: UndoManager,
        token: Token,
        perform: @escaping @MainActor ([Assignment], Direction) async -> Void
    ) {
        // UndoManager doesn't retain targets; the handler (which it does keep) holds the token alive.
        undoManager.registerUndo(withTarget: token) { [token] _ in
            register(direction.flipped, on: undoManager, token: token, perform: perform)
            let report = report
            Task { @MainActor in
                let outcome = await report.value
                await perform(direction == .undo ? outcome.undoAssignments : outcome.redoAssignments, direction)
            }
        }
        undoManager.setActionName(title)
    }

    /// Identifies this change's entries on the undo stack.
    private final class Token {}
}
