import AVFoundation
import Foundation
import Observation
import Speech

enum VoicePermission {
    case notDetermined, denied, allowed
}

/// What came back when listening stopped.
struct VoiceResult: Equatable {
    var transcript: String
    /// The recognizer wasn't sure, or stopped with an error part-way.
    var isUncertain: Bool
}

/// Listening, behind a protocol so tests and screenshots can use a fake.
@MainActor
protocol VoiceInput: AnyObject {
    /// The live transcript while listening.
    var transcript: String { get }
    /// The last 16 input levels, 0...1, for the waveform.
    var levels: [Float] { get }

    func permission() -> VoicePermission
    /// Asks for microphone and speech recognition access. Returns whether both are allowed.
    func requestPermission() async -> Bool
    func start(language: String?) throws
    /// Stops listening and waits briefly for the final transcript.
    func stop() async -> VoiceResult
    func cancel()
}

/// On-device speech recognition from the microphone.
@Observable
@MainActor
final class SpeechVoiceInput: VoiceInput {
    private(set) var transcript = ""
    private(set) var levels = [Float](repeating: 0, count: 16)

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var lastConfidence: Float = 1
    @ObservationIgnored private var failed = false
    @ObservationIgnored private var finalResult: CheckedContinuation<Void, Never>?
    /// Bumped each start, so callbacks from an earlier session are ignored.
    @ObservationIgnored private var session = 0

    func permission() -> VoicePermission {
        let mic = AVAudioApplication.shared.recordPermission
        let speech = SFSpeechRecognizer.authorizationStatus()
        if mic == .denied || speech == .denied || speech == .restricted { return .denied }
        if mic == .undetermined || speech == .notDetermined { return .notDetermined }
        return .allowed
    }

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start(language: String?) throws {
        cancel()
        session += 1
        let current = session
        transcript = ""
        failed = false
        lastConfidence = 1

        let locale = language.map(Locale.init(identifier:)) ?? .current
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else {
            throw VoiceError.unavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = Self.level(of: buffer)
            Task { @MainActor in
                guard self?.session == current else { return }
                self?.push(level: level)
            }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            // The mic may be busy (a call). Remove the tap so the next start can add one.
            stopAudio()
            self.request = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let segments = result?.bestTranscription.segments ?? []
            let confidence = segments.isEmpty ? Float(1) : segments.map(\.confidence).reduce(0, +) / Float(segments.count)
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                guard let self, self.session == current else { return }
                if let text { self.transcript = text }
                if isFinal { self.lastConfidence = confidence }
                if failed { self.failed = true }
                if isFinal || failed {
                    self.finalResult?.resume()
                    self.finalResult = nil
                }
            }
        }
    }

    func stop() async -> VoiceResult {
        guard request != nil else { return VoiceResult(transcript: transcript, isUncertain: false) }
        stopAudio()
        request?.endAudio()
        let stopping = session
        // Wait for the final result, but never more than 1.5 s.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // Never leave an earlier waiter hanging.
            finalResult?.resume()
            finalResult = continuation
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                // Only time out this stop, not a newer session's.
                guard self.session == stopping else { return }
                self.finalResult?.resume()
                self.finalResult = nil
            }
        }
        let result = VoiceResult(transcript: transcript,
                                 isUncertain: failed || lastConfidence < 0.35)
        finish()
        return result
    }

    func cancel() {
        stopAudio()
        task?.cancel()
        finalResult?.resume()
        finalResult = nil
        finish()
    }

    // MARK: - Private

    private func stopAudio() {
        if engine.isRunning {
            engine.stop()
        }
        // Always remove the tap, even if the engine was stopped by an interruption;
        // installing a second one on the same bus would crash.
        engine.inputNode.removeTap(onBus: 0)
    }

    private func finish() {
        task = nil
        request = nil
        levels = [Float](repeating: 0, count: 16)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func push(level: Float) {
        levels.removeFirst()
        levels.append(level)
    }

    /// Rough loudness of a buffer, 0...1.
    nonisolated private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        return min(1, rms * 12)
    }
}

enum VoiceError: Error {
    case unavailable
}

#if DEBUG
/// Types out a sample sentence word by word, for the simulator and screenshots.
@Observable
@MainActor
final class DemoVoiceInput: VoiceInput {
    private(set) var transcript = ""
    private(set) var levels = [Float](repeating: 0, count: 16)
    @ObservationIgnored private var typing: Task<Void, Never>?
    let phrase: String

    init(phrase: String = "Remind me to call Dana tomorrow at 10 about the lease") {
        self.phrase = phrase
    }

    func permission() -> VoicePermission { .allowed }
    func requestPermission() async -> Bool { true }

    func start(language: String?) throws {
        transcript = ""
        let words = phrase.split(separator: " ").map(String.init)
        typing = Task { @MainActor [weak self] in
            for (index, _) in words.enumerated() {
                try? await Task.sleep(for: .milliseconds(230))
                guard let self, !Task.isCancelled else { return }
                self.transcript = words[0...index].joined(separator: " ")
                self.levels.removeFirst()
                self.levels.append(Float.random(in: 0.2...1))
            }
        }
    }

    func stop() async -> VoiceResult {
        typing?.cancel()
        return VoiceResult(transcript: transcript, isUncertain: false)
    }

    func cancel() {
        typing?.cancel()
        transcript = ""
    }
}
#endif
