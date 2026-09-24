import DefaultlyCore
import Foundation
import Testing
@testable import Defaultly

/// The model's serial queue of loads and applies, with an in-memory LaunchServices.
@MainActor
struct AppModelTests {
    @Test func anApplyShowsTheNewDefaultAndCanBeUndone() async {
        let harness = await Harness()
        await harness.apply([Assignment(ext: .png, app: .preview)])
        #expect(harness.model.statuses[.png]?.current == .preview)
        guard case .finished(let summary) = harness.model.activity else {
            Issue.record("expected a summary, got \(harness.model.activity)")
            return
        }
        #expect(!summary.hasIssues)
        #expect(summary.offersUndo)

        harness.undoManager.undo()
        #expect(await harness.eventually { harness.model.statuses[.png]?.current == .textEdit })
    }

    @Test func aReloadDuringAnApplyWaitsForIt() async {
        let harness = await Harness(holdingWrites: true)
        let applying = await harness.startApplying([Assignment(ext: .png, app: .preview)])
        await harness.untilAWriteIsHeld()
        let readsBefore = harness.launchServices.reads
        let reloading = Task { await harness.model.reload() }
        try? await Task.sleep(for: .milliseconds(50))
        // Reading now could show the default from before the change after the apply has finished.
        #expect(harness.launchServices.reads == readsBefore)

        harness.launchServices.releaseWrites()
        await applying.value
        await reloading.value
        #expect(harness.model.statuses[.png]?.current == .preview)
    }

    @Test func undoPressedDuringAnApplyUndoesThatApply() async {
        let harness = await Harness()
        await harness.apply([Assignment(ext: .txt, app: .preview)])
        harness.launchServices.holdWrites()
        let applying = await harness.startApplying([Assignment(ext: .png, app: .preview)])
        await harness.untilAWriteIsHeld()

        harness.undoManager.undo()
        harness.launchServices.releaseWrites()
        await applying.value
        #expect(await harness.eventually { harness.model.statuses[.png]?.current == .textEdit })
        #expect(harness.model.statuses[.txt]?.current == .preview)
    }

    @Test func retryReappliesOnlyWhatFailed() async {
        let harness = await Harness(failing: [.jpg])
        await harness.apply([Assignment(ext: .png, app: .preview), Assignment(ext: .jpg, app: .preview)])
        guard case .finished(let summary) = harness.model.activity else {
            Issue.record("expected a summary, got \(harness.model.activity)")
            return
        }
        #expect(summary.retryable == [Assignment(ext: .jpg, app: .preview)])

        await harness.model.retry(summary, undoManager: nil)
        #expect(harness.launchServices.writes(to: .png) == 1)
        #expect(harness.launchServices.writes(to: .jpg) == 2)
    }

    /// macOS 27 asks before each change; the controls that apply stay disabled until it is answered.
    @Test func stillApplyingWhileMacOSAsks() async {
        let harness = await Harness(holdingWrites: true, instantWritesAreSilent: false)
        let applying = await harness.startApplying([Assignment(ext: .png, app: .preview)])
        await harness.untilAWriteIsHeld()
        #expect(harness.model.isApplying)

        harness.launchServices.releaseWrites()
        await applying.value
        #expect(!harness.model.isApplying)
    }

    /// Applying the same change twice asks macOS 27 only once, and leaves a single step to undo.
    @Test func repeatingAnApplyAsksOnceAndUndoesInOneStep() async {
        let harness = await Harness(instantWritesAreSilent: false)
        await harness.apply([Assignment(ext: .png, app: .preview)])
        await harness.apply([Assignment(ext: .png, app: .preview)])
        #expect(harness.launchServices.writes(to: .png) == 1)

        // The second change had nothing to revert, so its entry is removed and Undo reverts the first.
        await Task.yield()
        harness.undoManager.undo()
        #expect(await harness.eventually { harness.model.statuses[.png]?.current == .textEdit })
        #expect(!harness.undoManager.canUndo)
    }
}

// MARK: - Fakes

private extension FileExtension {
    static let png = FileExtension("png")!
    static let jpg = FileExtension("jpg")!
    static let txt = FileExtension("txt")!
}

private extension AppInfo {
    static let textEdit = AppInfo(bundleID: "com.apple.TextEdit", name: "TextEdit", url: URL(fileURLWithPath: "/Applications/TextEdit.app"))
    static let preview = AppInfo(bundleID: "com.apple.Preview", name: "Preview", url: URL(fileURLWithPath: "/Applications/Preview.app"))
}

@MainActor
private struct Harness {
    let launchServices: FakeLaunchServices
    let model: AppModel
    let undoManager = UndoManager()

    init(failing: Set<FileExtension> = [], holdingWrites: Bool = false, instantWritesAreSilent: Bool = true) async {
        let apps = FakeApps(apps: [.textEdit, .preview])
        launchServices = FakeLaunchServices(
            defaults: [.png: AppInfo.textEdit.url, .jpg: AppInfo.textEdit.url, .txt: AppInfo.textEdit.url],
            failing: failing,
            instantWritesAreSilent: instantWritesAreSilent
        )
        model = AppModel(
            service: AssociationService(launchServices: launchServices, apps: apps, verificationTimeout: .milliseconds(200)),
            locator: apps,
            store: CustomFormatStore(defaults: UserDefaults(suiteName: "defaultly-tests-\(UUID().uuidString)")!)
        )
        // Menu commands and buttons each get their own undo group; here the test opens and closes them.
        undoManager.groupsByEvent = false
        await model.loadIfNeeded()
        if holdingWrites { launchServices.holdWrites() }
    }

    func apply(_ assignments: [Assignment]) async {
        await startApplying(assignments).value
    }

    /// Starts an apply with Undo, as a button does: its undo group closes once Undo is registered, like the event's
    /// group, long before the apply finishes. An entry removed while its group is still open would stay.
    func startApplying(_ assignments: [Assignment]) async -> Task<Void, Never> {
        undoManager.beginUndoGrouping()
        let applying = Task { await model.apply(assignments, named: "Change", undoManager: undoManager) }
        // The apply registers Undo before its first suspension, and main-actor jobs run in order.
        await Task.yield()
        undoManager.endUndoGrouping()
        return applying
    }

    func untilAWriteIsHeld() async {
        _ = await eventually { launchServices.heldWrites > 0 }
    }

    /// Undo and Redo run on the queue a moment after they are chosen.
    func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}

private struct FakeApps: AppLocating {
    let apps: [AppInfo]

    func app(at url: URL) -> AppInfo? { apps.first { $0.url == url } }
    func app(bundleID: String) -> AppInfo? { apps.first { $0.bundleID == bundleID } }
    func installedApps() -> [AppInfo] { apps }
}

/// In-memory LaunchServices. While held, writes wait for `releaseWrites()`, like a confirmation nobody answered yet.
/// `failing`: writes throw. `instantWritesAreSilent: false` behaves like macOS 27.
private final class FakeLaunchServices: LaunchServicesClient, @unchecked Sendable {
    struct Failure: LocalizedError { var errorDescription: String? { "boom" } }

    private let lock = NSLock()
    private var defaults: [FileExtension: URL]
    private var written: [FileExtension] = []
    private var readCount = 0
    private var isHolding = false
    private var held: [CheckedContinuation<Void, Never>] = []
    private let failing: Set<FileExtension>
    let instantWritesAreSilent: Bool

    init(defaults: [FileExtension: URL], failing: Set<FileExtension>, instantWritesAreSilent: Bool) {
        self.defaults = defaults
        self.failing = failing
        self.instantWritesAreSilent = instantWritesAreSilent
    }

    var heldWrites: Int { lock.withLock { held.count } }
    var reads: Int { lock.withLock { readCount } }

    func writes(to ext: FileExtension) -> Int {
        lock.withLock { written.filter { $0 == ext }.count }
    }

    func holdWrites() {
        lock.withLock { isHolding = true }
    }

    func releaseWrites() {
        let waiting = lock.withLock {
            isHolding = false
            defer { held = [] }
            return held
        }
        waiting.forEach { $0.resume() }
    }

    func defaultApplication(for ext: FileExtension) -> URL? {
        lock.withLock {
            readCount += 1
            return defaults[ext]
        }
    }

    func applications(for ext: FileExtension) -> [URL] { [] }

    func setDefaultApplication(_ app: AppInfo, for ext: FileExtension, using method: AssignmentMethod) async throws {
        await withCheckedContinuation { continuation in
            let passes = lock.withLock {
                if isHolding { held.append(continuation) }
                return !isHolding
            }
            if passes { continuation.resume() }
        }
        lock.withLock { written.append(ext) }
        if failing.contains(ext) { throw Failure() }
        lock.withLock { defaults[ext] = app.url }
    }
}
