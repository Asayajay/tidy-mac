import XCTest
@testable import TidyMacCore

final class MatchConditionTests: XCTestCase {
    private func candidate(_ name: String) -> FileCandidate {
        FileCandidate(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            filename: name,
            pathExtension: URL(fileURLWithPath: name).pathExtension,
            isReadable: true,
            isWritable: true
        )
    }

    func testFileExtensionMatchIsCaseInsensitive() {
        let condition = MatchCondition(kind: .fileExtension, value: "pdf")
        XCTAssertTrue(condition.matches(candidate("report.PDF")))
        XCTAssertTrue(condition.matches(candidate("report.pdf")))
        XCTAssertFalse(condition.matches(candidate("report.txt")))
    }

    func testFileExtensionIgnoresLeadingDotInValue() {
        let condition = MatchCondition(kind: .fileExtension, value: ".pdf")
        XCTAssertTrue(condition.matches(candidate("report.pdf")))
    }

    func testNoExtensionNeverMatchesExtensionCondition() {
        let condition = MatchCondition(kind: .fileExtension, value: "pdf")
        XCTAssertFalse(condition.matches(candidate("README")))
    }

    func testEmptyExtensionValueDoesNotMatchExtensionlessFile() {
        // A rule someone accidentally configured with an empty extension value
        // must not silently swallow every extensionless file.
        let condition = MatchCondition(kind: .fileExtension, value: "")
        XCTAssertFalse(condition.matches(candidate("README")))
    }

    func testFilenameContainsIsCaseInsensitive() {
        let condition = MatchCondition(kind: .filenameContains, value: "invoice")
        XCTAssertTrue(condition.matches(candidate("Invoice-2024.pdf")))
        XCTAssertFalse(condition.matches(candidate("report.pdf")))
    }

    func testFilenamePrefixOnlyMatchesStart() {
        let condition = MatchCondition(kind: .filenamePrefix, value: "IMG_")
        XCTAssertTrue(condition.matches(candidate("IMG_1234.jpg")))
        XCTAssertFalse(condition.matches(candidate("edited_IMG_1234.jpg")))
    }

    func testFilenameRegexMatchesScreenshotConvention() {
        let condition = MatchCondition(kind: .filenameRegex, value: "^Screen ?Shot .*")
        XCTAssertTrue(condition.matches(candidate("Screenshot 2024-01-01 at 3.14.15 PM.png")))
        XCTAssertTrue(condition.matches(candidate("Screen Shot 2020-05-01 at 9.00.00 AM.png")))
        XCTAssertFalse(condition.matches(candidate("vacation-screenshot.png")))
    }

    func testInvalidRegexPatternFailsClosedNotOpen() {
        // An unparsable regex (e.g. a user typo in a custom rule) must never match
        // everything -- it should match nothing rather than accidentally sweep up files.
        let condition = MatchCondition(kind: .filenameRegex, value: "[unterminated(")
        XCTAssertFalse(condition.matches(candidate("anything.txt")))
    }

    func testEmptyContainsAndPrefixValuesDoNotMatchEverything() {
        XCTAssertFalse(MatchCondition(kind: .filenameContains, value: "").matches(candidate("x.txt")))
        XCTAssertFalse(MatchCondition(kind: .filenamePrefix, value: "").matches(candidate("x.txt")))
    }
}
