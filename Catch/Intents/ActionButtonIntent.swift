import AppIntents

/// 11g: put this on the Action button. Catch listens in the Dynamic Island
/// without opening, and saves when you stop talking. It's an App Shortcut, which
/// can't be iOS 18 only, so recording in the background is added below for iOS 18.
struct ListenInBackgroundIntent: AppIntent {
    static let title: LocalizedStringResource = "Catch by Voice in the Background"
    static let description = IntentDescription(
        "Listens in the Dynamic Island and saves what you say, to Later if it hears a time.")

    @MainActor
    func perform() async throws -> some IntentResult {
        guard #available(iOS 18.0, *) else { throw ListenError(.unavailable) }
        do {
            try await AppServices.shared.voiceActivity.start()
        } catch let failure as VoiceActivityController.StartFailure {
            // Say why instead of silently doing nothing.
            throw ListenError(failure)
        }
        return .result()
    }
}

@available(iOS 18.0, *)
extension ListenInBackgroundIntent: AudioRecordingIntent {}

struct ListenError: Error, CustomLocalizedStringResourceConvertible {
    let failure: VoiceActivityController.StartFailure

    init(_ failure: VoiceActivityController.StartFailure) {
        self.failure = failure
    }

    var localizedStringResource: LocalizedStringResource {
        switch failure {
        case .busy:
            return "Catch is already listening."
        case .liveActivitiesOff:
            return "Turn on Live Activities for Catch in Settings to listen in the background."
        case .needsPermission:
            return "Open Catch and hold + once to allow the microphone, then try again."
        case .unavailable:
            return "Listening isn't available right now."
        }
    }
}
