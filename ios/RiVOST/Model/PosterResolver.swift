import Foundation

/// Finds a poster that really loads for every film, on device.
///
/// Cinema feeds sometimes ship dead links (404, hotlink-blocked 403) or none at all. For each film we try,
/// best first: its own poster (sharper variant first), the same film's poster listed by another cinema,
/// then the public search pages of AlloCiné and TMDB. Only films still without a poster are looked up
/// on those sites, and results are cached with the snapshot, so they see a handful of requests per refresh.
/// If everything fails the UI draws a typographic poster (`GeneratedPoster`).
struct PosterResolver {
    private static let browserUA =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": browserUA,
            "Accept-Language": "fr-FR,fr;q=0.9,en;q=0.6",
        ]
        return URLSession(configuration: config)
    }()

    /// Posters already known to work (from the previous snapshot), keyed by movie id: kept if still valid.
    var known: [String: String] = [:]

    /// Returns the showtimes with each movie's `posterUrl` replaced by a verified URL (or nil).
    func resolve(_ showtimes: [Showtime]) async -> [Showtime] {
        var movies: [String: Movie] = [:]
        for st in showtimes { movies[st.movie.id] = st.movie }

        // Same film listed under different ids by different cinemas: share their posters.
        var siblings: [String: [String]] = [:]
        for movie in movies.values {
            guard let url = movie.posterUrl else { continue }
            for key in Self.keys(movie) { siblings[key, default: []].append(url) }
        }

        let resolved = await withTaskGroup(of: (String, String?).self) { group in
            for movie in movies.values {
                let local = Self.dedupe(
                    [known[movie.id]].compactMap { $0 }
                        + Self.variants(movie.posterUrl)
                        + Self.keys(movie).flatMap { siblings[$0] ?? [] }.flatMap(Self.variants)
                )
                group.addTask {
                    if let url = await firstLoading(local) { return (movie.id, url) }
                    return (movie.id, await firstLoading(await scrape(movie)))
                }
            }
            var out: [String: String] = [:]
            for await (id, url) in group { out[id] = url }
            return out
        }

        return showtimes.map { $0.with(posterUrl: resolved[$0.movie.id] ?? nil) }
    }

    // MARK: Candidates

    private static func variants(_ url: String?) -> [String] {
        guard var raw = url?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return [] }
        if raw.hasPrefix("http://") { raw = "https://" + raw.dropFirst(7) }
        let sharp = raw
            .replacingOccurrences(of: "/movie_poster/120/", with: "/movie_poster/800/")
            .replacingOccurrences(of: "image.tmdb.org/t/p/w500/", with: "image.tmdb.org/t/p/w780/")
            .replacingOccurrences(of: "image.tmdb.org/t/p/w342/", with: "image.tmdb.org/t/p/w780/")
        return dedupe([sharp, raw])
    }

    private static func keys(_ movie: Movie) -> [String] {
        [movie.tmdbId.map { "tmdb:\($0)" },
         movie.title.matchKey.isEmpty ? nil : "t:\(movie.title.matchKey)",
         movie.originalTitle.flatMap { $0.matchKey.isEmpty ? nil : "t:\($0.matchKey)" }]
            .compactMap { $0 }
    }

    private static func dedupe(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0).inserted }
    }

    // MARK: Checking

    /// True when the URL answers 2xx with an image (only the headers are read; the body is dropped).
    private func loads(_ raw: String) async -> Bool {
        guard let url = URL(string: raw) else { return false }
        var request = URLRequest(url: url)
        request.setValue("image/avif,image/webp,image/*;q=0.9", forHTTPHeaderField: "Accept")
        guard let (bytes, response) = try? await session.bytes(for: request) else { return false }
        bytes.task.cancel()
        guard let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode) && (http.mimeType ?? "").hasPrefix("image/")
    }

    private func firstLoading(_ candidates: [String]) async -> String? {
        for url in candidates where await loads(url) { return url }
        return nil
    }

    // MARK: Scraping AlloCiné / TMDB search pages

    private struct Hit {
        let title: String
        let originalTitle: String?
        let director: String?
        let released: Date?
        let poster: String
    }

    private func scrape(_ movie: Movie) async -> [String] {
        // Long event titles ("La nuit de la glisse 2026 - THE CALL") often find nothing as a whole:
        // also try the part before the subtitle. Matching below still requires the full title.
        let queries = Self.dedupe(
            [movie.title, movie.originalTitle].compactMap { $0 }.flatMap { title in
                [title, title.split(separator: /\s+[-–—:]\s+/).first.map(String.init) ?? title]
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        )
        var out: [String] = []
        for search in [searchAllocine, searchTMDB] {
            for query in queries {
                let found = Self.rank(movie, await search(query))
                out += found.prefix(2)
                if !found.isEmpty { break }
            }
        }
        return Self.dedupe(out)
    }

    private func page(_ url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func searchAllocine(_ query: String) async -> [Hit] {
        var components = URLComponents(string: "https://www.allocine.fr/rechercher/movie/")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url, let html = await page(url) else { return [] }

        return HTML.all(#"<li class="mdl">([\s\S]*?)</li>"#, in: html).compactMap { groups in
            let card = groups[0]
            guard let src = HTML.first(#"class="thumbnail-img"[^>]*data-src="([^"]+)""#, in: card),
                  let title = HTML.first(#"meta-title-link"[^>]*>([^<]+)<"#, in: card),
                  !src.contains("/empty/") else { return nil }
            return Hit(
                title: HTML.decode(title),
                originalTitle: HTML.first(#"Titre original\s*</span>\s*<span[^>]*>([^<]+)<"#, in: card).map(HTML.decode),
                director: HTML.first(#"meta-body-direction[\s\S]*?dark-grey-link">([^<]+)<"#, in: card).map(HTML.decode),
                released: HTML.frenchDate(HTML.first(#"class="date">([^<]+)<"#, in: card)),
                // Drop the thumbnail transform ("/c_310_420/") to get the full-size poster.
                poster: src.replacing(/\/c_\d+_\d+\//, with: "/")
            )
        }
    }

    private func searchTMDB(_ query: String) async -> [Hit] {
        var components = URLComponents(string: "https://www.themoviedb.org/search/movie")!
        components.queryItems = [URLQueryItem(name: "query", value: query), URLQueryItem(name: "language", value: "fr-FR")]
        guard let url = components.url, let html = await page(url) else { return [] }

        return html.components(separatedBy: #"class="comp:media-card"#).dropFirst().prefix(10).compactMap { card in
            guard let path = HTML.first(#"/t/p/w\d+(?:_and_h\d+)?(?:_face)?(/[A-Za-z0-9]+\.(?:jpg|png|webp))"#, in: card),
                  let title = HTML.all(#"<h2[^>]*>\s*<span>([^<]+)</span>(?:<span class="font-light"> \(([^<]+)\)</span>)?"#, in: card).first
            else { return nil }
            return Hit(
                title: HTML.decode(title[0]),
                originalTitle: title.count > 1 && !title[1].isEmpty ? HTML.decode(title[1]) : nil,
                director: nil,
                released: HTML.frenchDate(HTML.first(#"release_date[^>]*>([^<]+)<"#, in: card)),
                poster: "https://image.tmdb.org/t/p/w780\(path)"
            )
        }
    }

    /// Keeps the hits that are this film (title must match) and orders homonyms by director, year
    /// and a release close to today (the film is on screen this week).
    private static func rank(_ movie: Movie, _ hits: [Hit]) -> [String] {
        let titles = Set([movie.title, movie.originalTitle].compactMap { $0?.matchKey }.filter { !$0.isEmpty })
        let director = movie.director?.matchKey ?? ""
        let year: TimeInterval = 365 * 24 * 3600

        return hits.enumerated()
            .compactMap { index, hit -> (String, Int, Int)? in
                guard titles.contains(hit.title.matchKey) || titles.contains(hit.originalTitle?.matchKey ?? "\u{0}") else { return nil }
                var score = 0
                if !director.isEmpty, hit.director?.matchKey == director { score += 4 }
                if let released = hit.released {
                    let releaseYear = Paris.calendar.component(.year, from: released)
                    if let wanted = movie.year, abs(releaseYear - wanted) <= 1 { score += 2 }
                    let delta = released.timeIntervalSinceNow
                    if delta > -2 * year, delta < year { score += 1 }
                }
                return (hit.poster, score, index)
            }
            .sorted { ($0.1, -$0.2) > ($1.1, -$1.2) }
            .map(\.0)
    }
}

/// Minimal helpers to read the bits we need from search-result HTML.
enum HTML {
    private static let months = ["janvier", "fevrier", "mars", "avril", "mai", "juin",
                                 "juillet", "aout", "septembre", "octobre", "novembre", "decembre"]

    /// Capture groups of every match (missing optional groups become "").
    static func all(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (1..<max(match.numberOfRanges, 2)).map { i in
                let range = match.range(at: i)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }

    static func first(_ pattern: String, in text: String) -> String? {
        all(pattern, in: text).first?.first.flatMap { $0.isEmpty ? nil : $0 }
    }

    static func decode(_ s: String) -> String {
        var out = s
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        for match in all(#"&#(\d+);"#, in: out) {
            if let code = UInt32(match[0]), let scalar = Unicode.Scalar(code) {
                out = out.replacingOccurrences(of: "&#\(match[0]);", with: String(Character(scalar)))
            }
        }
        return out.replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "28 octobre 2026" → Date
    static func frenchDate(_ s: String?) -> Date? {
        guard let parts = s.map({ all(#"(\d{1,2}) ([a-z]+) (\d{4})"#, in: $0.matchKey).first }) ?? nil,
              let month = months.firstIndex(of: parts[1]),
              let day = Int(parts[0]), let year = Int(parts[2]) else { return nil }
        return Paris.calendar.date(from: DateComponents(year: year, month: month + 1, day: day))
    }
}

extension Showtime {
    func with(posterUrl: String?) -> Showtime {
        Showtime(id: id, startsAt: startsAt, version: version, format: format, room: room,
                 bookingUrl: bookingUrl, roomLabel: roomLabel, movie: movie.with(posterUrl: posterUrl), cinema: cinema)
    }
}

extension Movie {
    func with(posterUrl: String?) -> Movie {
        Movie(id: id, title: title, originalTitle: originalTitle, year: year, durationMin: durationMin,
              director: director, posterUrl: posterUrl, tmdbId: tmdbId)
    }
}
