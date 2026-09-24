import DefaultlyCore
import Foundation
import Observation
import SwiftUI

/// The result of one apply, shown in the activity overlay.
struct ApplySummary: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let total: Int
    let issues: [AssignmentOutcome]
    let offersUndo: Bool

    var hasIssues: Bool { !issues.isEmpty }
    var retryable: [Assignment] { issues.map(\.assignment) }

    var message: String {
        hasIssues ? String(localized: "Couldn't change \(issues.count) of \(total) formats") : title
    }
}

/// App-wide state: formats, their associations, installed apps, and the changes the user makes.
@Observable
@MainActor
final class AppModel {
    enum Activity: Equatable {
        case idle
        case applying(title: String, count: Int)
        case finished(ApplySummary)
    }

    private let service: AssociationService
    private let locator: any AppLocating
    private let store: CustomFormatStore

    private(set) var library: FormatLibrary
    private(set) var customFormats: [CustomFormat]
    private(set) var statuses: [FileExtension: FormatStatus] = [:]
    private(set) var installedApps: [AppInfo] = []
    private(set) var suites: [ResolvedSuite] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// Extensions being changed right now.
    private(set) var inFlight: Set<FileExtension> = []
    /// Bumped whenever associations change, so dependent views can recompute.
    private(set) var revision = 0
    var activity: Activity = .idle
    /// The latest apply; each new one waits for it, so Undo pressed mid-apply is queued, not lost.
    private var lastApply: Task<ApplyReport, Never>?

    init(service: AssociationService, locator: any AppLocating, store: CustomFormatStore) {
        self.service = service
        self.locator = locator
        self.store = store
        let saved = store.load()
        customFormats = saved
        library = FormatLibrary(custom: saved)
    }

    var isApplying: Bool {
        if case .applying = activity { true } else { false }
    }

    // MARK: - Loading

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        guard !isLoading, !isApplying else { return }
        isLoading = true
        let extensions = library.allExtensions
        let service = service
        let locator = locator
        let snapshot = await Task.detached(priority: .userInitiated) {
            (
                statuses: service.statuses(for: extensions),
                apps: locator.installedApps(),
                suites: AppSuite.all.compactMap { $0.resolve(using: locator) }
            )
        }.value
        statuses = snapshot.statuses
        installedApps = snapshot.apps
        suites = snapshot.suites
        isLoading = false
        hasLoaded = true
        revision += 1
    }

    private func refresh(_ extensions: [FileExtension]) async {
        guard !extensions.isEmpty else { return }
        let service = service
        let fresh = await Task.detached { service.statuses(for: extensions) }.value
        statuses.merge(fresh) { _, new in new }
        revision += 1
    }

    // MARK: - Queries

    func formats(in scope: FormatScope) -> [FileFormat] {
        switch scope {
        case .all: library.allFormats
        case .category(let id): library.category(id: id)?.formats ?? []
        case .custom: library.customCategory.formats
        case .search(let query): library.search(query) { $0.displayName }
        }
    }

    func category(of format: FileFormat) -> FileCategory? {
        library.category(id: format.categoryID)
    }

    func tint(for format: FileFormat) -> Color {
        category(of: format)?.tint.color ?? .gray
    }

    func supportingApps(for formats: [FileFormat]) -> [AppCount] {
        AppRanking.supporting(formats, statuses: statuses)
    }

    func currentDefaults(for formats: [FileFormat]) -> [AppCount] {
        AppRanking.defaults(for: formats, statuses: statuses)
    }

    func formats(openedBy app: AppInfo) -> [FileFormat] {
        library.allFormats.filter { app.isSameApp(as: statuses[$0.ext]?.current) }
    }

    /// How many of the library's formats each app opens, keyed by bundle ID.
    var defaultCounts: [String: Int] {
        library.allExtensions.reduce(into: [:]) { counts, ext in
            if let app = statuses[ext]?.current { counts[app.bundleID, default: 0] += 1 }
        }
    }

    /// Formats in the same category that the format's current app supports but does not open yet.
    func relatedFormats(to format: FileFormat) -> (app: AppInfo, formats: [FileFormat])? {
        guard let app = statuses[format.ext]?.current, let category = category(of: format) else { return nil }
        let related = category.formats.filter { other in
            other.ext != format.ext
                && statuses[other.ext]?.supports(app) == true
                && !app.isSameApp(as: statuses[other.ext]?.current)
        }
        return related.isEmpty ? nil : (app, related)
    }

    func app(at url: URL) -> AppInfo? {
        locator.app(at: url)
    }

    /// Formats `app` can open but does not open yet, including extensions it declares that
    /// are not in the library (offered as new custom formats). All start unchecked.
    func suggestions(for app: AppInfo) async -> [PlanItem] {
        let service = service
        let declared = await Task.detached { DeclaredFormats.extensions(ofAppAt: app.url) }.value
        let unknown = declared.filter { library.format(for: $0) == nil }.sorted()
        let unknownStatuses = await Task.detached { service.statuses(for: unknown) }.value
        let unknownFormats = unknown.map {
            FileFormat(ext: $0, name: $0.fallbackName, categoryID: FormatLibrary.customCategoryID, isCustom: true)
        }
        let known = library.allFormats.filter { statuses[$0.ext]?.supports(app) == true }
        return PlanBuilder.items(
            for: known + unknownFormats,
            assigning: app,
            statuses: statuses.merging(unknownStatuses) { current, _ in current },
            including: .none
        )
    }

    // MARK: - Changing associations

    static func title(setting app: AppInfo, count: Int) -> String {
        String(localized: "Set \(app.name) for \(count) formats")
    }

    /// Applies assignments with verification and registers them for Undo/Redo.
    func apply(_ assignments: [Assignment], named title: String, undoManager: UndoManager?) async {
        guard let report = await execute(assignments, title: title, offersUndo: undoManager != nil),
              let undoManager
        else { return }
        ReversibleChange(title: title, report: report).register(on: undoManager, target: self) { [weak self] assignments, isUndo in
            let actionTitle = isUndo ? String(localized: "Undo \(title)") : String(localized: "Redo \(title)")
            Task { await self?.execute(assignments, title: actionTitle, offersUndo: false) }
        }
    }

    /// Applies the included items of a reviewed plan, adding any new custom formats first.
    func apply(_ items: [PlanItem], named title: String, undoManager: UndoManager?) async {
        let included = items.filter(\.isIncluded)
        let newFormats = included
            .filter { $0.format.isCustom && library.format(for: $0.format.ext) == nil }
            .map { CustomFormat(ext: $0.format.ext) }
        await addCustomFormats(newFormats)
        await apply(included.map(\.assignment), named: title, undoManager: undoManager)
    }

    func retry(_ summary: ApplySummary, undoManager: UndoManager?) async {
        await apply(summary.retryable, named: summary.title, undoManager: undoManager)
    }

    /// Runs after any apply already in progress.
    @discardableResult
    private func execute(_ assignments: [Assignment], title: String, offersUndo: Bool) async -> ApplyReport? {
        guard !assignments.isEmpty else { return nil }
        let previous = lastApply
        let current = Task {
            _ = await previous?.value
            return await run(assignments, title: title, offersUndo: offersUndo)
        }
        lastApply = current
        return await current.value
    }

    private func run(_ assignments: [Assignment], title: String, offersUndo: Bool) async -> ApplyReport {
        inFlight = Set(assignments.map(\.ext))
        activity = .applying(title: title, count: assignments.count)
        let report = await service.apply(assignments)
        inFlight = []
        await refresh(assignments.map(\.ext))

        let summary = ApplySummary(
            title: title,
            total: report.outcomes.count,
            issues: report.issues,
            offersUndo: offersUndo && !report.undoAssignments.isEmpty
        )
        activity = .finished(summary)
        AccessibilityNotification.Announcement(summary.message).post()
        return report
    }

    // MARK: - Custom formats

    func customFormat(for ext: FileExtension) -> CustomFormat? {
        customFormats.first { $0.ext == ext }
    }

    func addCustomFormats(_ formats: [CustomFormat]) async {
        let new = formats.filter { library.format(for: $0.ext) == nil }
        guard !new.isEmpty else { return }
        customFormats += new
        saveCustomFormats()
        await refresh(new.map(\.ext))
    }

    func updateCustomFormat(_ format: CustomFormat) {
        guard let index = customFormats.firstIndex(where: { $0.ext == format.ext }) else { return }
        customFormats[index] = format
        saveCustomFormats()
    }

    /// Removal is instant and undoable, like deleting in Finder.
    func removeCustomFormats(_ extensions: Set<FileExtension>, undoManager: UndoManager?) {
        let removed = customFormats.filter { extensions.contains($0.ext) }
        guard !removed.isEmpty else { return }
        customFormats.removeAll { extensions.contains($0.ext) }
        saveCustomFormats()
        undoManager?.registerUndo(withTarget: self) { model in
            model.restoreCustomFormats(removed, undoManager: undoManager)
        }
        undoManager?.setActionName(String(localized: "Remove Custom Formats"))
    }

    private func restoreCustomFormats(_ formats: [CustomFormat], undoManager: UndoManager?) {
        customFormats += formats.filter { customFormat(for: $0.ext) == nil }
        saveCustomFormats()
        undoManager?.registerUndo(withTarget: self) { model in
            model.removeCustomFormats(Set(formats.map(\.ext)), undoManager: undoManager)
        }
        undoManager?.setActionName(String(localized: "Remove Custom Formats"))
    }

    private func saveCustomFormats() {
        store.save(customFormats)
        library = FormatLibrary(custom: customFormats)
        revision += 1
    }

    // MARK: - Backup

    func backupData() throws -> Data {
        let known = statuses.filter { library.format(for: $0.key) != nil }
        return try AssociationBackup(statuses: known, customFormats: customFormats).encoded()
    }

    func restorePreview(from data: Data) async throws -> RestorePreview {
        let backup = try AssociationBackup.decode(data)
        await refresh(backup.associations.map(\.ext).filter { statuses[$0] == nil })
        return RestorePreview(
            backup: backup,
            library: FormatLibrary(custom: customFormats + backup.customFormats),
            existingCustomFormats: customFormats,
            statuses: statuses,
            apps: locator
        )
    }

    func restore(_ preview: RestorePreview, items: [PlanItem], undoManager: UndoManager?) async {
        await addCustomFormats(preview.newCustomFormats)
        await apply(items, named: String(localized: "Restore Backup"), undoManager: undoManager)
    }
}
