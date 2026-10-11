import XCTest
@testable import Catch

@MainActor
final class OnboardingTests: XCTestCase {
    private func makeModel() throws -> (AppModel, TestEnvironment, FakeVoice, FakeNotifications) {
        let env = try TestEnvironment()
        env.settingsStore.settings.haptics = false
        let voice = FakeVoice()
        let notifications = FakeNotifications()
        let model = AppModel(store: env.store, settingsStore: env.settingsStore,
                             notifications: notifications, voice: voice)
        return (model, env, voice, notifications)
    }

    func testFreshInstallShowsWelcome() throws {
        let (model, _, _, _) = try makeModel()
        model.startOnboardingIfNeeded()
        XCTAssertEqual(model.onboarding, .welcome)
    }

    func testExistingDataSkipsIt() throws {
        let (model, env, _, _) = try makeModel()
        env.add("Already here", to: .inbox)

        model.startOnboardingIfNeeded()

        XCTAssertNil(model.onboarding)
        XCTAssertTrue(env.settingsStore.hasOnboarded)
    }

    func testOnlyOnce() throws {
        let (model, env, _, _) = try makeModel()
        env.settingsStore.hasOnboarded = true
        model.startOnboardingIfNeeded()
        XCTAssertNil(model.onboarding)
    }

    func testHoldStepTapExplains() throws {
        let (model, _, _, _) = try makeModel()
        model.beginOnboarding()
        model.tapCaptureDuringOnboarding()
        XCTAssertEqual(model.onboarding, .hold)
        XCTAssertEqual(model.toast?.message, "Hold it down to talk")
        XCTAssertFalse(model.showsPinnedUpFirst)
    }

    func testSayingATimeSavesAndAsksAboutReminders() async throws {
        let (model, env, voice, _) = try makeModel()
        model.beginOnboarding()
        voice.result = VoiceResult(transcript: "Remind me to call Dana tomorrow at 10 about the lease", isUncertain: false)

        model.startListening()
        XCTAssertEqual(model.onboarding, .talk)
        await model.stopListening(save: true)

        XCTAssertEqual(model.onboarding, .permission)
        XCTAssertEqual(env.store.items(in: .later).map(\.text), ["Call Dana about the lease"])
        guard case .onboardingPermission? = model.sheet else { return XCTFail("Expected step 3") }
    }

    func testLettingGoWithoutATimeGoesBackToStepOne() async throws {
        let (model, env, voice, _) = try makeModel()
        model.beginOnboarding()
        voice.result = VoiceResult(transcript: "Call Dana", isUncertain: false)

        model.startListening()
        await model.stopListening(save: true)

        XCTAssertEqual(model.onboarding, .hold)
        XCTAssertEqual(model.toast?.message, "Keep holding until you’ve said the time")
        XCTAssertTrue(env.store.allItems().isEmpty)
    }

    func testTurnOnReminders() async throws {
        let (model, env, _, notifications) = try makeModel()
        notifications.currentPermission = .notDetermined
        model.onboarding = .permission

        await model.finishOnboarding(allowReminders: true)

        XCTAssertNil(model.onboarding)
        XCTAssertTrue(env.settingsStore.hasOnboarded)
        XCTAssertEqual(notifications.requestCount, 1)
        XCTAssertTrue(env.settingsStore.settings.notifications)
    }

    func testNotNowTurnsRemindersOff() async throws {
        let (model, env, _, notifications) = try makeModel()
        model.onboarding = .permission

        await model.finishOnboarding(allowReminders: false)

        XCTAssertEqual(notifications.requestCount, 0)
        XCTAssertFalse(env.settingsStore.settings.notifications)
        XCTAssertTrue(env.settingsStore.hasOnboarded)
    }

    func testSkip() throws {
        let (model, env, _, _) = try makeModel()
        model.beginOnboarding()
        model.skipOnboarding()
        XCTAssertNil(model.onboarding)
        XCTAssertTrue(env.settingsStore.hasOnboarded)
    }

    func testPermissionLabel() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12)))
        let tomorrowTen = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 10)))
        XCTAssertEqual(OnboardingPermissionSheet.label(for: tomorrowTen, now: now, calendar: calendar), "tomorrow at 10")
    }
}
