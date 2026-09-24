import DefaultlyCore
import SwiftUI

/// Quick Setup content column: app suites, then one setup per category.
struct SetupListView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        List(selection: $navigation.setupSelection) {
            if !model.suites.isEmpty {
                Section("App Suites") {
                    ForEach(model.suites) { suite in
                        SuiteRow(suite: suite).tag(SetupTarget.suite(suite.id))
                    }
                }
            }
            Section("Categories") {
                ForEach(setupCategories) { category in
                    CategorySetupRow(category: category, mostlyOpenedWith: model.currentDefaults(for: category.formats).first?.app)
                        .tag(SetupTarget.category(category.id))
                }
            }
        }
        .navigationTitle(Text("Quick Setup"))
        .navigationSubtitle(Text("Switch many formats in one step"))
    }

    private var setupCategories: [FileCategory] {
        let custom = model.library.customCategory
        return model.library.categories + (custom.formats.isEmpty ? [] : [custom])
    }
}

private struct SuiteRow: View {
    let suite: ResolvedSuite

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -8) {
                ForEach(suite.apps) { AppIconView(app: $0, size: 28) }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: suite.suite.name)
                Text("Documents, spreadsheets and presentations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A list row: takes plain values and never reads the environment (see `FormatRow`).
private struct CategorySetupRow: View {
    let category: FileCategory
    let mostlyOpenedWith: AppInfo?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.symbol)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(category.tint.color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: category.displayName)
                Group {
                    if let mostly = mostlyOpenedWith {
                        Text("Mostly \(mostly.name) · \(category.formats.count) formats")
                    } else {
                        Text("\(category.formats.count) formats")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
