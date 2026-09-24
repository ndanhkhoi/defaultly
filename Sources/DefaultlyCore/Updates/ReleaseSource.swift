import Foundation

/// Where releases are published and downloaded from.
public protocol ReleaseSource: Sendable {
    func releases() async throws -> [Release]
    func data(from url: URL) async throws -> Data
    /// Downloads to a temporary file that the caller moves or deletes. `progress` goes from 0 to 1.
    func download(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

public enum UpdateError: LocalizedError, Equatable {
    case server(status: Int)
    case rateLimited
    case missingChecksum
    case checksumMismatch
    case unreadableArchive
    case wrongApp(expected: String)
    case invalidSignature
    case differentDeveloper

    public var errorDescription: String? {
        switch self {
        case .server(let status):
            String(localized: "GitHub answered with an error (HTTP \(status)).", bundle: .main)
        case .rateLimited:
            String(localized: "GitHub is limiting requests from your network. Try again in an hour.", bundle: .main)
        case .missingChecksum:
            String(localized: "The release has no checksum for its download, so it can't be verified.", bundle: .main)
        case .checksumMismatch:
            String(localized: "The download is damaged: its checksum doesn't match the release.", bundle: .main)
        case .unreadableArchive:
            String(localized: "The download couldn't be unpacked.", bundle: .main)
        case .wrongApp(let expected):
            String(localized: "The download doesn't contain \(expected).", bundle: .main)
        case .invalidSignature:
            String(localized: "The downloaded app's code signature isn't valid.", bundle: .main)
        case .differentDeveloper:
            String(localized: "The downloaded app is signed by a different developer.", bundle: .main)
        }
    }
}

/// `ReleaseSource` backed by the GitHub REST API and release downloads.
public struct GitHubReleaseClient: ReleaseSource {
    private let releasesURL: URL
    private let appName: String
    private let userAgent: String
    private let session: URLSession

    /// `releasesURL` is `https://api.github.com/repos/{owner}/{repo}/releases`.
    public init(releasesURL: URL, appName: String, appVersion: String, session: URLSession = .shared) {
        self.releasesURL = releasesURL
        self.appName = appName
        userAgent = "\(appName)/\(appVersion)"
        self.session = session
    }

    public func releases() async throws -> [Release] {
        var request = URLRequest(url: releasesURL, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        try Self.check(response)
        return try Release.decodeGitHubReleases(data, appName: appName)
    }

    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(for: request(url))
        try Self.check(response)
        return data
    }

    public func download(from url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let (file, response) = try await session.download(for: request(url), delegate: ProgressReporter(progress))
        do {
            try Self.check(response)
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw error
        }
        return file
    }

    private func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        if [403, 429].contains(http.statusCode), http.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0" {
            throw UpdateError.rateLimited
        }
        throw UpdateError.server(status: http.statusCode)
    }
}

/// Async downloads don't report bytes to their delegate, but their task's `Progress` does.
private final class ProgressReporter: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let report: @Sendable (Double) -> Void
    // Set once, from the session's delegate queue, before any progress is reported.
    private var observation: NSKeyValueObservation?

    init(_ report: @escaping @Sendable (Double) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        let report = report
        observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            report(progress.fractionCompleted)
        }
    }
}
