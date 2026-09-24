import Foundation
import Testing
@testable import DefaultlyCore

@MainActor
struct ReversibleChangeTests {
    final class Recorder {
        var calls: [(assignments: [Assignment], direction: ReversibleChange.Direction)] = []
    }

    let wordToLibre = AssignmentOutcome(assignment: Assignment(ext: .ext("docx"), app: .libre), previous: .word, result: .applied)
    var toWord: [Assignment] { [Assignment(ext: .ext("docx"), app: .word)] }
    var toLibre: [Assignment] { [Assignment(ext: .ext("docx"), app: .libre)] }

    func undoManager() -> UndoManager {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        return undoManager
    }

    func register(_ report: Task<ApplyReport, Never>, on undoManager: UndoManager, recorder: Recorder) {
        undoManager.beginUndoGrouping()
        ReversibleChange(title: "Set LibreOffice", report: report).register(on: undoManager) { assignments, direction in
            recorder.calls.append((assignments, direction))
        }
        undoManager.endUndoGrouping()
    }

    /// Lets queued main-actor tasks (the undo handlers' work) run.
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    @Test func undoAndRedoMirrorEachOther() async {
        let recorder = Recorder()
        let manager = undoManager()
        register(Task { ApplyReport(outcomes: [wordToLibre]) }, on: manager, recorder: recorder)
        await settle()
        #expect(manager.undoActionName == "Set LibreOffice")

        manager.undo()
        await settle()
        #expect(recorder.calls.map(\.assignments) == [toWord])
        #expect(recorder.calls.map(\.direction) == [.undo])
        #expect(manager.canRedo)

        manager.redo()
        await settle()
        #expect(recorder.calls.map(\.assignments) == [toWord, toLibre])
        #expect(recorder.calls.map(\.direction) == [.undo, .redo])
        #expect(manager.canUndo)
    }

    @Test func undoPressedDuringTheApplyUndoesThatApply() async {
        let recorder = Recorder()
        let manager = undoManager()
        let (gate, open) = AsyncStream<Void>.makeStream()
        let outcome = wordToLibre
        let report = Task {
            for await _ in gate { break }
            return ApplyReport(outcomes: [outcome])
        }
        register(report, on: manager, recorder: recorder)
        #expect(manager.canUndo)

        manager.undo()
        await settle()
        #expect(recorder.calls.isEmpty)

        open.yield()
        await report.value
        await settle()
        #expect(recorder.calls.map(\.assignments) == [toWord])
    }

    @Test func nothingToRevertLeavesNoUndoEntry() async {
        let manager = undoManager()
        let noPrevious = AssignmentOutcome(assignment: Assignment(ext: .ext("docx"), app: .libre), previous: nil, result: .applied)
        register(Task { ApplyReport(outcomes: [noPrevious]) }, on: manager, recorder: Recorder())
        await settle()
        #expect(!manager.canUndo)
    }
}
