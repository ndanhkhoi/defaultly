import Foundation
import Testing
@testable import DefaultlyCore

struct AppVersionTests {
    @Test func parsesTagsAndPadsMissingNumbers() {
        #expect(AppVersion("v1.2.3")?.components == [1, 2, 3])
        #expect(AppVersion("1.2") == AppVersion("1.2.0"))
        #expect(AppVersion(" 2 ")?.description == "2.0.0")
    }

    @Test func rejectsWhatIsNotAVersion() {
        for text in ["", "v", "1.2.3.4", "1..2", "1.2.3-beta", "one", "1.-2", "１.２"] {
            #expect(AppVersion(text) == nil, "\(text)")
        }
    }

    @Test func comparesNumerically() throws {
        let versions = try ["1.10.0", "1.9.9", "2.0.0", "1.0.1", "1.0.0"].map { try #require(AppVersion($0)) }
        #expect(versions.sorted().map(\.description) == ["1.0.0", "1.0.1", "1.9.9", "1.10.0", "2.0.0"])
    }
}

struct UpdateScheduleTests {
    @Test func isDueADayAfterTheLastCheck() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(UpdateSchedule.isDue(lastCheck: nil, now: now))
        #expect(!UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(-UpdateSchedule.interval), now: now))
        #expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(3600), now: now), "clock set back")
    }
}

struct ReleaseFeedTests {
    @Test func decodesGitHubReleasesAndMatchesAssets() throws {
        let releases = try Release.decodeGitHubReleases(Data(Self.gitHubJSON.utf8), appName: "Defaultly")
        #expect(releases.map(\.version.description) == ["1.2.0", "1.1.0", "1.0.0"])
        let newest = try #require(releases.first)
        #expect(newest.archiveURL?.lastPathComponent == "Defaultly-1.2.zip")
        #expect(newest.checksumsURL?.lastPathComponent == "SHA256SUMS.txt")
        #expect(newest.pageURL.absoluteString == "https://github.com/o/r/releases/tag/v1.2")
        #expect(newest.publishedAt == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(releases[1].isInstallable == false)
    }

    @Test func offersTheNewestInstallableReleaseWithEveryNewerOnesNotes() throws {
        let releases = [release("1.3.0", installable: false), release("1.2.0"), release("1.1.0"), release("1.0.0")]
        let update = try #require(AvailableUpdate(releases: releases, current: version("1.0.0")))
        #expect(update.release.version == version("1.2.0"))
        #expect(update.newReleases.map(\.version.description) == ["1.2.0", "1.1.0"])
    }

    @Test func offersNothingWhenUpToDateOrSkipped() {
        let releases = [release("1.2.0"), release("1.1.0")]
        #expect(AvailableUpdate(releases: releases, current: version("1.2.0")) == nil)
        #expect(AvailableUpdate(releases: releases, current: version("1.3.0")) == nil)
        #expect(AvailableUpdate(releases: releases, current: version("1.0.0"), skipping: version("1.2.0")) == nil)
        #expect(AvailableUpdate(releases: releases, current: version("1.0.0"), skipping: version("1.1.0"))?.release.version == version("1.2.0"))
    }

    private func version(_ text: String) -> AppVersion { AppVersion(text)! }

    private func release(_ text: String, installable: Bool = true) -> Release {
        let base = URL(string: "https://example.com/\(text)/")!
        return Release(
            version: version(text), notes: "", publishedAt: nil, pageURL: base,
            archiveURL: installable ? base.appendingPathComponent("Defaultly-\(text).zip") : nil,
            checksumsURL: installable ? base.appendingPathComponent("SHA256SUMS.txt") : nil
        )
    }

    private static let gitHubJSON = """
    [
      {"tag_name": "v1.2", "body": "Notes", "draft": false, "prerelease": false,
       "published_at": "2026-09-21T14:13:20Z", "html_url": "https://github.com/o/r/releases/tag/v1.2",
       "assets": [
         {"name": "Defaultly-1.2.zip", "browser_download_url": "https://github.com/o/r/releases/download/v1.2/Defaultly-1.2.zip"},
         {"name": "SHA256SUMS.txt", "browser_download_url": "https://github.com/o/r/releases/download/v1.2/SHA256SUMS.txt"}]},
      {"tag_name": "v1.3.0", "body": null, "draft": true, "prerelease": false, "published_at": null,
       "html_url": "https://github.com/o/r/releases/tag/v1.3.0", "assets": []},
      {"tag_name": "v1.2.1-beta", "body": "", "draft": false, "prerelease": true, "published_at": null,
       "html_url": "https://github.com/o/r/releases/tag/v1.2.1-beta", "assets": []},
      {"tag_name": "nightly", "body": "", "draft": false, "prerelease": false, "published_at": null,
       "html_url": "https://github.com/o/r/releases/tag/nightly", "assets": []},
      {"tag_name": "v1.1.0", "body": null, "draft": false, "prerelease": false, "published_at": null,
       "html_url": "https://github.com/o/r/releases/tag/v1.1.0", "assets": []},
      {"tag_name": "v1.0.0", "body": "", "draft": false, "prerelease": false, "published_at": null,
       "html_url": "https://github.com/o/r/releases/tag/v1.0.0", "assets": []}
    ]
    """
}

struct ReleaseNotesTests {
    @Test func splitsMarkdownIntoBlocks() {
        let markdown = """
        ### Fixed

        - **Fixed:** a crash when
          switching categories.
        * Nested
            - child
        A paragraph that
        wraps.
        ---
        #hashtag stays text
        """
        #expect(ReleaseNotes.blocks(from: markdown) == [
            .heading("Fixed"),
            .bullet("**Fixed:** a crash when switching categories."),
            .bullet("Nested"),
            .bullet("child A paragraph that wraps."),
            .paragraph("#hashtag stays text"),
        ])
    }

    @Test func keepsOnlyTheChangesOfAReleaseBody() {
        let body = """
        ## What’s changed

        - New thing

        ## Install

        1. Download it.

        **Full Changelog**: https://github.com/o/r/compare/v1.0.0...v1.0.1
        """
        #expect(ReleaseNotes.changes(inReleaseBody: body) == "- New thing")
    }

    @Test func fallsBackToTheTextBeforeTheFirstSection() {
        #expect(ReleaseNotes.changes(inReleaseBody: "- Fix\n\n**Full Changelog**: link\n## Install\nSteps") == "- Fix")
        #expect(ReleaseNotes.changes(inReleaseBody: "## Install\n\nSteps") == "")
    }
}

struct ChangelogTests {
    @Test func parsesReleasedVersionsInFileOrder() throws {
        let markdown = """
        # Changelog

        Intro text.

        ## Unreleased

        - Not yet

        ## [1.1.0] - 2026-09-25

        ### Added
        - Updates

        ## 1.0.1 – 2026-09-24

        - Fix

        ## 1.0.0
        - First
        """
        let entries = Changelog.parse(markdown)
        #expect(entries.map(\.version.description) == ["1.1.0", "1.0.1", "1.0.0"])
        #expect(entries[0].notes == "### Added\n- Updates")
        #expect(entries[1].notes == "- Fix")
        #expect(entries[2].date == nil)
        let day = try #require(entries[0].date)
        #expect(Calendar.current.dateComponents([.year, .month, .day], from: day) == DateComponents(year: 2026, month: 9, day: 25))
    }

    @Test func readsTheRepositoryChangelog() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../CHANGELOG.md")
        let entries = Changelog.parse(try String(contentsOf: file, encoding: .utf8))
        #expect(!entries.isEmpty)
        #expect(entries.allSatisfy { !$0.notes.isEmpty && $0.date != nil })
        #expect(entries.map(\.version) == entries.map(\.version).sorted(by: >), "newest version first")
    }
}

struct ChecksumsTests {
    @Test func parsesShasumOutput() {
        let hex = String(repeating: "ab", count: 32)
        let text = "\(hex)  Defaultly-1.0.zip\n\(hex.uppercased()) *Defaultly-1.0.dmg\nnot a line\n\(hex.prefix(10))  short.zip\n"
        #expect(Checksums.parse(text) == ["Defaultly-1.0.zip": hex, "Defaultly-1.0.dmg": hex])
    }

    @Test func hashesFiles() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("defaultly-\(UUID()).txt")
        try Data("abc".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(try Checksums.sha256(of: file) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
