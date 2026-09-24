import Foundation

/// One block of release notes. The text keeps its inline Markdown (bold, code, links) for the app to render.
public enum ReleaseNoteBlock: Equatable, Sendable {
    case heading(String)
    case bullet(String)
    case paragraph(String)
}

public enum ReleaseNotes {
    /// Splits Markdown into headings, bullets and paragraphs. Wrapped lines join the block above them,
    /// nested bullets are flattened, and horizontal rules are dropped.
    public static func blocks(from markdown: String) -> [ReleaseNoteBlock] {
        var blocks: [ReleaseNoteBlock] = []
        var continues = false
        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isRule(line) {
                continues = false
            } else if let heading = heading(in: line) {
                blocks.append(.heading(heading))
                continues = false
            } else if let bullet = bullet(in: line) {
                blocks.append(.bullet(bullet))
                continues = true
            } else if continues, let last = blocks.popLast() {
                blocks.append(last.appending(line))
            } else {
                blocks.append(.paragraph(line))
                continues = true
            }
        }
        return blocks
    }

    /// What changed in a GitHub release body: its "What's changed" section when it has one, otherwise the text
    /// before its first section. Sections such as "Install" and "**Full Changelog**" links aren't changes.
    public static func changes(inReleaseBody body: String) -> String {
        var preamble: [String] = []
        var sections: [(title: String, lines: [String])] = []
        for line in body.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                sections.append((String(trimmed.dropFirst(3)), []))
            } else if trimmed.hasPrefix("**Full Changelog**") {
                continue
            } else if sections.isEmpty {
                preamble.append(line)
            } else {
                sections[sections.count - 1].lines.append(line)
            }
        }
        let changes = sections.first { isChangesTitle($0.title) }?.lines ?? preamble
        return changes.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func heading(in line: String) -> String? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
    }

    private static func bullet(in line: String) -> String? {
        guard let marker = line.first, "-*+".contains(marker), line.dropFirst().first == " " else { return nil }
        return line.dropFirst(2).trimmingCharacters(in: .whitespaces)
    }

    private static func isRule(_ line: String) -> Bool {
        guard let first = line.first, line.count >= 3, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }

    private static func isChangesTitle(_ title: String) -> Bool {
        let normalized = title.lowercased().replacingOccurrences(of: "’", with: "'")
        return ["what's changed", "what's new", "changes"].contains(normalized)
    }
}

private extension ReleaseNoteBlock {
    func appending(_ line: String) -> ReleaseNoteBlock {
        switch self {
        case .heading(let text): .heading(text + " " + line)
        case .bullet(let text): .bullet(text + " " + line)
        case .paragraph(let text): .paragraph(text + " " + line)
        }
    }
}
