import Foundation

/// A batch of changes and its inverse, registered with an `UndoManager` so Undo and Redo mirror each other.
public struct ReversibleChange: Sendable {
    public let title: String
    public let undo: [Assignment]
    public let redo: [Assignment]

    public init(title: String, report: ApplyReport) {
        self.init(title: title, undo: report.undoAssignments, redo: report.redoAssignments)
    }

    init(title: String, undo: [Assignment], redo: [Assignment]) {
        self.title = title
        self.undo = undo
        self.redo = redo
    }

    /// Undoing calls `perform(undo, true)`. The mirrored change is registered first, while the
    /// undo manager is still undoing, so it lands on the Redo stack (and vice versa for Redo).
    @MainActor
    public func register(
        on undoManager: UndoManager,
        target: AnyObject,
        perform: @escaping @MainActor (_ assignments: [Assignment], _ isUndo: Bool) -> Void
    ) {
        guard !undo.isEmpty else { return }
        undoManager.registerUndo(withTarget: target) { target in
            let isUndo = undoManager.isUndoing
            mirrored.register(on: undoManager, target: target, perform: perform)
            perform(undo, isUndo)
        }
        undoManager.setActionName(title)
    }

    private var mirrored: ReversibleChange {
        ReversibleChange(title: title, undo: redo, redo: undo)
    }
}
