import Foundation
import Testing
@testable import DefaultlyCore

struct AssociationServiceTests {
    let docx = FileExtension.ext("docx")
    let apps = FakeAppLocator(apps: [.word, .libre, .code])

    @Test func readsCurrentAppAndCandidatesDedupedByBundleID() {
        let wordCopy = URL(fileURLWithPath: "/Users/me/Applications/Microsoft Word.app")
        let locator = FakeAppLocator(apps: [.word, .libre, AppInfo(bundleID: AppInfo.word.bundleID, name: "Word copy", url: wordCopy)])
        let launchServices = FakeLaunchServices(
            defaults: [docx: AppInfo.word.url],
            candidates: [docx: [AppInfo.word.url, wordCopy, AppInfo.libre.url, URL(fileURLWithPath: "/tmp/NotAnApp.app")]]
        )
        let status = AssociationService(launchServices: launchServices, apps: locator).statuses(for: [docx])[docx]
        #expect(status?.current == .word)
        #expect(status?.candidates == [.word, .libre])
    }

    func service(_ launchServices: FakeLaunchServices) -> AssociationService {
        AssociationService(launchServices: launchServices, apps: apps, verificationTimeout: .milliseconds(50))
    }

    @Test func appliesInstantlyAndRemembersThePreviousApp() async {
        let launchServices = FakeLaunchServices(defaults: [docx: AppInfo.word.url])
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.applied])
        #expect(report.outcomes.first?.previous == .word)
        #expect(launchServices.defaultApplication(for: docx) == AppInfo.libre.url)
        #expect(launchServices.methods(for: docx) == [.instant])
    }

    @Test func fallsBackToTheInteractiveAPIWhenMacOSIgnoresTheInstantWrite() async {
        let launchServices = FakeLaunchServices(defaults: [docx: AppInfo.word.url], ownedByOthers: [docx])
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.applied])
        #expect(launchServices.methods(for: docx) == [.instant, .interactive])
    }

    @Test func reportsWhenMacOSKeepsAnotherApp() async {
        let launchServices = FakeLaunchServices(defaults: [docx: AppInfo.word.url], rejected: [docx])
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.notAccepted(actual: .word)])
    }

    @Test func stopsAskingOnceTheUserDeclines() async {
        let doc = FileExtension.ext("doc")
        let launchServices = FakeLaunchServices(
            defaults: [docx: AppInfo.word.url, doc: AppInfo.word.url],
            ownedByOthers: [docx, doc],
            declining: [docx]
        )
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre), Assignment(ext: doc, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.notAccepted(actual: .word), .notAccepted(actual: .word)])
        #expect(launchServices.methods(for: doc) == [.instant])
    }

    @Test func asksOncePerFormatWhenInstantWritesArentSilent() async {
        let doc = FileExtension.ext("doc")
        let launchServices = FakeLaunchServices(
            defaults: [docx: AppInfo.word.url, doc: AppInfo.libre.url],
            instantWritesAreSilent: false
        )
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre), Assignment(ext: doc, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.applied, .applied])
        #expect(launchServices.methods(for: docx) == [.interactive])
        // Already opens with it: nothing to ask about.
        #expect(launchServices.methods(for: doc) == [])
    }

    @Test func stopsAtTheFirstDeclineWhenInstantWritesArentSilent() async {
        let doc = FileExtension.ext("doc")
        let launchServices = FakeLaunchServices(
            defaults: [docx: AppInfo.word.url, doc: AppInfo.word.url],
            declining: [docx],
            instantWritesAreSilent: false
        )
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre), Assignment(ext: doc, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.notAccepted(actual: .word), .notAccepted(actual: .word)])
        #expect(launchServices.methods(for: docx) == [.interactive])
        #expect(launchServices.methods(for: doc) == [])
    }

    @Test func reportsFailuresWithoutRetryingThem() async {
        let odt = FileExtension.ext("odt")
        let launchServices = FakeLaunchServices(failing: [docx])
        let report = await service(launchServices).apply([Assignment(ext: docx, app: .libre), Assignment(ext: odt, app: .libre)])
        #expect(report.outcomes.map(\.result) == [.failed(message: "boom"), .applied])
        #expect(launchServices.methods(for: docx) == [.instant])
    }
}

struct ApplyReportTests {
    func outcome(_ ext: String, to app: AppInfo, previous: AppInfo?, _ result: AssignmentOutcome.Result = .applied) -> AssignmentOutcome {
        AssignmentOutcome(assignment: Assignment(ext: .ext(ext), app: app), previous: previous, result: result)
    }

    @Test func undoRevertsOnlyRealChanges() {
        let report = ApplyReport(outcomes: [
            outcome("docx", to: .libre, previous: .word),
            outcome("odt", to: .libre, previous: nil),
            outcome("rtf", to: .libre, previous: .libre),
            outcome("doc", to: .libre, previous: .word, .notAccepted(actual: .word)),
            outcome("dot", to: .libre, previous: .word, .failed(message: "x")),
        ])
        #expect(report.undoAssignments == [Assignment(ext: .ext("docx"), app: .word)])
        #expect(report.redoAssignments == [Assignment(ext: .ext("docx"), app: .libre)])
        #expect(report.issues.map(\.id) == [.ext("doc"), .ext("dot")])
    }
}
