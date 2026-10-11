import ActivityKit
import AppIntents
import SwiftUI

/// 11g: listening in the Dynamic Island after pressing the Action button.
struct VoiceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable { case listening, saved, nothing }

        struct Chunk: Codable, Hashable {
            /// "normal", "filler", "time" or "project", as in VoiceParse.
            var kind: String
            var text: String
        }

        var phase: Phase
        var chunks: [Chunk]
        var savedTitle: String?
        var savedDestination: String?
        /// What Undo removes.
        var savedItemID: String?

        static func listening(_ parse: VoiceParse) -> ContentState {
            ContentState(phase: .listening, chunks: parse.chunks.map { Chunk(kind: kindName($0.kind), text: $0.text) })
        }

        static func saved(title: String, destination: String, itemID: UUID? = nil) -> ContentState {
            ContentState(phase: .saved, chunks: [], savedTitle: title, savedDestination: destination,
                         savedItemID: itemID?.uuidString)
        }

        static let nothingHeard = ContentState(phase: .nothing, chunks: [])

        private static func kindName(_ kind: VoiceParse.Chunk.Kind) -> String {
            switch kind {
            case .normal: return "normal"
            case .filler: return "filler"
            case .time: return "time"
            case .project: return "project"
            }
        }
    }
}

/// The Lock Screen banner and the Dynamic Island's expanded view.
struct VoiceActivityView: View {
    let state: VoiceActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            switch state.phase {
            case .listening:
                VoiceActivityTranscript(chunks: state.chunks)
                HStack {
                    Text("Stops when you stop talking")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button(intent: FinishVoiceActivityIntent()) {
                        Text("Save")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.blue, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            case .saved:
                Text(state.savedTitle ?? "")
                    .font(.headline)
                    .lineLimit(2)
                HStack {
                    Spacer()
                    Button(intent: UndoVoiceCatchIntent(itemID: state.savedItemID ?? "")) {
                        Text("Undo")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            case .nothing:
                Text("Press the Action button and talk.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var header: some View {
        switch state.phase {
        case .listening:
            HStack(spacing: 6) {
                Circle().fill(Theme.red).frame(width: 8, height: 8)
                Text("Listening")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.red)
            }
        case .saved:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.green)
                Text("Saved to \(state.savedDestination ?? "Inbox")")
                    .font(.subheadline.weight(.semibold))
            }
        case .nothing:
            Text("Didn't hear anything")
                .font(.subheadline.weight(.semibold))
        }
    }
}

/// The transcript with the same highlighting as the app's voice sheet.
struct VoiceActivityTranscript: View {
    let chunks: [VoiceActivityAttributes.ContentState.Chunk]

    var body: some View {
        transcript
            .font(.title3.weight(.semibold))
            .lineLimit(3)
    }

    private var transcript: Text {
        guard !chunks.isEmpty else {
            return Text("…").foregroundStyle(.white.opacity(0.4))
        }
        var result = AttributedString()
        for (index, chunk) in chunks.enumerated() {
            if index > 0 { result += AttributedString(" ") }
            var part = AttributedString(chunk.text)
            switch chunk.kind {
            case "filler":
                part.foregroundColor = Color.white.opacity(0.4)
            case "time":
                part.foregroundColor = Theme.orange
                part.backgroundColor = Theme.orange.opacity(0.25)
            case "project":
                part.foregroundColor = Color(red: 0.6, green: 0.6, blue: 1)
                part.backgroundColor = Theme.purple.opacity(0.3)
            default:
                part.foregroundColor = Color.white
            }
            result += part
        }
        return Text(result)
    }
}
