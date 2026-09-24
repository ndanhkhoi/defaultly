import SwiftUI

struct DefaultlyCommands: Commands {
    let model: AppModel
    let navigation: Navigation

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Custom Format…") { navigation.sheet = .newCustomFormats(prefill: "") }
                .keyboardShortcut("n")
        }
        CommandGroup(replacing: .importExport) {
            Button("Export Backup…") { BackupFlow(model: model, navigation: navigation).export() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!model.hasLoaded)
            Button("Restore from Backup…") { Task { await BackupFlow(model: model, navigation: navigation).restore() } }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(!model.hasLoaded || model.isApplying)
        }
        CommandGroup(after: .sidebar) {
            Button("Refresh") { Task { await model.reload() } }
                .keyboardShortcut("r")
                .disabled(model.isLoading || model.isApplying)
            Divider()
        }
        CommandGroup(replacing: .help) {
            Link("Defaultly on GitHub", destination: URL(string: "https://github.com/ndanhkhoi/defaultly")!)
        }
    }
}
