import DefaultlyCore
import SwiftUI

/// The inspector column for format lists.
struct FormatInspector: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    let scope: FormatScope

    var body: some View {
        let selected = model.formats(in: scope).filter { navigation.formatSelection.contains($0.ext) }
        switch selected.count {
        case 0:
            if let category = groupForEmptySelection {
                AssignmentPanel(
                    title: category.displayName,
                    subtitle: String(localized: "Change the app for every format in this category, or select formats in the list."),
                    formats: category.formats
                )
            } else {
                ContentUnavailableView(
                    "No Format Selected",
                    systemImage: "cursorarrow.click.2",
                    description: Text("Select a format to see which app opens it. Select several to change them together.")
                )
            }
        case 1:
            FormatDetailView(format: selected[0])
                .id(selected[0].ext)
        default:
            AssignmentPanel(
                title: String(localized: "\(selected.count) Formats Selected"),
                subtitle: String(localized: "Pick one app to open all of them."),
                formats: selected
            )
        }
    }

    /// With nothing selected, a category offers its own quick setup.
    private var groupForEmptySelection: FileCategory? {
        switch scope {
        case .category(let id): model.library.category(id: id)
        case .custom: model.library.customCategory.formats.isEmpty ? nil : model.library.customCategory
        case .all, .search: nil
        }
    }
}
