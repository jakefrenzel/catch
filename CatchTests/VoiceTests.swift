import XCTest
@testable import Catch

/// NSDataDetector always reads relative dates ("tomorrow") against the real
/// clock, so these tests use the real date too.
final class VoiceParserTests: XCTestCase {
    private let calendar = Calendar.current
    private let kitchenReno = VoiceParser.ProjectName(id: UUID(), name: "Kitchen Reno")

    private func parse(_ text: String, projects: [VoiceParser.ProjectName] = []) -> VoiceParse {
        VoiceParser.parse(text, projects: projects, afterWork: TimeOfDay(hour: 17, minute: 30),
                          now: .now, calendar: calendar)
    }

    func testAfterWorkIsAWholePhrase() throws {
        let result = parse("Book the after workout massage")
        XCTAssertNil(result.date)
        XCTAssertEqual(result.title, "Book the after workout massage")
    }

    func testTimeGoesToLater() throws {
        let result = parse("Remind me to call Dana tomorrow at 10 about the lease")

        XCTAssertEqual(result.title, "Call Dana about the lease")
        XCTAssertEqual(result.chunks.map(\.kind), [.filler, .normal, .time, .normal])
        XCTAssertEqual(result.chunks.map(\.text), ["Remind me to", "call Dana", "tomorrow at 10", "about the lease"])

        let date = try XCTUnwrap(result.date)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: .now))
        XCTAssertTrue(calendar.isDate(date, inSameDayAs: tomorrow))
        XCTAssertEqual(calendar.component(.hour, from: date), 10)
        XCTAssertEqual(result.destination, .later(date))
    }

    func testProjectOnlyAddsAStep() {
        let result = parse("Add get a tile quote to the kitchen reno", projects: [kitchenReno])

        XCTAssertEqual(result.title, "Get a tile quote")
        XCTAssertEqual(result.chunks.map(\.kind), [.filler, .normal, .filler, .project])
        XCTAssertEqual(result.chunks.last?.text, "the kitchen reno")
        XCTAssertEqual(result.projectName, "Kitchen Reno")
        XCTAssertEqual(result.destination, .projectStep(kitchenReno.id))
    }

    func testNeitherGoesToInbox() {
        let result = parse("Look into a standing desk for the office", projects: [kitchenReno])
        XCTAssertEqual(result.title, "Look into a standing desk for the office")
        XCTAssertEqual(result.chunks.map(\.kind), [.normal])
        XCTAssertEqual(result.destination, .inbox)
    }

    func testProjectNamesMatchLoosely() {
        let result = parse("Order samples for the kitchen renno", projects: [kitchenReno])
        XCTAssertEqual(result.projectName, "Kitchen Reno")
        XCTAssertEqual(result.title, "Order samples")
    }

    func testShortWordsMustMatchExactly() {
        let trip = VoiceParser.ProjectName(id: UUID(), name: "Trip")
        XCTAssertNil(parse("Buy a tip jar", projects: [trip]).projectName)
    }

    func testAfterWorkUsesTheSetting() throws {
        let result = parse("Pick up dry cleaning after work.")
        XCTAssertEqual(result.title, "Pick up dry cleaning")
        let expected = TimeOfDay(hour: 17, minute: 30).next(after: .now, calendar: calendar)
        let date = try XCTUnwrap(result.date)
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 5)
    }

    func testCapitalizesAndDropsTrailingPunctuation() {
        XCTAssertEqual(parse("buy milk.").title, "Buy milk")
    }

    func testLeadInAloneLeavesNoTitle() {
        XCTAssertEqual(parse("Remind me to").title, "Remind me to",
                       "A lead-in only counts when something follows it")
        XCTAssertEqual(parse("").title, "")
    }

    func testEditDistance() {
        XCTAssertEqual(VoiceParser.editDistance("reno", "renno"), 1)
        XCTAssertEqual(VoiceParser.editDistance("kitchen", "kitchen"), 0)
        XCTAssertTrue(VoiceParser.isClose("renno", "reno"))
        XCTAssertFalse(VoiceParser.isClose("tip", "trip"))
    }
}

@MainActor
final class FakeVoice: VoiceInput {
    var transcript = ""
    var levels: [Float] = []
    var currentPermission: VoicePermission = .allowed
    var result = VoiceResult(transcript: "", isUncertain: false)
    var started = false
    var cancelled = false

    func permission() -> VoicePermission { currentPermission }
    func requestPermission() async -> Bool { true }
    func start(language: String?) throws { started = true }
    func stop() async -> VoiceResult { result }
    func cancel() { cancelled = true }
}

@MainActor
final class VoiceFlowTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment, FakeVoice) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        let voice = FakeVoice()
        let model = AppModel(store: env.store, settingsStore: env.settingsStore,
                             notifications: FakeNotifications(), voice: voice)
        return (model, env, voice)
    }

    func testDeniedMicShowsTheMicSheet() throws {
        let (model, _, voice) = try makeModel()
        voice.currentPermission = .denied

        model.startListening()

        XCTAssertFalse(model.isListening)
        guard case .micDenied? = model.sheet else { return XCTFail("Expected 10a") }
    }

    func testHoldStartsListening() throws {
        let (model, _, voice) = try makeModel()
        model.startListening()
        XCTAssertTrue(model.isListening)
        XCTAssertTrue(voice.started)
        XCTAssertFalse(model.showsPinnedUpFirst)
    }

    func testReleaseSavesToLaterWhenATimeWasHeard() async throws {
        let (model, env, voice) = try makeModel()
        voice.result = VoiceResult(transcript: "Remind me to call Dana tomorrow at 10", isUncertain: false)
        model.startListening()

        await model.stopListening(save: true)

        XCTAssertFalse(model.isListening)
        let item = try XCTUnwrap(env.store.items(in: .later).first)
        XCTAssertEqual(item.text, "Call Dana")
        XCTAssertEqual(Calendar.current.component(.hour, from: try XCTUnwrap(item.remindAt)), 10)
    }

    func testDraggingAwayCancels() async throws {
        let (model, env, voice) = try makeModel()
        voice.result = VoiceResult(transcript: "Buy milk", isUncertain: false)
        model.startListening()

        await model.stopListening(save: false)

        XCTAssertTrue(voice.cancelled)
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    func testUncertainResultAsksBeforeSaving() async throws {
        let (model, env, voice) = try makeModel()
        voice.result = VoiceResult(transcript: "Send the slides to", isUncertain: true)
        model.startListening()

        await model.stopListening(save: true)

        guard case .voiceRetry(let heard)? = model.sheet else { return XCTFail("Expected 10b") }
        XCTAssertEqual(heard, "Send the slides to")
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    func testSilenceSavesNothing() async throws {
        let (model, env, _) = try makeModel()
        model.startListening()
        await model.stopListening(save: true)
        XCTAssertEqual(model.toast?.message, "Didn't hear anything. Hold + and talk.")
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    func testSpokenProjectStep() throws {
        let (model, env, _) = try makeModel()
        let project = env.addProject("Kitchen Reno", steps: [("Measure", "Plan")])

        model.saveSpoken("Add get a tile quote to the kitchen reno")

        XCTAssertEqual(project.orderedSteps.map(\.text), ["Measure", "Get a tile quote"])
        XCTAssertEqual(model.toast?.message, "Added to Kitchen Reno")
    }

    func testFixedRetrySavesAndCloses() throws {
        let (model, env, _) = try makeModel()
        model.sheet = .voiceRetry("Send the slides to")

        model.saveSpoken("Send the slides to Priya")

        XCTAssertNil(model.sheet)
        XCTAssertEqual(env.store.items(in: .inbox).map(\.text), ["Send the slides to Priya"])
    }
}
