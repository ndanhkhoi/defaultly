import Foundation

/// The notes of one released version in `CHANGELOG.md`.
public struct ChangelogEntry: Identifiable, Equatable, Sendable {
    public let version: AppVersion
    /// The release day, at midnight in the current time zone, so it displays as the day written.
    public let date: Date?
    /// Markdown.
    public let notes: String

    public init(version: AppVersion, date: Date?, notes: String) {
        self.version = version
        self.date = date
        self.notes = notes
    }

    public var id: AppVersion { version }
}

public enum Changelog {
    /// Entries in file order. A version starts at a `## 1.2.3 - 2026-09-24` heading (`[1.2.3]` and a missing date
    /// are fine too); other `##` headings such as `## Unreleased` are skipped with their content.
    public static func parse(_ markdown: String) -> [ChangelogEntry] {
        var entries: [ChangelogEntry] = []
        var current: (version: AppVersion, date: Date?, lines: [String])?

        func finish() {
            guard let entry = current else { return }
            let notes = entry.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(ChangelogEntry(version: entry.version, date: entry.date, notes: notes))
            current = nil
        }

        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                finish()
                if let heading = versionHeading(String(line.dropFirst(3))) {
                    current = (heading.version, heading.date, [])
                }
            } else if line.hasPrefix("# ") {
                finish()
            } else {
                current?.lines.append(line)
            }
        }
        finish()
        return entries
    }

    /// `1.2.3 - 2026-09-24`, `[1.2.3] – 2026-09-24` or `1.2.3`.
    private static func versionHeading(_ text: String) -> (version: AppVersion, date: Date?)? {
        let parts = text.split(separator: " ").filter { !["-", "–", "—"].contains($0) }
        guard let first = parts.first,
              let version = AppVersion(first.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
        else { return nil }
        return (version, parts.dropFirst().first.flatMap { day(String($0)) })
    }

    private static func day(_ text: String) -> Date? {
        let numbers = text.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: numbers[0], month: numbers[1], day: numbers[2]))
    }
}
