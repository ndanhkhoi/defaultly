import Foundation
import UniformTypeIdentifiers

/// Reads the file extensions an app says it can open, from its `Info.plist`.
public enum DeclaredFormats {
    public static func extensions(ofAppAt url: URL) -> Set<FileExtension> {
        Bundle(url: url)?.infoDictionary.map(extensions(in:)) ?? []
    }

    /// Combines `CFBundleTypeExtensions` with the extensions of every `LSItemContentTypes` entry,
    /// using the app's own type declarations first and the system's knowledge second.
    public static func extensions(in infoPlist: [String: Any]) -> Set<FileExtension> {
        let documentTypes = infoPlist["CFBundleDocumentTypes"] as? [[String: Any]] ?? []
        let declaredTypes = typeDeclarations(in: infoPlist)
        var result = Set<FileExtension>()

        for documentType in documentTypes {
            for raw in documentType["CFBundleTypeExtensions"] as? [String] ?? [] where raw != "*" {
                if let ext = FileExtension(raw) { result.insert(ext) }
            }
            for identifier in documentType["LSItemContentTypes"] as? [String] ?? [] {
                let tags = declaredTypes[identifier] ?? UTType(identifier)?.tags[.filenameExtension] ?? []
                result.formUnion(tags.compactMap(FileExtension.init))
            }
        }
        return result
    }

    /// Identifier → extensions from `UTExportedTypeDeclarations` and `UTImportedTypeDeclarations`.
    private static func typeDeclarations(in infoPlist: [String: Any]) -> [String: [String]] {
        let declarations = ["UTExportedTypeDeclarations", "UTImportedTypeDeclarations"]
            .flatMap { infoPlist[$0] as? [[String: Any]] ?? [] }
        var result: [String: [String]] = [:]
        for declaration in declarations {
            guard let identifier = declaration["UTTypeIdentifier"] as? String,
                  let tags = declaration["UTTypeTagSpecification"] as? [String: Any]
            else { continue }
            let extensions = tags["public.filename-extension"]
            result[identifier, default: []] += (extensions as? [String]) ?? (extensions as? String).map { [$0] } ?? []
        }
        return result
    }
}
