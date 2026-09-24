import Foundation

/// A published version of the app and the files it ships with.
public struct Release: Identifiable, Equatable, Sendable {
    public let version: AppVersion
    /// Markdown, as published.
    public let notes: String
    public let publishedAt: Date?
    public let pageURL: URL
    /// `<App>-<version>.zip`, which the app installs from.
    public let archiveURL: URL?
    /// `SHA256SUMS.txt`, which the archive is checked against.
    public let checksumsURL: URL?

    public init(version: AppVersion, notes: String, publishedAt: Date?, pageURL: URL, archiveURL: URL?, checksumsURL: URL?) {
        self.version = version
        self.notes = notes
        self.publishedAt = publishedAt
        self.pageURL = pageURL
        self.archiveURL = archiveURL
        self.checksumsURL = checksumsURL
    }

    public var id: AppVersion { version }

    public var archiveName: String? { archiveURL?.lastPathComponent }

    /// Only releases the app can verify are offered.
    public var isInstallable: Bool { archiveURL != nil && checksumsURL != nil }
}

/// A newer release, with every release since the running version so their notes can all be shown.
public struct AvailableUpdate: Equatable, Sendable {
    public let release: Release
    /// Newest first, `release` included.
    public let newReleases: [Release]

    /// The newest installable release newer than `current`, or nil when there is none or it is the skipped one.
    /// A release newer than the skipped version is offered again.
    public init?(releases: [Release], current: AppVersion, skipping skipped: AppVersion? = nil) {
        let newer = releases.filter { $0.version > current }.sorted { $0.version > $1.version }
        guard let newest = newer.first(where: \.isInstallable) else { return nil }
        if let skipped, newest.version <= skipped { return nil }
        release = newest
        newReleases = newer.filter { $0.version <= newest.version }
    }
}

// MARK: - GitHub

public extension Release {
    /// Decodes `GET /repos/{owner}/{repo}/releases` from the GitHub REST API. Drafts, pre-releases and tags
    /// that aren't versions are left out. Assets are matched by name: `<appName>-<version>.zip` and `SHA256SUMS.txt`.
    static func decodeGitHubReleases(_ data: Data, appName: String) throws -> [Release] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GitHubRelease].self, from: data).compactMap { $0.release(appName: appName) }
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: URL
    }

    let tagName: String
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let publishedAt: Date?
    let htmlUrl: URL
    let assets: [Asset]

    func release(appName: String) -> Release? {
        guard !draft, !prerelease, let version = AppVersion(tagName) else { return nil }
        // Asset names use the version as tagged (`v1.2` → `1.2`), not the padded `1.2.0`.
        let tagged = tagName.first == "v" || tagName.first == "V" ? String(tagName.dropFirst()) : tagName
        func asset(_ name: String) -> URL? { assets.first { $0.name == name }?.browserDownloadUrl }
        return Release(
            version: version,
            notes: body ?? "",
            publishedAt: publishedAt,
            pageURL: htmlUrl,
            archiveURL: asset("\(appName)-\(tagged).zip"),
            checksumsURL: asset("SHA256SUMS.txt")
        )
    }
}
