import Foundation
import Testing
@testable import DefaultlyCore

struct FileExtensionTests {
    @Test(arguments: [
        ("docx", "docx"), (".DOCX", "docx"), ("*.docx", "docx"), ("  Md \n", "md"), ("c++", "c++"), ("7z", "7z"),
    ])
    func normalizesUserInput(input: String, expected: String) {
        #expect(FileExtension(input)?.rawValue == expected)
    }

    @Test(arguments: ["", ".", "*.", "tar.gz", "a b", "bad/one", "ệ", String(repeating: "x", count: 33)])
    func rejectsInvalidInput(input: String) {
        #expect(FileExtension(input) == nil)
    }

    @Test func describesWithLeadingDot() {
        #expect(FileExtension.ext("docx").description == ".docx")
    }

    @Test func parsesListsKeepingOrderAndDroppingDuplicates() {
        let parsed = FileExtension.parseList("kt, kts;gradle  .KT *.foo bad/one\nyml")
        #expect(parsed.valid.map(\.rawValue) == ["kt", "kts", "gradle", "foo", "yml"])
        #expect(parsed.invalid == ["bad/one"])
    }

    @Test func encodesAsPlainString() throws {
        let data = try JSONEncoder().encode([FileExtension.ext("pdf")])
        #expect(String(decoding: data, as: UTF8.self) == #"["pdf"]"#)
        let decoded = try JSONDecoder().decode([FileExtension].self, from: data)
        #expect(decoded == [.ext("pdf")])
    }

    @Test func rejectsInvalidStringWhenDecoding() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([FileExtension].self, from: Data(#"["a b"]"#.utf8))
        }
    }

    @Test func knownExtensionsResolveEveryContentType() {
        let identifiers = FileExtension.ext("docx").contentTypes.map(\.identifier)
        #expect(identifiers.first == "org.openxmlformats.wordprocessingml.document")
        #expect(Set(identifiers).count == identifiers.count)
    }
}
