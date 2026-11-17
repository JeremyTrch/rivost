import Foundation
import SwiftUI

// MARK: - Wire format (mirrors src/types/showtimes.ts, served by /api/showtimes)

struct Cinema: Codable, Hashable, Identifiable {
    let key: String
    let id: String
    let slug: String
    let name: String
    let city: String
    let label: String
}

struct Movie: Codable, Hashable {
    let id: String
    let title: String
    let originalTitle: String?
    let year: Int?
    let durationMin: Int?
    let director: String?
    let posterUrl: String?
    let tmdbId: Int?
}

struct Showtime: Codable, Hashable, Identifiable {
    let id: String
    let startsAt: String
    let version: String
    let format: String
    let room: String?
    let bookingUrl: String?
    let roomLabel: String
    let movie: Movie
    let cinema: Cinema
}

struct Snapshot: Codable {
    let fetchedAt: String
    let showtimes: [Showtime]
    let cinemas: [Cinema]
    let error: String?
    let today: String?
}

// MARK: - Derived

/// A movie with its (possibly filtered) showtimes, sorted chronologically.
struct Film: Identifiable, Hashable {
    let id: String
    let movie: Movie
    let showtimes: [Showtime]

    var cinemas: [Cinema] {
        var seen = Set<String>()
        return showtimes.compactMap { seen.insert($0.cinema.key).inserted ? $0.cinema : nil }
    }

    var days: [String] {
        var seen = Set<String>()
        return showtimes.compactMap { seen.insert($0.day).inserted ? $0.day : nil }
    }

    var nextShowtime: Showtime? { showtimes.first { !$0.hasStarted } }

    var upcoming: [Showtime] { showtimes.filter { !$0.hasStarted } }
}

/// Navigation value: which film, and which view it zooms out of.
struct FilmRoute: Hashable {
    let filmID: String
    let sourceID: String
    var cinemaKey: String? = nil
}

extension Showtime {
    var day: String { String(startsAt.prefix(10)) }
    var time: String { String(startsAt.dropFirst(11).prefix(5)) }
    var date: Date { Paris.date(startsAt) ?? .distantPast }
    var hasStarted: Bool { date < .now }
    var bookingURL: URL? { bookingUrl.flatMap(URL.init(string:)) }
    var isPremium: Bool { RoomStyle.isPremium(roomLabel) }

    /// "dans 25 min" / "dans 1h40" when the screening starts within 3 hours.
    var countdown: String? {
        let minutes = Int(date.timeIntervalSinceNow / 60)
        guard (0..<180).contains(minutes) else { return nil }
        if minutes < 60 { return "dans \(max(minutes, 1)) min" }
        return "dans \(minutes / 60)h\(String(format: "%02d", minutes % 60))"
    }
}

extension Movie {
    var groupKey: String { tmdbId.map { "tmdb:\($0)" } ?? "id:\(id)" }

    /// Poster sources to try in order: a sharper variant when the CDN supports it, then the original.
    var posterURLs: [URL] {
        guard let raw = posterUrl?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return [] }
        let original = raw.hasPrefix("http://") ? "https://" + raw.dropFirst(7) : raw
        let sharp = original
            .replacingOccurrences(of: "/movie_poster/120/", with: "/movie_poster/800/")
            .replacingOccurrences(of: "image.tmdb.org/t/p/w500/", with: "image.tmdb.org/t/p/w780/")
        var seen = Set<String>()
        return [sharp, original, raw]
            .filter { seen.insert($0).inserted }
            .compactMap { URL(string: $0) ?? $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap(URL.init(string:)) }
    }

    var hasPoster: Bool { !posterURLs.isEmpty }

    var durationLabel: String? {
        guard let durationMin, durationMin > 0 else { return nil }
        let h = durationMin / 60, m = durationMin % 60
        return h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m) min"
    }

    var displayOriginalTitle: String? {
        guard let originalTitle, originalTitle.folded != title.folded else { return nil }
        return originalTitle
    }

    var metaLine: String {
        [year.map(String.init), durationLabel, director].compactMap { $0 }.joined(separator: " · ")
    }

    func matches(_ query: String) -> Bool {
        let q = query.folded
        return [title, originalTitle, director].compactMap { $0?.folded }.contains { $0.contains(q) }
    }
}

extension Cinema {
    var shortName: String {
        switch key {
        case "cineum-cannes": "Cinéum"
        case "pathe-lingostiere": "Pathé Lingostière"
        case "cgr-cagnes": "CGR Polygone"
        case "cineplanet-antibes": "Cinéplanet"
        default: label
        }
    }

    var chipName: String {
        switch key {
        case "pathe-lingostiere": "Pathé"
        case "cgr-cagnes": "CGR"
        default: shortName
        }
    }

    /// Each venue gets its own lamp colour, used for dots and card glows.
    var tint: Color {
        switch key {
        case "cineum-cannes": RV.gold
        case "pathe-lingostiere": Color(hex: 0xE38A4A)
        case "cgr-cagnes": Color(hex: 0xD0566A)
        case "cineplanet-antibes": Color(hex: 0x3FA7B5)
        default: RV.fog
        }
    }

    var mapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: "\(name) \(city)")]
        return components.url!
    }
}

enum RoomStyle {
    static func isPremium(_ label: String) -> Bool {
        label.range(
            of: #"imax|4dx|dolby|lounge|lodge|atmos|vip|premium|laser|ice|3d|screen\s*x|cosy|aurore"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }
}
