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
        "set a reminder to", "remind me to", "don't forget to", "dont forget to", "set a reminder",
        "note to self", "i need to", "i have to", "remind me", "add",
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

        var dayRange: NSRange?
        if found == nil, let spoken = spokenTime(in: lower, now: now, calendar: calendar) {
            found = (spoken.range, spoken.date)
            dayRange = spoken.dayRange
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
        for range in [found.range, dayRange].compactMap({ $0 }) {
            var first: Int?
            for index in tokens.indices where NSIntersectionRange(tokens[index].range, range).length > 0 {
                tokens[index].kind = .time
                first = first ?? index
            }
            // "on Monday", "at 5": the lead-in word belongs to the time.
            if let first, first > 0, tokens[first - 1].kind == .normal, timeLeadIns.contains(tokens[first - 1].word) {
                tokens[first - 1].kind = .time
            }
        }
        return found.date
    }

    // MARK: Spoken times

    // NSDataDetector wants "5:00", "5 PM" or "five o'clock"; people also say
    // "at five", "five thirty" or "for 5".
    private static let hourWords = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                                    "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12]
    private static let minuteWords = ["oh five": 5, "fifteen": 15, "thirty": 30, "forty five": 45, "forty-five": 45]
    private static let spokenTimePattern = try? NSRegularExpression(pattern:
        "\\b(at|for|by|around)\\s+(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|1[0-2]|[1-9])"
        + "(?:(?::|\\s)(oh five|fifteen|thirty|forty[- ]five|[0-5][0-9]))?"
        + "(?:\\s*(a\\.?\\s?m\\.?|p\\.?\\s?m\\.?|o'?clock|in the morning|in the afternoon|in the evening|at night))?"
        + "(?=$|[\\s.,!?])")
    private static let dayPattern = try? NSRegularExpression(pattern:
        "\\b(today|tonight|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b")
    /// In Calendar's order, so index + 1 is the weekday number.
    private static let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
    /// Words that may follow a spoken time; anything else ("for five people") isn't one.
    private static let afterSpokenTime: Set<String> = [
        "today", "tonight", "tomorrow", "on", "this", "next", "monday", "tuesday", "wednesday", "thursday",
        "friday", "saturday", "sunday", "to", "and", "about", "that", "so", "please", "remind",
    ]

    private static func spokenTime(in lower: NSString, now: Date, calendar: Calendar)
        -> (range: NSRange, dayRange: NSRange?, date: Date)? {
        guard let pattern = spokenTimePattern else { return nil }
        let text = lower as String
        for match in pattern.matches(in: text, range: NSRange(location: 0, length: lower.length)) {
            let lead = lower.substring(with: match.range(at: 1))
            let hourText = lower.substring(with: match.range(at: 2))
            let isDigits = hourText.first?.isNumber == true
            // "at 5" and "at 5:30" are NSDataDetector's.
            if lead == "at", isDigits { continue }
            // "dinner for two" isn't a time; "set a reminder for two" is.
            if lead == "for", lower.range(of: "remind").location == NSNotFound
                || lower.range(of: "remind").location > match.range.location { continue }
            let rest = lower.substring(from: NSMaxRange(match.range))
            let next = rest.split(whereSeparator: { $0.isWhitespace }).first
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            if let next, !next.isEmpty, !afterSpokenTime.contains(next) { continue }

            guard let hour = isDigits ? Int(hourText) : hourWords[hourText] else { continue }
            var minute = 0
            if match.range(at: 3).location != NSNotFound {
                let minuteText = lower.substring(with: match.range(at: 3))
                minute = Int(minuteText) ?? minuteWords[minuteText] ?? 0
            }
            var meridiem: Bool?   // true = PM
            if match.range(at: 4).location != NSNotFound {
                let suffix = lower.substring(with: match.range(at: 4))
                if suffix.hasPrefix("p") || suffix.contains("afternoon") || suffix.contains("evening") || suffix.contains("night") {
                    meridiem = true
                } else if suffix.hasPrefix("a") || suffix.contains("morning") {
                    meridiem = false
                }
            }

            let dayMatch = dayPattern?.firstMatch(in: text, range: NSRange(location: 0, length: lower.length))
            let day = dayMatch.map { lower.substring(with: $0.range) }
            if day == "tonight", meridiem == nil { meridiem = true }
            guard let date = spokenDate(hour: hour, minute: minute, pm: meridiem, day: day,
                                        now: now, calendar: calendar) else { continue }
            return (match.range, dayMatch?.range, date)
        }
        return nil
    }

    /// Without AM or PM, 1–6 means afternoon and 7–11 the next time that hour comes round.
    private static func spokenDate(hour: Int, minute: Int, pm: Bool?, day: String?,
                                   now: Date, calendar: Calendar) -> Date? {
        // By the Catch day: "tomorrow" said at 1 AM, still last night, means later today.
        let today = DayClock.day(of: now, calendar: calendar)
        var start = today
        var dayGiven = false
        if day == "tomorrow" {
            start = DayClock.tomorrow(after: now, calendar: calendar)
            dayGiven = true
        } else if let day, let weekday = weekdays.firstIndex(of: day) {
            start = calendar.nextDate(after: today, matching: DateComponents(weekday: weekday + 1),
                                      matchingPolicy: .nextTime) ?? today
            dayGiven = true
        }
        func at(_ hour24: Int, on day: Date) -> Date? {
            calendar.date(bySettingHour: hour24, minute: minute, second: 0, of: day)
        }
        let hour24: Int
        switch pm {
        case true?: hour24 = hour % 12 + 12
        case false?: hour24 = hour % 12
        case nil:
            if hour == 12 || (1...6).contains(hour) {
                hour24 = hour == 12 ? 12 : hour + 12
            } else if !dayGiven {
                // "at 8" at 9 AM is tonight; at 9 PM it's tomorrow morning.
                if let morning = at(hour, on: start), morning > now { return morning }
                if let evening = at(hour + 12, on: start), evening > now { return evening }
                return calendar.date(byAdding: .day, value: 1, to: start).flatMap { at(hour, on: $0) }
            } else {
                hour24 = hour
            }
        }
        guard let date = at(hour24, on: start) else { return nil }
        if !dayGiven, date <= now {
            return calendar.date(byAdding: .day, value: 1, to: date)
        }
        return date
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
        var normal = tokens.indices.filter { tokens[$0].kind == .normal }
        // "Remind me at five to call Bob": the "to" belongs to the lead-in.
        if let first = normal.first, first > 0, tokens[first].word == "to", tokens[first - 1].kind != .normal {
            normal.removeFirst()
        }
        let words = normal.map { tokens[$0].text }
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
