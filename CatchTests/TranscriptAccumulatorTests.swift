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

    func testAShortPhraseBeforeAPauseIsKept() {
        var heard = TranscriptAccumulator()
        heard.add("Buy milk")
        heard.add("tomorrow")
        heard.add("tomorrow at 10")
        XCTAssertEqual(heard.text, "Buy milk tomorrow at 10")
    }

    func testAMarkedPauseStartsANewStretch() {
        var heard = TranscriptAccumulator()
        heard.add("Milk", endsStretch: true)
        heard.add("and")
        heard.add("and eggs")
        XCTAssertEqual(heard.text, "Milk and eggs")
    }

    func testAMarkedPauseKeepsAStretchStartingTheSameWay() {
        var heard = TranscriptAccumulator()
        heard.add("I need milk", endsStretch: true)
        heard.add("I")
        heard.add("I need eggs")
        XCTAssertEqual(heard.text, "I need milk I need eggs")
    }

    func testAResultRepeatingTheMarkedStretchIsNotDoubled() {
        var heard = TranscriptAccumulator()
        heard.add("Buy milk", endsStretch: true)
        heard.add("Buy milk tomorrow at 10.")
        XCTAssertEqual(heard.text, "Buy milk tomorrow at 10.")
    }

    func testAnEmptyMarkedResultStillEndsTheStretch() {
        var heard = TranscriptAccumulator()
        heard.add("Milk")
        heard.add("", endsStretch: true)
        heard.add("and eggs")
        XCTAssertEqual(heard.text, "Milk and eggs")
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
