import DefaultlyCore
import Foundation
import Observation

enum SidebarItem: Hashable {
    case quickSetup
    case allFormats
    case apps
    case category(String)
    case custom
}

/// What the format table shows.
enum FormatScope: Hashable {
    case all
    case category(String)
    case custom
    case search(String)
}

enum SetupTarget: Hashable {
    case suite(String)
    case category(String)
}

enum SheetRoute: Identifiable {
    case newCustomFormats(prefill: String)
    case editCustomFormat(CustomFormat)
    case restore(RestorePreview)
    case issues(ApplySummary)

    var id: String {
        switch self {
        case .newCustomFormats: "new-custom"
        case .editCustomFormat(let format): "edit-\(format.ext.rawValue)"
        case .restore(let preview): "restore-\(preview.backup.createdAt.timeIntervalSince1970)"
        case .issues(let summary): "issues-\(summary.id)"
        }
    }
}

/// An error the user can act on.
struct AlertRoute {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?
}

/// Where the user is in the UI. Domain state lives in `AppModel`.
@Observable
@MainActor
final class Navigation {
    var sidebar: SidebarItem? = .quickSetup
    var formatSelection: Set<FileExtension> = []
    var setupSelection: SetupTarget?
    var appSelection: String?
    var searchText = ""
    var sheet: SheetRoute?
    var alert: AlertRoute?

    var isSearchingFormats: Bool {
        sidebar != .apps && !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var formatScope: FormatScope? {
        if isSearchingFormats { return .search(searchText) }
        switch sidebar {
        case .allFormats: return .all
        case .category(let id): return .category(id)
        case .custom: return .custom
        case .quickSetup, .apps, nil: return nil
        }
    }

    /// Shows a format in its category with it selected.
    func reveal(_ format: FileFormat) {
        searchText = ""
        sidebar = format.isCustom ? .custom : .category(format.categoryID)
        formatSelection = [format.ext]
    }
}
