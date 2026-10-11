import XCTest
@testable import Catch

final class TranscriptAccumulatorTests: XCTestCase {
    func testRevisionsReplaceTheCurrentText() {
        var heard = TranscriptAccumulator()
        heard.add("Remind me")
        heard.add("Remind me to call")
        heard.add("Remind me to call Bob tomorrow at 10")
        XCTAssertEqual(heard.text, "Remind me to call Bob tomorrow at 10")
    }

    func testAnEmptyResultKeepsWhatWasHeard() {
        var heard = TranscriptAccumulator()
        heard.add("Remind me to call Bob tomorrow at 10")
        heard.add("")
        heard.add("  ")
        XCTAssertEqual(heard.text, "Remind me to call Bob tomorrow at 10")
    }

    func testStartingOverAfterAPauseKeepsTheEarlierPart() {
        var heard = TranscriptAccumulator()
        heard.add("Remind me to call Bob")
        heard.add("tomorrow")
        heard.add("tomorrow at 10")
        XCTAssertEqual(heard.text, "Remind me to call Bob tomorrow at 10")
    }

    func testAFinalResultWithEverythingIsNotDoubled() {
        var heard = TranscriptAccumulator()
        heard.add("Remind me to call Bob")
        heard.add("tomorrow at 10")
        heard.add("Remind me to call Bob tomorrow at 10.")
        XCTAssertEqual(heard.text, "Remind me to call Bob tomorrow at 10.")
    }

    func testEarlyFirstWordFixesAreRevisions() {
        var heard = TranscriptAccumulator()
        heard.add("Paul")
        heard.add("Call Bob")
        XCTAssertEqual(heard.text, "Call Bob")
    }

    func testPunctuationAndCaseChangesAreRevisions() {
        var heard = TranscriptAccumulator()
        heard.add("remind me to call bob")
        heard.add("Remind me to call Bob.")
        XCTAssertEqual(heard.text, "Remind me to call Bob.")
    }
}
