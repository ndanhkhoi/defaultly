import DefaultlyCore
import SwiftUI

/// Release notes, one section per version, rendered natively from their Markdown.
/// Takes plain values only, like every row-like view (see `FormatRow`).
struct ReleaseNotesList: View {
    struct Section: Identifiable {
        let version: AppVersion
        let date: Date?
        let blocks: [ReleaseNoteBlock]

        var id: AppVersion { version }
    }

    let sections: [Section]
    var installed: AppVersion?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    header(section)
                    if section.blocks.isEmpty {
                        Text("No notes for this version.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                        BlockView(block: block)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func header(_ section: Section) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Version \(section.version.description)").font(.headline)
            if section.version == installed {
                Text("Installed")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(.tint)
            }
            Spacer()
            if let date = section.date {
                Text(date, format: .dateTime.day().month().year()).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BlockView: View {
    let block: ReleaseNoteBlock

    var body: some View {
        switch block {
        case .heading(let text):
            Text(Self.inline(text)).font(.subheadline.weight(.semibold)).padding(.top, 4)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "•").foregroundStyle(.secondary).accessibilityHidden(true)
                Text(Self.inline(text)).fixedSize(horizontal: false, vertical: true)
            }
        case .paragraph(let text):
            Text(Self.inline(text)).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Bold, italics, code and links stay formatted; anything else shows as written.
    private static func inline(_ markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

extension ReleaseNotesList.Section {
    init(_ entry: ChangelogEntry) {
        self.init(version: entry.version, date: entry.date, blocks: ReleaseNotes.blocks(from: entry.notes))
    }

    init(_ release: Release) {
        let changes = ReleaseNotes.changes(inReleaseBody: release.notes)
        self.init(version: release.version, date: release.publishedAt, blocks: ReleaseNotes.blocks(from: changes))
    }
}
