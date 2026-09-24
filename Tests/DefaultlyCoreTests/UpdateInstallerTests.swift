import Foundation
import Testing
@testable import DefaultlyCore

/// Builds real, ad-hoc signed app bundles and zips in a temporary folder, as the release pipeline does.
struct UpdateInstallerTests {
    static let bundleID = "io.github.ndanhkhoi.defaultly"
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("defaultly-update-\(UUID())", isDirectory: true)
    let base = URL(string: "https://example.com/releases/download/v1.1.0/")!

    @Test func preparesAVerifiedRelease() async throws {
        let (installer, release) = try publish(makeApp(version: "1.1.0"))
        defer { cleanUp() }
        let prepared = try await installer.prepare(release) { _ in }
        #expect(shortVersion(of: prepared.appURL) == "1.1.0")
        #expect(prepared.appURL.resolvingSymlinksInPath().path.hasPrefix(staging.resolvingSymlinksInPath().path))
    }

    @Test func rejectsADamagedDownload() async throws {
        let (installer, release) = try publish(makeApp(version: "1.1.0"), checksum: String(repeating: "0", count: 64))
        defer { cleanUp() }
        await #expect(throws: UpdateError.checksumMismatch) { try await installer.prepare(release) { _ in } }
    }

    @Test func rejectsAReleaseWithoutItsChecksum() async throws {
        let (installer, release) = try publish(makeApp(version: "1.1.0"), checksumName: "Other.zip")
        defer { cleanUp() }
        await #expect(throws: UpdateError.missingChecksum) { try await installer.prepare(release) { _ in } }
    }

    @Test(arguments: [(Self.bundleID, "1.0.9"), ("com.example.other", "1.1.0")])
    func rejectsAnotherAppOrVersion(bundleID: String, version: String) async throws {
        let (installer, release) = try publish(makeApp(bundleID: bundleID, version: version))
        defer { cleanUp() }
        await #expect(throws: UpdateError.wrongApp(expected: "\(Self.bundleID) 1.1.0")) { try await installer.prepare(release) { _ in } }
    }

    /// Both downloads use the same staging folder, as retries in one session do.
    @Test func aSecondDownloadInTheSameSessionIsReadAfresh() async throws {
        defer { cleanUp() }
        let (wrong, wrongRelease) = try publish(makeApp(version: "1.0.9", name: "first"))
        await #expect(throws: UpdateError.wrongApp(expected: "\(Self.bundleID) 1.1.0")) { try await wrong.prepare(wrongRelease) { _ in } }
        let (installer, release) = try publish(makeApp(version: "1.1.0", name: "second"))
        let prepared = try await installer.prepare(release) { _ in }
        #expect(shortVersion(of: prepared.appURL) == "1.1.0")
    }

    @Test func rejectsUnsignedOrModifiedApps() throws {
        defer { cleanUp() }
        let installer = UpdateInstaller(source: FakeReleaseSource(), bundleID: Self.bundleID, signature: .adHoc, stagingFolder: staging)
        let unsigned = try makeApp(version: "1.1.0", signed: false, name: "unsigned")
        #expect(throws: UpdateError.invalidSignature) { try installer.verifiedApp(in: unsigned.deletingLastPathComponent(), version: version("1.1.0")) }

        let modified = try makeApp(version: "1.1.0", name: "modified")
        try Data("extra".utf8).write(to: modified.appendingPathComponent("Contents/Resources/added.txt"))
        #expect(throws: UpdateError.invalidSignature) { try installer.verifiedApp(in: modified.deletingLastPathComponent(), version: version("1.1.0")) }
    }

    @Test func requiresAppleIssuedDeveloperIDOfTheSameTeamWhenTheRunningAppHasOne() throws {
        defer { cleanUp() }
        let adHoc = try makeApp(version: "1.1.0")
        let folder = adHoc.deletingLastPathComponent()
        let developerID = UpdateInstaller(source: FakeReleaseSource(), bundleID: Self.bundleID, signature: .developerID(teamID: "ABCDE12345"), stagingFolder: staging)
        #expect(throws: UpdateError.differentDeveloper) { try developerID.verifiedApp(in: folder, version: version("1.1.0")) }
        // Apple's own apps are validly signed, but not with a Developer ID of this team.
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        #expect(throws: UpdateError.differentDeveloper) { try CodeSignature.validate(textEdit, for: .developerID(teamID: "ABCDE12345")) }
        #expect(CodeSignature.developerIDRequirement(teamID: "ABC\" or anchor apple") == nil)
    }

    @Test func refusesEverythingWhenTheRunningSignatureIsUnreadable() throws {
        defer { cleanUp() }
        let installer = UpdateInstaller(source: FakeReleaseSource(), bundleID: Self.bundleID, signature: .unreadable, stagingFolder: staging)
        let app = try makeApp(version: "1.1.0")
        #expect(throws: UpdateError.invalidSignature) { try installer.verifiedApp(in: app.deletingLastPathComponent(), version: version("1.1.0")) }
    }

    @Test func installReplacesTheAppAndCleansUp() async throws {
        let (installer, release) = try publish(makeApp(version: "1.1.0"))
        defer { cleanUp() }
        let installed = try makeApp(version: "1.0.0", name: "Applications")
        let prepared = try await installer.prepare(release) { _ in }
        try installer.install(prepared, replacing: installed)
        #expect(shortVersion(of: installed) == "1.1.0")
        #expect(!FileManager.default.fileExists(atPath: staging.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: installed.deletingLastPathComponent().path) == ["Defaultly.app"])
    }

    @Test func aFailedSwapKeepsTheOldApp() async throws {
        let (installer, release) = try publish(makeApp(version: "1.1.0"))
        defer { cleanUp() }
        let installed = try makeApp(version: "1.0.0", name: "Applications")
        let prepared = try await installer.prepare(release) { _ in }
        let applications = installed.deletingLastPathComponent().path
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: applications)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: applications) }
        #expect(throws: (any Error).self) { try installer.install(prepared, replacing: installed) }
        #expect(shortVersion(of: installed) == "1.0.0")
        #expect(throws: Never.self) { try CodeSignature.validate(installed, for: .adHoc) }
    }

    @Test func installChecksThePreparedAppAgain() async throws {
        let (installer, release) = try publish(makeApp(version: "1.1.0"))
        defer { cleanUp() }
        let installed = try makeApp(version: "1.0.0", name: "Applications")
        let prepared = try await installer.prepare(release) { _ in }
        try FileManager.default.removeItem(at: prepared.appURL.appendingPathComponent("Contents/MacOS/Defaultly"))
        #expect(throws: UpdateError.invalidSignature) { try installer.install(prepared, replacing: installed) }
        #expect(shortVersion(of: installed) == "1.0.0")
    }

    @Test func detectsLocationsItCantInstallTo() throws {
        defer { cleanUp() }
        let app = try makeApp(version: "1.0.0")
        #expect(UpdateInstaller.problem(installingAt: app) == nil)
        #expect(UpdateInstaller.problem(installingAt: URL(fileURLWithPath: "/usr/local/bin/defaultly")) == .notAnApp)
        #expect(UpdateInstaller.problem(installingAt: URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/ABC/d/Defaultly.app")) == .translocated)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: app.deletingLastPathComponent().path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: app.deletingLastPathComponent().path) }
        #expect(UpdateInstaller.problem(installingAt: app) == .readOnly)
    }

    // MARK: - Helpers

    private var staging: URL { folder.appendingPathComponent("staging", isDirectory: true) }

    private func version(_ text: String) -> AppVersion { AppVersion(text)! }

    private func shortVersion(of app: URL) -> String? {
        UpdateInstaller.infoDictionary(of: app)?["CFBundleShortVersionString"] as? String
    }

    private func release() -> Release {
        Release(
            version: version("1.1.0"), notes: "", publishedAt: nil, pageURL: base,
            archiveURL: base.appendingPathComponent("Defaultly-1.1.0.zip"), checksumsURL: base.appendingPathComponent("SHA256SUMS.txt")
        )
    }

    /// Zips `app` like `scripts/package-release.sh` and serves it with its checksum.
    private func publish(_ app: URL, checksum: String? = nil, checksumName: String = "Defaultly-1.1.0.zip") throws -> (UpdateInstaller, Release) {
        let release = release()
        let zip = app.deletingLastPathComponent().appendingPathComponent("Defaultly-1.1.0.zip")
        try run("/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app.path, zip.path)
        let sums = app.deletingLastPathComponent().appendingPathComponent("SHA256SUMS.txt")
        try Data("\(try checksum ?? Checksums.sha256(of: zip))  \(checksumName)\n".utf8).write(to: sums)
        let source = FakeReleaseSource(files: [release.archiveURL!: zip, release.checksumsURL!: sums])
        return (UpdateInstaller(source: source, bundleID: Self.bundleID, signature: .adHoc, stagingFolder: staging), release)
    }

    private func makeApp(bundleID: String = bundleID, version: String, signed: Bool = true, name: String = UUID().uuidString) throws -> URL {
        let app = folder.appendingPathComponent(name).appendingPathComponent("Defaultly.app")
        let contents = app.appendingPathComponent("Contents")
        for sub in ["MacOS", "Resources"] {
            try FileManager.default.createDirectory(at: contents.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: contents.appendingPathComponent("MacOS/Defaultly"))
        let info: [String: Any] = [
            "CFBundleIdentifier": bundleID, "CFBundleShortVersionString": version, "CFBundleVersion": "1",
            "CFBundleExecutable": "Defaultly", "CFBundleName": "Defaultly", "CFBundlePackageType": "APPL",
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        if signed { try run("/usr/bin/codesign", "--force", "--sign", "-", app.path) }
        return app
    }

    private func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0, "\(tool) \(arguments.joined(separator: " "))")
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(at: folder)
    }
}

/// Serves local files in place of release downloads.
struct FakeReleaseSource: ReleaseSource {
    var releaseList: [Release] = []
    var files: [URL: URL] = [:]

    func releases() async throws -> [Release] { releaseList }

    func data(from url: URL) async throws -> Data {
        guard let file = files[url] else { throw UpdateError.server(status: 404) }
        return try Data(contentsOf: file)
    }

    func download(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        guard let file = files[url] else { throw UpdateError.server(status: 404) }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("download-\(UUID())")
        try FileManager.default.copyItem(at: file, to: copy)
        progress(1)
        return copy
    }
}
