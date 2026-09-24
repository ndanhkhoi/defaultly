import Foundation
import Testing
@testable import DefaultlyCore

/// Downloads the latest published release from GitHub, so it only runs when asked to.
/// It installs into a temporary folder, never over a real app.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["DEFAULTLY_INTEGRATION"] == "1"))
struct UpdateIntegrationTests {
    @Test func installsTheLatestPublishedRelease() async throws {
        let old = try #require(AppVersion("0.0.1"))
        let client = GitHubReleaseClient(
            releasesURL: try #require(URL(string: "https://api.github.com/repos/ndanhkhoi/defaultly/releases")),
            appName: "Defaultly",
            appVersion: old.description
        )
        let update = try #require(AvailableUpdate(releases: try await client.releases(), current: old))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("defaultly-integration-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let installed = folder.appendingPathComponent("Applications/Defaultly.app")
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)

        let installer = UpdateInstaller(
            source: client, bundleID: "io.github.ndanhkhoi.defaultly", signature: .adHoc,
            stagingFolder: folder.appendingPathComponent("staging")
        )
        let prepared = try await installer.prepare(update.release) { _ in }
        try installer.install(prepared, replacing: installed)

        let version = UpdateInstaller.infoDictionary(of: installed)?["CFBundleShortVersionString"] as? String
        #expect(version.flatMap(AppVersion.init) == update.release.version)
        // Downloads made by the app aren't quarantined, so Gatekeeper doesn't stop the new version.
        #expect(getxattr(installed.path, "com.apple.quarantine", nil, 0, 0, 0) == -1)
    }
}
