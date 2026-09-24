import AppKit
import CoreServices
import UniformTypeIdentifiers

/// How a default app is written.
public enum AssignmentMethod: Sendable {
    /// Writes the handler directly: instant and silent, but macOS may quietly ignore it
    /// for types another app owns. Not silent from macOS 27 (see `instantWritesAreSilent`).
    case instant
    /// Asks macOS through `NSWorkspace`: about 2 s per call, and macOS may ask the user to confirm.
    case interactive
}

/// The system database that maps file types to the apps that open them.
public protocol LaunchServicesClient: Sendable {
    func defaultApplication(for ext: FileExtension) -> URL?
    /// Apps that declare they can open the extension, most relevant first.
    func applications(for ext: FileExtension) -> [URL]
    /// False from macOS 27: an instant write then queues a system confirmation for each content type and returns
    /// before the user answers, so it asks more often than the interactive method and can't tell what they chose.
    var instantWritesAreSilent: Bool { get }
    func setDefaultApplication(_ app: AppInfo, for ext: FileExtension, using method: AssignmentMethod) async throws
}

public enum LaunchServicesError: LocalizedError, Equatable {
    case unknownType(FileExtension)
    /// The user declined the system prompt that confirms the change.
    case declined

    public var errorDescription: String? {
        switch self {
        case .unknownType(let ext):
            String(localized: "macOS has no content type for \(ext.description).", bundle: .main)
        case .declined:
            String(localized: "The change wasn't allowed.", bundle: .main)
        }
    }
}

/// `LaunchServicesClient` backed by LaunchServices and `NSWorkspace`.
public struct SystemLaunchServices: LaunchServicesClient {
    public init() {}

    public func defaultApplication(for ext: FileExtension) -> URL? {
        guard let type = ext.contentTypes.first else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: type)
    }

    public func applications(for ext: FileExtension) -> [URL] {
        var seen = Set<String>()
        return ext.contentTypes
            .flatMap { NSWorkspace.shared.urlsForApplications(toOpen: $0) }
            .filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    public var instantWritesAreSilent: Bool {
        guard Self.setRoleHandler != nil else { return false }
        if #available(macOS 27, *) { return false }
        return true
    }

    /// Instant writes cover every content type of the extension. The interactive API sets only the
    /// preferred one (the one Finder uses), because each call may ask the user to confirm.
    public func setDefaultApplication(_ app: AppInfo, for ext: FileExtension, using method: AssignmentMethod) async throws {
        let types = ext.contentTypes
        guard let preferred = types.first else { throw LaunchServicesError.unknownType(ext) }
        // Apps picked from outside the usual folders must be known to LaunchServices first.
        _ = LSRegisterURL(app.url as CFURL, false)

        if method == .instant, let setHandler = Self.setRoleHandler {
            for type in types {
                _ = setHandler(type.identifier as CFString, Self.allRoles, app.bundleID as CFString)
            }
            return
        }
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: app.url, toOpen: preferred)
        } catch let error as NSError where error.isUserCancellation {
            throw LaunchServicesError.declined
        }
    }

    private typealias SetRoleHandler = @convention(c) (CFString, UInt32, CFString) -> OSStatus

    private static let allRoles = UInt32.max

    /// `LSSetDefaultRoleHandlerForContentType` is deprecated but is still what makes bulk changes
    /// instant. It is looked up at runtime so the build stays warning-free and the NSWorkspace
    /// path takes over if the function is ever removed.
    private static let setRoleHandler: SetRoleHandler? = {
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        guard let symbol = dlsym(defaultHandle, "LSSetDefaultRoleHandlerForContentType") else { return nil }
        return unsafeBitCast(symbol, to: SetRoleHandler.self)
    }()
}

private extension NSError {
    /// NSWorkspace wraps a declined confirmation as a Cocoa error around `userCanceledErr` (-128).
    var isUserCancellation: Bool {
        let underlying = userInfo[NSUnderlyingErrorKey] as? NSError
        return (domain == NSCocoaErrorDomain && code == NSUserCancelledError)
            || (underlying?.domain == NSOSStatusErrorDomain && underlying?.code == -128)
    }
}
