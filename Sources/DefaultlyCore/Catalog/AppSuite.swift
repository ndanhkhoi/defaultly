import Foundation

/// A family of apps that together cover several categories, e.g. Word + Excel + PowerPoint.
public struct AppSuite: Identifiable, Sendable {
    public struct Member: Sendable {
        public let categoryID: String
        public let bundleID: String
    }

    public let id: String
    public let name: String
    public let members: [Member]

    public static let all: [AppSuite] = [
        officeSuite(id: "microsoft-office", name: "Microsoft Office",
                    documents: "com.microsoft.Word", spreadsheets: "com.microsoft.Excel", presentations: "com.microsoft.Powerpoint"),
        officeSuite(id: "apple-iwork", name: "Apple iWork",
                    documents: "com.apple.iWork.Pages", spreadsheets: "com.apple.iWork.Numbers", presentations: "com.apple.iWork.Keynote"),
        officeSuite(id: "libreoffice", name: "LibreOffice",
                    documents: "org.libreoffice.script", spreadsheets: "org.libreoffice.script", presentations: "org.libreoffice.script"),
    ]

    /// The suite's apps keyed by category ID, or nil unless every member app is installed.
    public func resolve(using locator: any AppLocating) -> ResolvedSuite? {
        var apps: [String: AppInfo] = [:]
        for member in members {
            guard let app = locator.app(bundleID: member.bundleID) else { return nil }
            apps[member.categoryID] = app
        }
        return ResolvedSuite(suite: self, appsByCategory: apps)
    }

    private static func officeSuite(id: String, name: String, documents: String, spreadsheets: String, presentations: String) -> AppSuite {
        AppSuite(id: id, name: name, members: [
            Member(categoryID: "documents", bundleID: documents),
            Member(categoryID: "spreadsheets", bundleID: spreadsheets),
            Member(categoryID: "presentations", bundleID: presentations),
        ])
    }
}

/// An installed suite.
public struct ResolvedSuite: Identifiable, Sendable {
    public let suite: AppSuite
    public let appsByCategory: [String: AppInfo]

    public var id: String { suite.id }

    /// Member apps in suite order, without duplicates.
    public var apps: [AppInfo] {
        var seen = Set<String>()
        return suite.members.compactMap { appsByCategory[$0.categoryID] }.filter { seen.insert($0.bundleID).inserted }
    }

    public func app(for format: FileFormat) -> AppInfo? {
        appsByCategory[format.categoryID]
    }
}
