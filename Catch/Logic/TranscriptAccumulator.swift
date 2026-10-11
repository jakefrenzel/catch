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

    var text: String {
        [earlier, current].filter { !$0.isEmpty }.joined(separator: " ")
    }

    mutating func add(_ result: String) {
        let result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return }
        let new = Self.words(result)
        if !earlier.isEmpty, new.starts(with: Self.words(earlier)) {
            // A result that repeats everything said so far.
            earlier = ""
        } else if Self.startedOver(from: current, to: new) {
            earlier = text
        }
        current = result
    }

    /// Revisions keep the first word once a few words are in; a fresh start doesn't.
    private static func startedOver(from old: String, to new: [String]) -> Bool {
        let old = words(old)
        guard old.count >= 3, let first = old.first, let newFirst = new.first else { return false }
        return first != newFirst
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }
}
