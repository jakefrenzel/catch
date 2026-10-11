import Foundation

/// What a spoken sentence means: the highlighted chunks shown while talking,
/// the title to save, and where it goes.
struct VoiceParse: Equatable {
    struct Chunk: Equatable {
        enum Kind: Equatable { case normal, filler, time, project }
        let text: String
        let kind: Kind
    }

    enum Destination: Equatable {
        /// A time was heard.
        case later(Date)
        /// Only a project was heard: add a step to it.
        case projectStep(UUID)
        case inbox
    }

    var chunks: [Chunk]
    var title: String
    var date: Date?
    var projectID: UUID?
    var projectName: String?

    var destination: Destination {
        if let date { return .later(date) }
        if let projectID { return .projectStep(projectID) }
        return .inbox
    }
}

/// Turns a transcript into a VoiceParse. Times come from NSDataDetector plus a
/// few phrases it doesn't know ("after work", "this weekend"); project names are
/// matched loosely so "the kitchen renno" still finds Kitchen Reno.
enum VoiceParser {
    struct ProjectName {
        let id: UUID
        let name: String
    }

    /// Lead-ins that aren't part of the item, longest first.
    private static let leadIns = [
        "remind me to", "don't forget to", "dont forget to", "note to self", "i need to", "i have to",
        "remind me", "add",
    ]
    private static let projectPrepositions: Set<String> = ["to", "for", "in", "into", "on"]
    private static let projectArticles: Set<String> = ["the", "my", "our"]
    private static let timeLeadIns: Set<String> = ["at", "on", "by", "this", "next"]

    private struct Token {
        let range: NSRange
        let text: String
        let word: String   // lowercased, punctuation stripped
        var kind: VoiceParse.Chunk.Kind = .normal
    }

    static func parse(_ transcript: String, projects: [ProjectName], afterWork: TimeOfDay,
                      now: Date, calendar: Calendar) -> VoiceParse {
        let ns = transcript as NSString
        var tokens = tokenize(ns)
        guard !tokens.isEmpty else {
            return VoiceParse(chunks: [], title: "", date: nil, projectID: nil, projectName: nil)
        }

        markLeadIn(&tokens)
        let date = markTime(&tokens, in: ns, afterWork: afterWork, now: now, calendar: calendar)
        let project = markProject(&tokens, projects: projects)

        return VoiceParse(chunks: chunks(from: tokens), title: title(from: tokens), date: date,
                          projectID: project?.id, projectName: project?.name)
    }

    // MARK: - Steps

    // Built once; the voice sheet parses on every transcript change.
    private static let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    private static let wordPattern = try? NSRegularExpression(pattern: "\\S+")

    private static func tokenize(_ ns: NSString) -> [Token] {
        guard let regex = wordPattern else { return [] }
        return regex.matches(in: ns as String, range: NSRange(location: 0, length: ns.length)).map { match in
            let text = ns.substring(with: match.range)
            return Token(range: match.range, text: text, word: normalize(text))
        }
    }

    private static func markLeadIn(_ tokens: inout [Token]) {
        for phrase in leadIns {
            let words = phrase.split(separator: " ").map(String.init)
            guard tokens.count >= words.count,
                  zip(tokens, words).allSatisfy({ $0.word == $1 }) else { continue }
            // Only a lead-in when something follows; and don't fall back to a
            // shorter one ("remind me") when the longest match is everything said.
            guard tokens.count > words.count else { return }
            for index in 0..<words.count { tokens[index].kind = .filler }
            return
        }
    }

    /// Marks the time words and returns the date they mean, if any.
    private static func markTime(_ tokens: inout [Token], in ns: NSString, afterWork: TimeOfDay,
                                 now: Date, calendar: Calendar) -> Date? {
        let lower = ns.lowercased as NSString
        var found: (range: NSRange, date: Date)?

        // Phrases NSDataDetector doesn't turn into the times Catch uses.
        let custom: [(String, () -> Date?)] = [
            ("after work", { afterWork.next(after: now, calendar: calendar) }),
            ("this weekend", {
                calendar.nextDate(after: now, matching: DateComponents(hour: 10, minute: 0, second: 0, weekday: 7),
                                  matchingPolicy: .nextTime)
            }),
        ]
        for (phrase, makeDate) in custom {
            // Whole words only: "after work" isn't in "after workout".
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
            let range = lower.range(of: pattern, options: .regularExpression)
            if range.location != NSNotFound, let date = makeDate() {
                found = (range, date)
                break
            }
        }

        if found == nil,
           let detector = dateDetector,
           let match = detector.firstMatch(in: ns as String, range: NSRange(location: 0, length: ns.length)),
           var date = match.date {
            // "at 9" said after 9 means tomorrow.
            if date <= now, calendar.isDate(date, inSameDayAs: now),
               let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                date = tomorrow
            }
            found = (match.range, date)
        }

        guard let found else { return nil }
        var first: Int?
        for index in tokens.indices where NSIntersectionRange(tokens[index].range, found.range).length > 0 {
            tokens[index].kind = .time
            first = first ?? index
        }
        // "on Monday", "at 5": the lead-in word belongs to the time.
        if let first, first > 0, tokens[first - 1].kind == .normal, timeLeadIns.contains(tokens[first - 1].word) {
            tokens[first - 1].kind = .time
        }
        return found.date
    }

    private static func markProject(_ tokens: inout [Token], projects: [ProjectName]) -> ProjectName? {
        // Longer names first, so "Kitchen Reno Phase 2" wins over "Kitchen Reno".
        let candidates = projects
            .map { ($0, $0.name.split(separator: " ").map { normalize(String($0)) }.filter { !$0.isEmpty }) }
            .filter { !$0.1.isEmpty }
            .sorted { $0.1.count > $1.1.count }

        for (project, words) in candidates {
            guard tokens.count >= words.count else { continue }
            for start in 0...(tokens.count - words.count) {
                let window = tokens[start..<(start + words.count)]
                guard window.allSatisfy({ $0.kind == .normal }),
                      zip(window, words).allSatisfy({ isClose($0.word, $1) }) else { continue }

                for index in start..<(start + words.count) { tokens[index].kind = .project }
                var before = start - 1
                if before >= 0, projectArticles.contains(tokens[before].word), tokens[before].kind == .normal {
                    tokens[before].kind = .project
                    before -= 1
                }
                if before >= 0, projectPrepositions.contains(tokens[before].word), tokens[before].kind == .normal {
                    tokens[before].kind = .filler
                }
                return project
            }
        }
        return nil
    }

    private static func chunks(from tokens: [Token]) -> [VoiceParse.Chunk] {
        var result: [VoiceParse.Chunk] = []
        for token in tokens {
            if let last = result.last, last.kind == token.kind {
                result[result.count - 1] = .init(text: last.text + " " + token.text, kind: last.kind)
            } else {
                result.append(.init(text: token.text, kind: token.kind))
            }
        }
        return result
    }

    private static func title(from tokens: [Token]) -> String {
        let words = tokens.filter { $0.kind == .normal }.map(\.text)
        let joined = words.joined(separator: " ")
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
        guard let first = joined.first else { return "" }
        return first.uppercased() + joined.dropFirst()
    }

    // MARK: - Helpers

    private static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .punctuationCharacters)
    }

    /// Same word, or one edit apart when both words have four or more letters
    /// (so "renno" finds "reno", but "tip" doesn't find "trip").
    static func isClose(_ heard: String, _ target: String) -> Bool {
        if heard == target { return true }
        guard min(heard.count, target.count) >= 4, abs(heard.count - target.count) <= 1 else { return false }
        return editDistance(heard, target) <= 1
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var current = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                current[j] = a[i - 1] == b[j - 1]
                    ? previous[j - 1]
                    : 1 + min(previous[j - 1], previous[j], current[j - 1])
            }
            previous = current
        }
        return previous[b.count]
    }
}
