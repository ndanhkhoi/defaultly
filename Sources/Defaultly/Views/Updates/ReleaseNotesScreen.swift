import DefaultlyCore
import SwiftUI

/// Help → Release Notes: the changelog bundled with this version, so it works offline and matches what is installed.
/// Also opens by itself on the first launch after an update.
struct ReleaseNotesScreen: View {
    static let windowID = "release-notes"

    @Environment(UpdateController.self) private var updates
    private let sections = Self.bundledChangelog().map(ReleaseNotesList.Section.init)

    var body: some View {
        Group {
            if sections.isEmpty {
                ContentUnavailableView {
                    Label("No Release Notes", systemImage: "doc.text")
                } description: {
                    Text("This build doesn't include release notes.")
                } actions: {
                    Link("All Releases on GitHub", destination: ProjectLinks.releases)
                }
            } else {
                ScrollView {
                    ReleaseNotesList(sections: sections, installed: updates.currentVersion)
                        .padding(24)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if updates.currentVersion != nil {
                    Button("Check for Updates…") { updates.checkNow() }
                        .help("Check whether a newer version of Defaultly is available.")
                }
                Link(destination: ProjectLinks.releases) {
                    Label("All Releases on GitHub", systemImage: "arrow.up.forward.square")
                }
                .help("Open Defaultly's releases on GitHub")
            }
        }
    }

    private static func bundledChangelog() -> [ChangelogEntry] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return [] }
        return Changelog.parse(text)
    }
}
