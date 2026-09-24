#if DEBUG
import AppKit
import DefaultlyCore
import SwiftUI

/// Debug-only UI smoke test (`scripts/smoke-test.sh`): drives every screen, selection, sheet and
/// toast, then exits 0. SwiftUI crashes such as a row reading a missing environment object only
/// show up in a running app, so unit tests can't catch them. It never changes file associations;
/// it adds and removes two made-up custom formats in the debug build's own defaults.
@MainActor
enum SmokeTest {
    static let isRequested = ProcessInfo.processInfo.environment["DEFAULTLY_SMOKE_TEST"] != nil

    static func run(model: AppModel, navigation: Navigation) async {
        guard isRequested else { return }
        await model.loadIfNeeded()
        for round in 1...2 {
            log("round \(round)")
            await visitScreens(model: model, navigation: navigation)
        }
        await exerciseCustomFormats(model: model, navigation: navigation)
        await presentSheetsAndToasts(model: model, navigation: navigation)
        log("smoke test passed")
        exit(0)
    }

    private static func visitScreens(model: AppModel, navigation: Navigation) async {
        await step { navigation.sidebar = .quickSetup }
        for category in model.library.categories {
            await step { navigation.setupSelection = .category(category.id) }
        }
        for suite in model.suites {
            await step { navigation.setupSelection = .suite(suite.id) }
        }
        await step { navigation.sidebar = .allFormats }
        for (index, category) in model.library.categories.enumerated() {
            // Switch while rows are still selected: removed rows keep being updated (the v1.0.0 crash).
            await step { navigation.sidebar = .category(category.id) }
            await step { navigation.formatSelection = [category.formats[0].ext] }
            await step { navigation.formatSelection = Set(category.formats.prefix(5).map(\.ext)) }
            if index.isMultiple(of: 3) { await step { navigation.formatSelection = [] } }
        }
        if let format = model.library.format(for: FileExtension("png")!) {
            await step { navigation.reveal(format) }
        }
        await step { navigation.sidebar = .custom }
        await step { navigation.searchText = "doc" }
        await step { navigation.searchText = "zzqq" }
        await step { navigation.searchText = "" }
        await step { navigation.sidebar = .apps }
        for app in model.installedApps.prefix(20) {
            await step { navigation.appSelection = app.bundleID }
        }
    }

    private static func exerciseCustomFormats(model: AppModel, navigation: Navigation) async {
        let made = ["zzsmokea", "zzsmokeb"].compactMap(FileExtension.init)
        await model.addCustomFormats(made.map { CustomFormat(ext: $0, categoryID: "code") })
        await step { navigation.sidebar = .custom }
        await step { navigation.formatSelection = Set(made) }
        await step { navigation.formatSelection = [made[0]] }
        await step { navigation.sidebar = .quickSetup }
        await step { navigation.setupSelection = .category(FormatLibrary.customCategoryID) }
        await step { navigation.sidebar = .custom }
        await step { navigation.formatSelection = [made[0]] }
        // Remove while selected and while its setup is the last one picked.
        await step { model.removeCustomFormats(Set(made), undoManager: nil) }
        await step { navigation.sidebar = .quickSetup }
    }

    private static func presentSheetsAndToasts(model: AppModel, navigation: Navigation) async {
        let pdf = FileExtension("pdf")!
        let app = model.statuses[pdf]?.current ?? model.installedApps.first
        let sheets: [SheetRoute] = [
            .newCustomFormats(prefill: "kt, bad/one, png"),
            .editCustomFormat(CustomFormat(ext: FileExtension("zzsmoke")!, name: "Smoke", categoryID: "code")),
        ]
        for sheet in sheets {
            await step(.milliseconds(500)) { navigation.sheet = sheet }
            await step(.milliseconds(300)) { navigation.sheet = nil }
        }
        if let app {
            let issue = AssignmentOutcome(assignment: Assignment(ext: pdf, app: app), previous: nil, result: .notAccepted(actual: nil))
            let summary = ApplySummary(title: "Smoke", total: 1, issues: [issue], offersUndo: false)
            await step(.milliseconds(500)) { navigation.sheet = .issues(summary) }
            await step(.milliseconds(300)) { navigation.sheet = nil }
            await step(.milliseconds(300)) { model.activity = .applying(title: "Smoke", count: 3) }
            await step(.milliseconds(300)) { model.activity = .finished(summary) }
            await step(.milliseconds(300)) { model.activity = .idle }
        }
        if let data = try? model.backupData(), let preview = try? await model.restorePreview(from: data) {
            await step(.milliseconds(500)) { navigation.sheet = .restore(preview) }
            await step(.milliseconds(300)) { navigation.sheet = nil }
        }
    }

    private static func step(_ pause: Duration = .milliseconds(80), _ change: () -> Void) async {
        change()
        try? await Task.sleep(for: pause)
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("smoke: \(message)\n".utf8))
    }
}
#endif
