import AppIntents

/// 11g: put this on the Action button. Catch listens in the Dynamic Island
/// without opening, and saves when you stop talking.
@available(iOS 18.0, *)
struct ListenInBackgroundIntent: AudioRecordingIntent {
    static let title: LocalizedStringResource = "Catch by Voice in the Background"
    static let description = IntentDescription(
        "Listens in the Dynamic Island and saves what you say, to Later if it hears a time.")

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppServices.shared.voiceActivity.start()
        return .result()
    }
}
