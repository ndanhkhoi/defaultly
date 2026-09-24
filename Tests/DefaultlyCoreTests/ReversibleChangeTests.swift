import Foundation
import Testing
@testable import DefaultlyCore

@MainActor
struct ReversibleChangeTests {
    final class Recorder {
        var calls: [(assignments: [Assignment], isUndo: Bool)] = []
    }

    let toWord = [Assignment(ext: .ext("docx"), app: .word)]
    let toLibre = [Assignment(ext: .ext("docx"), app: .libre)]

    func registered(_ change: ReversibleChange, recorder: Recorder, target: AnyObject) -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.beginUndoGrouping()
        change.register(on: undoManager, target: target) { recorder.calls.append(($0, $1)) }
        undoManager.endUndoGrouping()
        return undoManager
    }

    @Test func undoAndRedoMirrorEachOther() {
        let recorder = Recorder()
        let target = NSObject()
        let undoManager = registered(ReversibleChange(title: "Set LibreOffice", undo: toWord, redo: toLibre), recorder: recorder, target: target)
        #expect(undoManager.undoActionName == "Set LibreOffice")

        undoManager.undo()
        #expect(recorder.calls.map(\.assignments) == [toWord])
        #expect(recorder.calls.map(\.isUndo) == [true])
        #expect(undoManager.canRedo)

        undoManager.redo()
        #expect(recorder.calls.map(\.assignments) == [toWord, toLibre])
        #expect(recorder.calls.map(\.isUndo) == [true, false])
        #expect(undoManager.canUndo)

        undoManager.undo()
        #expect(recorder.calls.last?.assignments == toWord)
    }

    @Test func nothingToRevertRegistersNothing() {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        ReversibleChange(title: "Nothing", undo: [], redo: []).register(on: undoManager, target: NSObject()) { _, _ in }
        #expect(!undoManager.canUndo)
        #expect(undoManager.undoActionName.isEmpty)
    }
}
