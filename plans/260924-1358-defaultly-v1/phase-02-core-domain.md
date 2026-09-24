# Phase 2 — Core domain & services (`Sources/DefaultlyCore`)

## Requirements
- No SwiftUI import. Every public type is `Sendable`.
- Ports: `LaunchServicesClient`, `AppLocating`. System implementations: `SystemLaunchServices`, `SystemAppLocator`.

## Files to create
| File | Responsibility |
|------|----------------|
| `Models/FileExtension.swift` | Normalize/validate extensions (`*.DOCX` → `docx`), parse lists |
| `Models/FileFormat.swift` | `FileFormat`, `FileCategory`, `CategoryTint`, `CustomFormat` |
| `Models/AppInfo.swift` | App identity (bundle ID, name, URL) |
| `Models/FormatStatus.swift` | Current app + candidate apps for an extension |
| `Models/Assignment.swift` | `Assignment`, `AssignmentOutcome`, `ApplyReport` (inverse for undo) |
| `Catalog/FileTypeCatalog.swift` | 17 categories, ≥ 350 formats |
| `Catalog/AppSuite.swift` | Multi-app suites per category (Microsoft Office, iWork, LibreOffice) |
| `Catalog/FormatLibrary.swift` | Merge catalog + custom, lookup, search |
| `Services/LaunchServicesClient.swift` | Port + implementation: instant (LaunchServices) and interactive (NSWorkspace) writes for every matching UTI |
| `Services/AppLocator.swift` | Port + implementation: installed apps, resolve bundle ID / URL |
| `Services/DeclaredFormats.swift` | Extensions an app declares in its `Info.plist` |
| `Services/AssociationService.swift` | Use cases: read statuses, two-phase apply + verify |
| `Services/PlanBuilder.swift` | Pending `PlanItem`s; drop no-ops; flag unsupported formats |
| `Services/AppRanking.swift` | Rank suggested apps by coverage; find the dominant current app |
| `Services/AssociationBackup.swift` | Codable JSON + backup → assignments |

## Tests (`Tests/DefaultlyCoreTests`)
- FileExtension normalization, invalid input, list parsing.
- Catalog: unique IDs, no duplicate extension across categories, no empty category, Vietnamese translation for every name.
- FormatLibrary merge/dedupe/search.
- DeclaredFormats parsing of sample plists.
- AssociationService with fakes: instant apply, interactive fallback, notAccepted, failed; previous app captured.
- ApplyReport inverse, PlanBuilder, AppRanking, backup round-trip.
- Opt-in integration (`DEFAULTLY_INTEGRATION=1`): made-up extension → TextEdit.

## Validation
`swift test` green.
