import XCTest
@testable import TidyMacCore

final class FileRuleAndEngineTests: XCTestCase {
    private func candidate(_ name: String) -> FileCandidate {
        FileCandidate(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            filename: name,
            pathExtension: URL(fileURLWithPath: name).pathExtension,
            isReadable: true,
            isWritable: true
        )
    }

    func testDisabledRuleNeverMatches() {
        var rule = FileRule(
            name: "PDFs",
            isEnabled: false,
            conditions: [MatchCondition(kind: .fileExtension, value: "pdf")],
            destinationSubpath: "Documents/PDFs"
        )
        XCTAssertFalse(rule.matches(candidate("report.pdf")))
        rule.isEnabled = true
        XCTAssertTrue(rule.matches(candidate("report.pdf")))
    }

    func testRuleWithNoConditionsNeverMatches() {
        let rule = FileRule(name: "Empty", conditions: [], destinationSubpath: "Nowhere")
        XCTAssertFalse(rule.matches(candidate("anything.pdf")))
    }

    func testConditionLogicAnyMatchesIfAnyConditionMatches() {
        let rule = FileRule(
            name: "Media",
            conditions: [
                MatchCondition(kind: .fileExtension, value: "mp3"),
                MatchCondition(kind: .fileExtension, value: "mp4")
            ],
            conditionLogic: .any,
            destinationSubpath: "Media"
        )
        XCTAssertTrue(rule.matches(candidate("song.mp3")))
        XCTAssertTrue(rule.matches(candidate("clip.mp4")))
        XCTAssertFalse(rule.matches(candidate("doc.pdf")))
    }

    func testConditionLogicAllRequiresEveryCondition() {
        let rule = FileRule(
            name: "InvoicePDFs",
            conditions: [
                MatchCondition(kind: .fileExtension, value: "pdf"),
                MatchCondition(kind: .filenameContains, value: "invoice")
            ],
            conditionLogic: .all,
            destinationSubpath: "Documents/Invoices"
        )
        XCTAssertTrue(rule.matches(candidate("Invoice-2024.pdf")))
        XCTAssertFalse(rule.matches(candidate("Invoice-2024.txt")))
        XCTAssertFalse(rule.matches(candidate("report.pdf")))
    }

    // MARK: - Ambiguous files matching multiple rules

    func testFirstMatchingRuleWinsWhenFileQualifiesForMultipleRules() {
        // A screenshot is a PNG, so it qualifies for both "Screenshots" and "Images."
        // Whichever rule is listed first must win.
        let screenshots = FileRule(
            name: "Screenshots",
            conditions: [MatchCondition(kind: .filenameRegex, value: "^Screen ?Shot .*")],
            destinationSubpath: "Screenshots"
        )
        let images = FileRule(
            name: "Images",
            conditions: [MatchCondition(kind: .fileExtension, value: "png")],
            destinationSubpath: "Pictures"
        )
        let engine = RuleEngine()
        let file = candidate("Screenshot 2024-01-01 at 3.14.15 PM.png")

        XCTAssertEqual(engine.firstMatchingRule(for: file, in: [screenshots, images])?.name, "Screenshots")
        XCTAssertEqual(engine.firstMatchingRule(for: file, in: [images, screenshots])?.name, "Images")
    }

    func testDisabledEarlierRuleFallsThroughToLaterMatch() {
        var screenshots = FileRule(
            name: "Screenshots",
            conditions: [MatchCondition(kind: .filenameRegex, value: "^Screen ?Shot .*")],
            destinationSubpath: "Screenshots"
        )
        screenshots.isEnabled = false
        let images = FileRule(
            name: "Images",
            conditions: [MatchCondition(kind: .fileExtension, value: "png")],
            destinationSubpath: "Pictures"
        )
        let engine = RuleEngine()
        let file = candidate("Screenshot 2024-01-01 at 3.14.15 PM.png")
        XCTAssertEqual(engine.firstMatchingRule(for: file, in: [screenshots, images])?.name, "Images")
    }

    func testNoMatchReturnsNil() {
        let engine = RuleEngine()
        let rules = DefaultRules.all
        XCTAssertNil(engine.firstMatchingRule(for: candidate("README"), in: rules))
        XCTAssertNil(engine.firstMatchingRule(for: candidate("Makefile"), in: rules))
    }

    // MARK: - Default rule set sanity checks

    func testDefaultRulesPlaceScreenshotsBeforeImages() {
        let names = DefaultRules.all.map(\.name)
        guard let screenshotsIndex = names.firstIndex(of: "Screenshots"),
              let imagesIndex = names.firstIndex(of: "Images") else {
            return XCTFail("Expected both Screenshots and Images in default rule set")
        }
        XCTAssertLessThan(screenshotsIndex, imagesIndex)
    }

    func testDefaultRulesRouteCommonFileTypes() {
        let engine = RuleEngine()
        let rules = DefaultRules.all

        XCTAssertEqual(engine.firstMatchingRule(for: candidate("Screenshot 2024-01-01 at 3.14.15 PM.png"), in: rules)?.destinationSubpath, "Screenshots")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("taxes.pdf"), in: rules)?.destinationSubpath, "Documents/PDFs")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("Xcode.dmg"), in: rules)?.destinationSubpath, "Downloads/Installers")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("vacation.jpg"), in: rules)?.destinationSubpath, "Pictures")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("notes.txt"), in: rules)?.destinationSubpath, "Documents")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("archive.zip"), in: rules)?.destinationSubpath, "Archives")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("song.mp3"), in: rules)?.destinationSubpath, "Audio")
        XCTAssertEqual(engine.firstMatchingRule(for: candidate("movie.mp4"), in: rules)?.destinationSubpath, "Videos")
    }
}
