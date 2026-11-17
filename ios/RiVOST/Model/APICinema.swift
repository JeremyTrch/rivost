import Foundation

/// The four Riviera cinemas, with their API Cinéma ids resolved once (saves 4 search calls per refresh).
enum Riviera {
    static let cinemas: [Cinema] = [
        Cinema(key: "cineum-cannes", id: "cnc_723880", slug: "cineum-cannes-cannes",
               name: "Cineum Cannes", city: "Cannes", label: "Cinéum Cannes"),
        Cinema(key: "pathe-lingostiere", id: "cnc_290191", slug: "pathe-lingostiere-nice",
               name: "Pathe Lingostiere", city: "Nice", label: "Pathé Lingostière Nice"),
        Cinema(key: "cgr-cagnes", id: "cnc_81545", slug: "cgr-polygone-riviera-cagnes-sur-mer",
               name: "Cgr Polygone Riviera", city: "Cagnes-sur-Mer", label: "CGR Cagnes-sur-Mer"),
        Cinema(key: "cineplanet-antibes", id: "cnc_20685", slug: "cineplanet-antibes-antibes",
               name: "Cineplanet Antibes", city: "Antibes", label: "Cinéplanet Antibes"),
    ]
}

enum APICinemaError: LocalizedError {
    case missingKey
    case unauthorized
    case quota
    case http(Int, String?)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            "Clé API Cinéma absente. Crée ios/Config/Secrets.xcconfig (voir Secrets.example.xcconfig)."
        case .unauthorized:
            "La clé API Cinéma est refusée."
        case .quota:
            "Quota API Cinéma atteint pour cette semaine. Les dernières séances connues restent affichées."
        case .http(let code, let detail):
            "API Cinéma a répondu \(code)\(detail.map { " : \($0)" } ?? "")."
        }
    }
}

/// Direct client for https://api-cinema.com — the app talks to it without any intermediate server.
struct APICinemaClient {
    private static let base = URL(string: "https://api.api-cinema.com")!

    let key: String

    /// Reads the key injected at build time (Config/Secrets.xcconfig → Info.plist "ApiCinemaKey").
    static func fromBundle() throws -> APICinemaClient {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "ApiCinemaKey") as? String,
              !key.isEmpty, !key.hasPrefix("$(") else { throw APICinemaError.missingKey }
        return APICinemaClient(key: key)
    }

    // MARK: Wire types

    private struct Page: Decodable {
        let data: [Row]
        let meta: Meta
        struct Meta: Decodable { let nextCursor: String? }
    }

    private struct Row: Decodable {
        let id: String
        let startsAt: String
        let version: String
        let format: String
        let room: String?
        let bookingUrl: String?
        let movie: Movie?
    }

    private struct SearchBody: Encodable {
        let from: String
        let to: String
        let version = "VOST"
        let include = ["movie"]
        let limit = 1000
        let cursor: String?
    }

    private struct ErrorBody: Decodable { let error: String?; let message: String? }

    // MARK: Requests

    /// VOST showtimes of the coming week (today + 6 days, Paris time) for every Riviera cinema.
    func weekShowtimes(today: String = Paris.dayKey()) async throws -> [Showtime] {
        let to = Paris.adding(days: 6, to: today)
        var showtimes: [Showtime] = []
        for cinema in Riviera.cinemas {
            var cursor: String?
            repeat {
                let page = try await search(cinema: cinema.id, body: SearchBody(from: today, to: to, cursor: cursor))
                for row in page.data where row.version == "VOST" {
                    guard let movie = row.movie else { continue }
                    showtimes.append(Showtime(
                        id: row.id,
                        startsAt: row.startsAt,
                        version: row.version,
                        format: row.format,
                        room: row.room,
                        bookingUrl: row.bookingUrl,
                        roomLabel: RoomLabel.make(format: row.format, room: row.room),
                        movie: movie,
                        cinema: cinema
                    ))
                }
                cursor = page.meta.nextCursor
            } while cursor != nil
        }
        return showtimes.sorted { $0.startsAt < $1.startsAt }
    }

    private func search(cinema id: String, body: SearchBody) async throws -> Page {
        let path = "v1/cinemas/\(id)/showtimes/search"
        var request = URLRequest(url: Self.base.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("RiVOST-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        switch status {
        case 200..<300:
            return try JSONDecoder().decode(Page.self, from: data)
        case 401, 403:
            throw APICinemaError.unauthorized
        case 429:
            throw APICinemaError.quota
        default:
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw APICinemaError.http(status, body?.error ?? body?.message)
        }
    }
}

/// Human label for the screening experience: premium formats first, then distinctive room names.
enum RoomLabel {
    private static let premium = /(?i)lounge|lodge|cosy|imax|atmos|premium|vip|laser|ice|screen\s*x|dolby|aurore/

    private static func clean(_ room: String) -> String {
        room.trimmingCharacters(in: .whitespaces)
            .replacing(/^(?i)salle\s+/, with: "")
            .replacing(/\s+/, with: " ")
    }

    static func make(format: String, room: String?) -> String {
        switch format {
        case "IMAX": return "IMAX"
        case "4DX": return "4DX"
        case "DOLBY":
            if let room, room.contains(/(?i)screen\s*x|lodge|cosy/) { return clean(room) }
            return "Dolby"
        case "3D":
            if let room, room.contains(premium) { return "\(clean(room)) · 3D" }
            return "3D"
        default:
            guard let room else { return "Standard" }
            let cleaned = clean(room)
            if cleaned.contains(premium) || room.contains(premium) { return cleaned }
            // A bare number ("3", "Salle 3") says nothing: call it Standard.
            if cleaned.wholeMatch(of: /\d+/) == nil, !cleaned.isEmpty { return cleaned }
            return "Standard"
        }
    }
}
