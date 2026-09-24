import Foundation
import Testing
@testable import DefaultlyCore

struct DeclaredFormatsTests {
    @Test func readsBundleTypeExtensionsIgnoringWildcards() {
        let plist: [String: Any] = [
            "CFBundleDocumentTypes": [["CFBundleTypeExtensions": ["MD", "markdown", "*"]]],
        ]
        #expect(DeclaredFormats.extensions(in: plist) == [.ext("md"), .ext("markdown")])
    }

    @Test func resolvesContentTypesDeclaredByTheAppItself() {
        let plist: [String: Any] = [
            "CFBundleDocumentTypes": [["LSItemContentTypes": ["com.example.widget"]]],
            "UTExportedTypeDeclarations": [[
                "UTTypeIdentifier": "com.example.widget",
                "UTTypeTagSpecification": ["public.filename-extension": ["widget", "wdg"]],
            ]],
            "UTImportedTypeDeclarations": [[
                "UTTypeIdentifier": "com.example.gadget",
                "UTTypeTagSpecification": ["public.filename-extension": "gadget"],
            ]],
        ]
        #expect(DeclaredFormats.extensions(in: plist) == [.ext("widget"), .ext("wdg")])
    }

    @Test func resolvesSystemContentTypes() {
        let plist: [String: Any] = ["CFBundleDocumentTypes": [["LSItemContentTypes": ["public.plain-text"]]]]
        #expect(DeclaredFormats.extensions(in: plist).contains(.ext("txt")))
    }

    @Test func returnsNothingWithoutDocumentTypes() {
        #expect(DeclaredFormats.extensions(in: [:]).isEmpty)
    }
}
