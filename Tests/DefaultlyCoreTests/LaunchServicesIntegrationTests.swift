import Foundation
import Testing
@testable import DefaultlyCore

/// Touches the real LaunchServices database, so it only runs when asked to,
/// and only with an extension no real file uses.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["DEFAULTLY_INTEGRATION"] == "1"))
struct LaunchServicesIntegrationTests {
    @Test func setsAndVerifiesAMadeUpExtension() async throws {
        let locator = SystemAppLocator()
        let textEdit = try #require(locator.app(bundleID: "com.apple.TextEdit"))
        let service = AssociationService(launchServices: SystemLaunchServices(), apps: locator)
        let report = await service.apply([Assignment(ext: .ext("defaultlytest"), app: textEdit)])
        #expect(report.outcomes.map(\.result) == [.applied])
    }
}
