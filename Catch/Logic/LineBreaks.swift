import Foundation

/// Single-line fields that grow vertically get Return as a newline character.
/// This tells a typed Return (which saves) from pasted text with line breaks
/// (which should keep its words apart: "Buy milk Call Dana", not "Buy milkCall Dana").
enum LineBreaks {
    struct Change: Equatable {
        /// The text with its line breaks taken out.
        let text: String
        /// The user pressed Return: the only change was one newline.
        let typedReturn: Bool
    }

    /// Nil when `new` has no line breaks, so there's nothing to do.
    static func change(from old: String, to new: String) -> Change? {
        guard new.contains(where: \.isNewline) else { return nil }
        if new.count == old.count + 1 && new.filter({ !$0.isNewline }) == old {
            return Change(text: old, typedReturn: true)
        }
        return Change(text: joined(new), typedReturn: false)
    }

    /// Lines joined with single spaces, blank lines dropped.
    static func joined(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
