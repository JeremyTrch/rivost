import Foundation
import Observation

@Observable
final class ShowtimesStore {
    private(set) var snapshot: Snapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastSync: Date?

    private(set) var showtimes: [Showtime] = []
    private(set) var allFilms: [Film] = []
    private(set) var days: [String] = []
    private(set) var featured: [Film] = []
    private var filmsByID: [String: Film] = [:]

    var hasData: Bool { snapshot != nil }
    var cinemas: [Cinema] { snapshot?.cinemas ?? [] }

    var fetchedAt: Date? {
        guard let raw = snapshot?.fetchedAt else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    /// API Cinéma allows 250 requests a week (~5 per refresh), so data is kept 6 hours
    /// unless the day changed, and a manual refresh is honoured at most every 10 minutes.
    private static let maxAge: TimeInterval = 6 * 3600
    private static let minManualInterval: TimeInterval = 10 * 60

    var isStale: Bool {
        guard let fetchedAt else { return true }
        return Date.now.timeIntervalSince(fetchedAt) > Self.maxAge || snapshot?.today.map { $0 < Paris.dayKey() } ?? true
    }

    init() {
        if let cached = Self.readCache() { apply(cached) }
    }

    // MARK: Queries

    func film(id: String) -> Film? { filmsByID[id] }

    func filtered(day: String?, cinema: String?) -> [Showtime] {
        showtimes.filter { st in
            (day == nil || st.day == day) && (cinema == nil || st.cinema.key == cinema)
        }
    }

    func films(day: String?, cinema: String?) -> [Film] {
        Self.group(filtered(day: day, cinema: cinema))
    }

    func days(for cinema: String?) -> [String] {
        guard let cinema else { return days }
        return Array(Set(showtimes.filter { $0.cinema.key == cinema }.map(\.day))).sorted()
    }

    // MARK: Loading

    /// Fetches this week's VOST showtimes straight from API Cinéma, then finds a working poster for each film.
    /// - Parameter force: pull-to-refresh; still skipped if the data is under 10 minutes old.
    func load(force: Bool = false) async {
        guard !isLoading else { return }
        if hasData, let fetchedAt {
            let age = Date.now.timeIntervalSince(fetchedAt)
            if force ? age < Self.minManualInterval : !isStale { return }
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let client = try APICinemaClient.fromBundle()
            let today = Paris.dayKey()
            let raw = try await client.weekShowtimes(today: today)

            var known: [String: String] = [:]
            for st in showtimes { if let url = st.movie.posterUrl { known[st.movie.id] = url } }
            let resolved = await PosterResolver(known: known).resolve(raw)

            let snapshot = Snapshot(
                fetchedAt: ISO8601DateFormatter().string(from: .now),
                showtimes: resolved,
                cinemas: Riviera.cinemas,
                error: nil,
                today: today
            )
            apply(snapshot)
            lastSync = .now
            errorMessage = nil
            Self.writeCache(snapshot)
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch let error as URLError {
            errorMessage = error.code == .notConnectedToInternet
                ? "Pas de connexion internet."
                : "Impossible de joindre API Cinéma."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ snapshot: Snapshot) {
        let today = Paris.dayKey()
        let upcoming = snapshot.showtimes
            .filter { $0.day >= today }
            .sorted { $0.startsAt < $1.startsAt }

        self.snapshot = snapshot
        showtimes = upcoming
        days = Array(Set(upcoming.map(\.day))).sorted()
        allFilms = Self.group(upcoming)
        filmsByID = Dictionary(uniqueKeysWithValues: allFilms.map { ($0.id, $0) })
        featured = Array(
            allFilms
                .filter { $0.movie.hasPoster && $0.nextShowtime != nil }
                .sorted { ($0.showtimes.count, $1.movie.title) > ($1.showtimes.count, $0.movie.title) }
                .prefix(7)
        )
    }

    static func group(_ showtimes: [Showtime]) -> [Film] {
        var order: [String] = []
        var buckets: [String: [Showtime]] = [:]
        for st in showtimes {
            let key = st.movie.groupKey
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(st)
        }
        return order
            .compactMap { key in
                buckets[key].map { group in
                    // Several cinemas may list the same film; prefer the listing that carries a poster.
                    let movie = group.first { $0.movie.hasPoster }?.movie ?? group[0].movie
                    return Film(id: key, movie: movie, showtimes: group)
                }
            }
            .sorted {
                $0.movie.title.compare($1.movie.title, options: [.caseInsensitive, .diacriticInsensitive], locale: Paris.locale) == .orderedAscending
            }
    }

    // MARK: Disk cache (instant launch + offline)

    private static var cacheURL: URL {
        URL.cachesDirectory.appending(path: "rivost-snapshot.json")
    }

    private static func readCache() -> Snapshot? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private static func writeCache(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
