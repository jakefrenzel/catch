import Foundation

/// Joins the speech recognizer's results into one transcript. Since iOS 17,
/// on-device recognition starts over after a pause: the next result holds only
/// what was said after it, and the last one can be empty. Neither may erase
/// what came before.
struct TranscriptAccumulator: Equatable {
    /// Text from before the recognizer last started over.
    private(set) var earlier = ""
    /// The current stretch, which the recognizer may still revise.
    private(set) var current = ""
    /// The recognizer said the current stretch is over, so the next result starts a new one.
    private var stretchEnded = false

    var text: String {
        [earlier, current].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// `endsStretch`: the recognizer marked this result as the end of a stretch of speech.
    mutating func add(_ result: String, endsStretch: Bool = false) {
        let result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            if endsStretch { stretchEnded = true }
            return
        }
        let new = Self.words(result)
        if !earlier.isEmpty, new.starts(with: Self.words(earlier)) {
            // A result that repeats everything said so far.
            earlier = ""
        } else if stretchEnded {
            // Unless it repeats the stretch that ended, it's what was said next.
            if !new.starts(with: Self.words(current)) { earlier = text }
        } else if Self.startedOver(from: current, to: new) {
            earlier = text
        }
        current = result
        stretchEnded = endsStretch
    }

    /// Revisions keep the first word once a few words are in, and don't get
    /// shorter while changing it; a fresh start does.
    private static func startedOver(from old: String, to new: [String]) -> Bool {
        let old = words(old)
        guard let first = old.first, let newFirst = new.first, first != newFirst else { return false }
        return old.count >= 3 || new.count < old.count
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
}
