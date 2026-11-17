import Foundation

/// All showtimes are Riviera wall-clock times: every date helper works in Europe/Paris.
enum Paris {
    static let timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
    static let locale = Locale(identifier: "fr_FR")

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }()

    private static let timestampParser = posixFormatter("yyyy-MM-dd'T'HH:mm:ss")
    private static let dayFormatter = posixFormatter("yyyy-MM-dd")
    private static var templates: [String: DateFormatter] = [:]

    private static func posixFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static func formatter(_ template: String) -> DateFormatter {
        if let cached = templates[template] { return cached }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        templates[template] = formatter
        return formatter
    }

    // MARK: Parsing

    /// `2026-11-17T13:10:00` (local Paris time, no offset) → Date
    static func date(_ timestamp: String) -> Date? {
        timestampParser.date(from: String(timestamp.prefix(19)))
    }

    static func dayKey(_ date: Date = .now) -> String { dayFormatter.string(from: date) }

    static func day(_ key: String) -> Date? { dayFormatter.date(from: key) }

    static func adding(days: Int, to key: String) -> String {
        guard let date = day(key), let next = calendar.date(byAdding: .day, value: days, to: date) else { return key }
        return dayKey(next)
    }

    // MARK: Labels

    private static func format(_ key: String, _ template: String) -> String {
        guard let date = day(key) else { return key }
        return formatter(template).string(from: date)
    }

    /// "MAR"
    static func weekdayShort(_ key: String) -> String {
        format(key, "EEE").replacingOccurrences(of: ".", with: "").uppercased()
    }

    /// "Mardi"
    static func weekdayLong(_ key: String) -> String { format(key, "EEEE").capitalizedFirst }

    /// "17"
    static func dayNumber(_ key: String) -> String { format(key, "d") }

    /// "17 novembre"
    static func dayMonth(_ key: String) -> String { format(key, "dMMMM") }

    /// "mardi 17 novembre"
    static func longDay(_ key: String) -> String { format(key, "EEEEdMMMM") }

    /// "mar. 17 nov."
    static func shortDay(_ key: String) -> String { format(key, "EEEdMMM") }

    /// "Aujourd’hui" / "Demain" / nil
    static func relative(_ key: String, today: String = dayKey()) -> String? {
        if key == today { return "Aujourd’hui" }
        if key == adding(days: 1, to: today) { return "Demain" }
        return nil
    }

    /// Best human title for a day: "Aujourd’hui", "Demain", "Jeudi 19 novembre".
    static func title(_ key: String) -> String {
        relative(key) ?? longDay(key).capitalizedFirst
    }

    /// "Ce soir", "Demain", "jeu. 19"
    static func when(_ showtime: Showtime) -> String {
        let today = dayKey()
        if showtime.day == today {
            return (Int(showtime.time.prefix(2)) ?? 0) >= 18 ? "Ce soir" : "Aujourd’hui"
        }
        if showtime.day == adding(days: 1, to: today) { return "Demain" }
        return format(showtime.day, "EEEd")
    }

    static func clock(_ date: Date) -> String { formatter("HHmm").string(from: date) }

    static func updatedLabel(_ date: Date) -> String {
        let style = Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide, locale: locale, calendar: calendar)
        return "Mis à jour \(date.formatted(style))"
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    /// Accent/case-insensitive key for search.
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Paris.locale)
    }

    /// Folded with punctuation collapsed to single spaces: "La Nuit – The Call" == "la nuit - THE CALL".
    var matchKey: String {
        folded
            .replacing(/[^\p{L}\p{N}]+/, with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

extension Int {
    /// `3.counted("séance")` → "3 séances"
    func counted(_ word: String) -> String { "\(self) \(word)\(self > 1 ? "s" : "")" }
}
