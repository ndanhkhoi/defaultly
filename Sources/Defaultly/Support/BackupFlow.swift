import AppKit
import UniformTypeIdentifiers

/// Save/open panels around backups, shared by the toolbar and the File menu.
@MainActor
struct BackupFlow {
    let model: AppModel
    let navigation: Navigation

    func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = String(localized: "Defaultly Backup \(Date().formatted(.iso8601.year().month().day())).json")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.backupData().write(to: url, options: .atomic)
        } catch {
            navigation.alert = AlertRoute(
                title: String(localized: "Couldn't Export Backup"),
                message: error.localizedDescription,
                actionTitle: String(localized: "Try Again"),
                action: { export() }
            )
        }
    }

    func restore() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            navigation.sheet = .restore(try await model.restorePreview(from: data))
        } catch {
            navigation.alert = AlertRoute(
                title: String(localized: "Couldn't Read Backup"),
                message: String(localized: "“\(url.lastPathComponent)” isn't a Defaultly backup, or it is damaged. \(error.localizedDescription)"),
                actionTitle: String(localized: "Choose Another File"),
                action: { Task { await restore() } }
            )
        }
    }
}
