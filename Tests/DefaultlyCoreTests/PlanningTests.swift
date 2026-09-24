import Foundation
import Testing
@testable import DefaultlyCore

struct PlanBuilderTests {
    let formats: [FileFormat] = [.fake("docx"), .fake("doc"), .fake("pages")]
    let statuses: [FileExtension: FormatStatus] = [
        .ext("docx"): FormatStatus(current: .word, candidates: [.word, .libre]),
        .ext("doc"): FormatStatus(current: .libre, candidates: [.word, .libre]),
        .ext("pages"): FormatStatus(current: nil, candidates: []),
    ]

    @Test func skipsNoOpsAndExcludesUnsupportedByDefault() {
        let items = PlanBuilder.items(for: formats, assigning: .libre, statuses: statuses)
        #expect(items.map(\.id) == [.ext("docx"), .ext("pages")])
        #expect(items.map(\.isIncluded) == [true, false])
        #expect(items.map(\.isSupported) == [true, false])
        #expect(items.first?.current == .word)
    }

    @Test func inclusionPolicyDecidesWhatStartsChecked() {
        #expect(PlanBuilder.items(for: formats, assigning: .libre, statuses: statuses, including: .all).map(\.isIncluded) == [true, true])
        #expect(PlanBuilder.items(for: formats, assigning: .libre, statuses: statuses, including: .none).map(\.isIncluded) == [false, false])
    }

    @Test func recomputedPlansKeepTheUsersChoices() {
        var previous = PlanBuilder.items(for: formats, assigning: .libre, statuses: statuses)
        previous[0].isIncluded = false
        previous[1].isIncluded = true
        let refreshed = PlanBuilder.items(for: [.fake("docx"), .fake("pages"), .fake("odt")], assigning: .libre, statuses: statuses)
        let kept = PlanBuilder.keepingChoices(of: previous, in: refreshed)
        #expect(kept.map(\.id) == [.ext("docx"), .ext("pages"), .ext("odt")])
        #expect(kept.map(\.isIncluded) == [false, true, false])
    }

    @Test func skipsFormatsWithoutATarget() {
        let items = PlanBuilder.items(for: formats, statuses: statuses) { $0.ext.rawValue == "doc" ? .word : nil }
        #expect(items.map(\.assignment) == [Assignment(ext: .ext("doc"), app: .word)])
    }
}

struct AppRankingTests {
    let formats: [FileFormat] = [.fake("docx"), .fake("doc"), .fake("odt")]
    let statuses: [FileExtension: FormatStatus] = [
        .ext("docx"): FormatStatus(current: .word, candidates: [.word, .libre]),
        .ext("doc"): FormatStatus(current: .word, candidates: [.word, .libre, .code]),
        .ext("odt"): FormatStatus(current: .libre, candidates: [.libre]),
    ]

    @Test func ranksSupportingAppsByCoverageThenName() {
        let ranked = AppRanking.supporting(formats, statuses: statuses)
        #expect(ranked.map(\.app) == [.libre, .word, .code])
        #expect(ranked.map(\.count) == [3, 2, 1])
    }

    @Test func ranksCurrentDefaults() {
        let ranked = AppRanking.defaults(for: formats, statuses: statuses)
        #expect(ranked.first == AppCount(app: .word, count: 2))
    }
}

struct AppSuiteTests {
    @Test func resolvesOnlyWhenEveryAppIsInstalled() {
        let office = AppSuite.all.first { $0.id == "microsoft-office" }!
        #expect(office.resolve(using: FakeAppLocator(apps: [.word])) == nil)

        let excel = AppInfo.fake("com.microsoft.Excel", "Microsoft Excel")
        let powerPoint = AppInfo.fake("com.microsoft.Powerpoint", "Microsoft PowerPoint")
        let resolved = office.resolve(using: FakeAppLocator(apps: [.word, excel, powerPoint]))
        #expect(resolved?.apps == [.word, excel, powerPoint])
        #expect(resolved?.app(for: .fake("xlsx", category: "spreadsheets")) == excel)
        #expect(resolved?.app(for: .fake("png", category: "images")) == nil)
    }

    @Test func singleAppSuitesListTheAppOnce() {
        let libreOffice = AppSuite.all.first { $0.id == "libreoffice" }!
        #expect(libreOffice.resolve(using: FakeAppLocator(apps: [.libre]))?.apps == [.libre])
    }
}
