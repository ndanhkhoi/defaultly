import CryptoKit
import Darwin
import Foundation
import Security

/// A downloaded release that passed every check, waiting to replace the running app.
public struct PreparedUpdate: Equatable, Sendable {
    public let release: Release
    /// The verified app bundle, unpacked in the staging folder.
    public let appURL: URL

    public init(release: Release, appURL: URL) {
        self.release = release
        self.appURL = appURL
    }
}

/// Why the running app can't replace itself.
public enum InstallLocationProblem: Equatable, Sendable {
    /// Not an app bundle, e.g. a bare executable started with `swift run`.
    case notAnApp
    /// macOS runs the app from a hidden read-only copy because it wasn't moved out of the download folder or disk image.
    case translocated
    /// The user can't replace the app or write to its folder.
    case readOnly
}

/// How the running app is signed, which decides the updates it accepts.
public enum RunningSignature: Equatable, Sendable {
    /// Any validly signed build is accepted; the checksum ties it to the release.
    case adHoc
    /// Only builds signed with an Apple-issued Developer ID certificate of this team.
    case developerID(teamID: String)
    /// The running app's signature couldn't be read, so no update can be trusted.
    case unreadable
}

/// Prepares and installs updates; the controller depends on this rather than on `UpdateInstaller`.
public protocol UpdateInstalling: Sendable {
    func prepare(_ release: Release, progress: @escaping @Sendable (Double) -> Void) async throws -> PreparedUpdate
    func install(_ update: PreparedUpdate, replacing appURL: URL) throws
}

/// Downloads, verifies and installs releases of the running app.
///
/// A release is only installed when its archive matches `SHA256SUMS.txt`, it unpacks to an app with the running app's
/// bundle ID and the release's version, and its code signature is valid (with the same Developer ID team once the
/// running app has one). Installing first moves the new bundle onto the app's volume, then swaps the two in one step,
/// so there is never a moment without an app, a failure leaves the old one untouched, and nothing of the old bundle,
/// such as a quarantine flag, carries over.
public struct UpdateInstaller: UpdateInstalling {
    private let source: any ReleaseSource
    private let bundleID: String
    private let signature: RunningSignature
    private let stagingFolder: URL

    /// `signature` is the running app's (see `CodeSignature.running`).
    /// `stagingFolder` holds downloads and is emptied before each one.
    public init(source: any ReleaseSource, bundleID: String, signature: RunningSignature, stagingFolder: URL) {
        self.source = source
        self.bundleID = bundleID
        self.signature = signature
        self.stagingFolder = stagingFolder
    }

    public static func problem(installingAt appURL: URL) -> InstallLocationProblem? {
        guard appURL.pathExtension == "app" else { return .notAnApp }
        if appURL.path.contains("/AppTranslocation/") { return .translocated }
        let fileManager = FileManager.default
        let folder = appURL.deletingLastPathComponent().path
        guard fileManager.isWritableFile(atPath: folder), fileManager.isWritableFile(atPath: appURL.path) else { return .readOnly }
        return nil
    }

    // MARK: - Preparing

    public func prepare(_ release: Release, progress: @escaping @Sendable (Double) -> Void) async throws -> PreparedUpdate {
        guard let archiveURL = release.archiveURL, let archiveName = release.archiveName, let checksumsURL = release.checksumsURL else {
            throw UpdateError.missingChecksum
        }
        let checksums = Checksums.parse(String(decoding: try await source.data(from: checksumsURL), as: UTF8.self))
        guard let expected = checksums[archiveName] else { throw UpdateError.missingChecksum }

        let fileManager = FileManager.default
        try? fileManager.removeItem(at: stagingFolder)
        try fileManager.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        let archive = stagingFolder.appendingPathComponent(archiveName)
        let download = try await source.download(from: archiveURL, progress: progress)
        try fileManager.moveItem(at: download, to: archive)

        guard try Checksums.sha256(of: archive) == expected else { throw UpdateError.checksumMismatch }
        // A fresh folder each time: an earlier attempt's bundle at the same path must not be mistaken for this one.
        let unpacked = stagingFolder.appendingPathComponent("unpacked-\(UUID().uuidString)", isDirectory: true)
        try await Self.unzip(archive, into: unpacked)
        try? fileManager.removeItem(at: archive)
        let app = try verifiedApp(in: unpacked, version: release.version)
        return PreparedUpdate(release: release, appURL: app)
    }

    /// The single app bundle in `folder`, if it is this app at `version` with a valid signature.
    func verifiedApp(in folder: URL, version: AppVersion) throws -> URL {
        let contents = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let apps = contents.filter { $0.pathExtension == "app" }
        guard apps.count == 1, let app = apps.first,
              let info = Self.infoDictionary(of: app),
              info["CFBundleIdentifier"] as? String == bundleID,
              let shortVersion = info["CFBundleShortVersionString"] as? String,
              AppVersion(shortVersion) == version
        else { throw UpdateError.wrongApp(expected: "\(bundleID) \(version)") }
        try CodeSignature.validate(app, for: signature)
        return app
    }

    /// Read from disk each time: `Bundle` keeps what it first read for a path for the rest of the process.
    static func infoDictionary(of app: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    private static func unzip(_ archive: URL, into folder: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, folder.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
        guard status == 0 else { throw UpdateError.unreadableArchive }
    }

    // MARK: - Installing

    /// Checks the prepared app again (it may have waited in the caches folder for days), then swaps it with the app at
    /// `appURL` and deletes the old one and the staging folder. The running process is unaffected; relaunch to use it.
    public func install(_ update: PreparedUpdate, replacing appURL: URL) throws {
        _ = try verifiedApp(in: update.appURL.deletingLastPathComponent(), version: update.release.version)
        let fileManager = FileManager.default
        // A folder on the app's volume. Moving the new app there may copy it; the installed app isn't touched yet.
        let holding = try fileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: appURL, create: true)
        defer { try? fileManager.removeItem(at: holding) }
        let incoming = holding.appendingPathComponent(appURL.lastPathComponent)
        try fileManager.moveItem(at: update.appURL, to: incoming)
        // One atomic exchange: either nothing changed, or `appURL` is the new app and `incoming` the old one.
        guard renamex_np(incoming.path, appURL.path, UInt32(RENAME_SWAP)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        try? fileManager.removeItem(at: stagingFolder)
    }
}

// MARK: - Checksums

enum Checksums {
    /// `shasum -a 256` output: `<hex>  <file>` per line, with `*` before the name in binary mode. Keyed by file name.
    static func parse(_ text: String) -> [String: String] {
        var sums: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, parts[0].count == 64, parts[0].allSatisfy(\.isHexDigit) else { continue }
            var name = parts[1].trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("*") { name.removeFirst() }
            sums[name] = parts[0].lowercased()
        }
        return sums
    }

    static func sha256(of file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Code signatures

public enum CodeSignature {
    /// How the running app is signed.
    public static var running: RunningSignature {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let info = info as? [String: Any]
        else { return .unreadable }
        guard let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String else { return .adHoc }
        return .developerID(teamID: teamID)
    }

    /// Checks the whole bundle, every architecture and nested code included. For a Developer ID app, the update must
    /// also satisfy a requirement that pins Apple's Developer ID chain and the team: a team ID written into a
    /// self-signed signature doesn't pass.
    static func validate(_ app: URL, for signature: RunningSignature) throws {
        var requirement: SecRequirement?
        switch signature {
        case .adHoc:
            break
        case .developerID(let teamID):
            requirement = developerIDRequirement(teamID: teamID)
            guard requirement != nil else { throw UpdateError.invalidSignature }
        case .unreadable:
            throw UpdateError.invalidSignature
        }
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateError.invalidSignature
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        switch SecStaticCodeCheckValidity(code, flags, requirement) {
        case errSecSuccess: return
        case errSecCSReqFailed: throw UpdateError.differentDeveloper
        default: throw UpdateError.invalidSignature
        }
    }

    /// Apple's Developer ID Application chain, issued to `teamID`.
    static func developerIDRequirement(teamID: String) -> SecRequirement? {
        guard !teamID.isEmpty, teamID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        let text = "anchor apple generic"
            + " and certificate 1[field.1.2.840.113635.100.6.2.6] exists"
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
            + " and certificate leaf[subject.OU] = \"\(teamID)\""
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess else { return nil }
        return requirement
    }
}
