import DefaultlyCore
import SwiftUI

/// Adds one or many custom formats, or edits one.
struct CustomFormatSheet: View {
    enum Mode {
        case add(prefill: String)
        case edit(CustomFormat)
    }

    @Environment(AppModel.self) private var model
    @Environment(Navigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var extensionsText = ""
    @State private var name = ""
    @State private var categoryID = FormatLibrary.customCategoryID

    var body: some View {
        let parsed = FileExtension.parseList(extensionsText)
        let existing = parsed.valid.compactMap { model.library.format(for: $0) }
        let new = parsed.valid.filter { model.library.format(for: $0) == nil }

        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    if case .edit(let format) = mode {
                        LabeledContent("Extension") {
                            ExtensionBadge(ext: format.ext, tint: .gray)
                        }
                    } else {
                        TextField("Extensions", text: $extensionsText, prompt: Text(verbatim: "kt, kts, gradle"))
                        feedback(parsed: parsed, existing: existing, new: new)
                    }
                    TextField("Name", text: $name, prompt: Text("Optional. Leave empty to use the system description."))
                    Picker("Category", selection: $categoryID) {
                        Text("Custom Formats").tag(FormatLibrary.customCategoryID)
                        Divider()
                        ForEach(model.library.categories) { category in
                            Text(verbatim: category.displayName).tag(category.id)
                        }
                    }
                } header: {
                    if isEditing { Text("Edit Custom Format") } else { Text("Add Custom Formats") }
                } footer: {
                    if !isEditing {
                        Text("Separate several extensions with commas or spaces. Next, choose which app opens them.")
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button { save(new: new) } label: {
                    if isEditing { Text("Save") } else { Text("Add \(new.count) Formats") }
                }
                    .glassButton(prominent: true)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isEditing && new.isEmpty)
            }
            .controlSize(.large)
            .padding(16)
        }
        .frame(width: 480)
        .onAppear(perform: prefill)
    }

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    @ViewBuilder
    private func feedback(parsed: FileExtension.ParsedList, existing: [FileFormat], new: [FileExtension]) -> some View {
        if !new.isEmpty {
            FlowLayout {
                ForEach(new, id: \.self) { ExtensionBadge(ext: $0, tint: .accentColor) }
            }
            .accessibilityLabel(Text("New: \(new.map(\.description).joined(separator: ", "))"))
        }
        ForEach(existing) { format in
            HStack {
                Label(
                    "\(format.ext.description) is already available in \(model.category(of: format)?.displayName ?? "")",
                    systemImage: "info.circle"
                )
                .foregroundStyle(.secondary)
                Spacer()
                Button("Show") {
                    navigation.reveal(format)
                    dismiss()
                }
                .buttonStyle(.link)
            }
        }
        if !parsed.invalid.isEmpty {
            Label("Not valid: \(parsed.invalid.joined(separator: ", "))", systemImage: "xmark.octagon")
                .foregroundStyle(.red)
                .help("Use letters, digits, “-”, “_” or “+”, without dots or spaces.")
        }
    }

    private func prefill() {
        switch mode {
        case .add(let text):
            extensionsText = text
        case .edit(let format):
            name = format.name ?? ""
            categoryID = format.categoryID
        }
    }

    private func save(new: [FileExtension]) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let customName = trimmedName.isEmpty ? nil : trimmedName
        switch mode {
        case .edit(let format):
            model.updateCustomFormat(CustomFormat(ext: format.ext, name: customName, categoryID: categoryID))
            dismiss()
        case .add:
            let formats = new.map { CustomFormat(ext: $0, name: customName, categoryID: categoryID) }
            Task {
                await model.addCustomFormats(formats)
                navigation.searchText = ""
                navigation.sidebar = .custom
                navigation.formatSelection = Set(new)
                dismiss()
            }
        }
    }
}
