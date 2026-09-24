import Foundation

/// "Open files with this extension using this app."
public struct Assignment: Hashable, Sendable {
    public let ext: FileExtension
    public let app: AppInfo

    public init(ext: FileExtension, app: AppInfo) {
        self.ext = ext
        self.app = app
    }
}

/// What happened when one assignment was applied and read back.
public struct AssignmentOutcome: Identifiable, Hashable, Sendable {
    public enum Result: Hashable, Sendable {
        case applied
        /// macOS reported success but kept (or chose) another app.
        case notAccepted(actual: AppInfo?)
        case failed(message: String)
    }

    public let assignment: Assignment
    /// The default app before the change, used to undo it.
    public let previous: AppInfo?
    public let result: Result

    public var id: FileExtension { assignment.ext }

    public init(assignment: Assignment, previous: AppInfo?, result: Result) {
        self.assignment = assignment
        self.previous = previous
        self.result = result
    }
}

/// The outcome of a batch of assignments.
public struct ApplyReport: Sendable {
    public let outcomes: [AssignmentOutcome]

    public init(outcomes: [AssignmentOutcome]) {
        self.outcomes = outcomes
    }

    public var appliedCount: Int { outcomes.count - issues.count }

    public var issues: [AssignmentOutcome] {
        outcomes.filter { $0.result != .applied }
    }

    /// Put back the apps that were default before this batch.
    /// Formats that had no previous default cannot be reverted, because macOS has no "unset" API.
    public var undoAssignments: [Assignment] {
        revertible.compactMap { outcome in
            outcome.previous.map { Assignment(ext: outcome.assignment.ext, app: $0) }
        }
    }

    /// Re-apply exactly what `undoAssignments` reverts.
    public var redoAssignments: [Assignment] {
        revertible.map(\.assignment)
    }

    private var revertible: [AssignmentOutcome] {
        outcomes.filter { outcome in
            outcome.result == .applied
                && outcome.previous != nil
                && !outcome.assignment.app.isSameApp(as: outcome.previous)
        }
    }
}
