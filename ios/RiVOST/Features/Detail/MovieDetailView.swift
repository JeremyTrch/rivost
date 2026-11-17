import SwiftUI

struct MovieDetailView: View {
    let film: Film
    @State private var cinema: String?

    private let heroHeight: CGFloat = 540

    /// "Dune — en VOST : Cinéplanet, mar. 17 nov. à 13:10 …"
    private var shareText: String {
        let lines = film.upcoming.prefix(4).map { "• \($0.cinema.shortName), \(Paris.shortDay($0.day)) à \($0.time)" }
        return (["\(film.movie.title) en VOST sur la Riviera :"] + lines).joined(separator: "\n")
    }

    init(film: Film, initialCinema: String?) {
        self.film = film
        let valid = film.cinemas.contains { $0.key == initialCinema }
        _cinema = State(initialValue: valid ? initialCinema : nil)
    }

    private var shown: [Showtime] {
        film.showtimes.filter { cinema == nil || $0.cinema.key == cinema }
    }

    private struct DayGroup: Identifiable {
        let day: String
        let venues: [(cinema: Cinema, showtimes: [Showtime])]
        var id: String { day }
    }

    private var schedule: [DayGroup] {
        var days: [String] = []
        var byDay: [String: [Showtime]] = [:]
        for st in shown {
            if byDay[st.day] == nil { days.append(st.day) }
            byDay[st.day, default: []].append(st)
        }
        return days.map { day in
            let list = byDay[day] ?? []
            var order: [String] = []
            var byCinema: [String: [Showtime]] = [:]
            for st in list {
                if byCinema[st.cinema.key] == nil { order.append(st.cinema.key) }
                byCinema[st.cinema.key, default: []].append(st)
            }
            return DayGroup(day: day, venues: order.compactMap { key in
                byCinema[key].map { ($0[0].cinema, $0) }
            })
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                titleBlock
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                stats
                    .padding(.horizontal, 20)
                    .padding(.top, 26)

                if film.cinemas.count > 1 {
                    CinemaChips(cinemas: film.cinemas, selection: $cinema)
                        .padding(.top, 26)
                }

                LazyVStack(alignment: .leading, spacing: 30) {
                    ForEach(schedule) { group in
                        daySection(group)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .animation(.snappy, value: cinema)

                Label("Touchez une séance pour ouvrir la billetterie", systemImage: "ticket")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(RV.mist)
                    .padding(.top, 28)

                FooterNote()
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background { RivieraBackground() }
        .overlay(alignment: .top) { TopFade() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText, subject: Text(film.movie.title)) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        let height = heroHeight
        return ZStack(alignment: .bottom) {
            MoviePoster(movie: film.movie)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .blur(radius: 38, opaque: true)
                .overlay(RV.night.opacity(0.38))
                .overlay {
                    LinearGradient(colors: [RV.night.opacity(0.4), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3))
                }
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.5),
                            .init(color: .black.opacity(0.4), location: 0.8),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .visualEffect { content, proxy in
                    let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                    let stretch = max(y, 0)
                    return content
                        .scaleEffect((height + stretch) / height, anchor: .bottom)
                        .offset(y: stretch > 0 ? 0 : -y * 0.35)
                }

            PosterView(movie: film.movie, cornerRadius: 16)
                .frame(width: 204, height: 306)
                .shadow(color: .black.opacity(0.5), radius: 40, y: 24)
                .padding(.bottom, 28)
        }
        .frame(height: height)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Eyebrow("Version originale sous-titrée")
            Text(film.movie.title)
                .font(.display(36))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .foregroundStyle(RV.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let original = film.movie.displayOriginalTitle {
                Text(original)
                    .font(.system(size: 16, design: .serif).italic())
                    .foregroundStyle(RV.mist)
            }
            HStack(spacing: 8) {
                if let year = film.movie.year { infoPill(String(year), icon: "calendar") }
                if let duration = film.movie.durationLabel { infoPill(duration, icon: "clock") }
                infoPill("VOST", icon: "captions.bubble")
            }
            .padding(.top, 6)
            if let director = film.movie.director {
                Text("Réalisé par \(Text(director).foregroundStyle(RV.fog).fontWeight(.semibold))")
                    .font(.system(size: 14))
                    .foregroundStyle(RV.mist)
                    .padding(.top, 4)
            }
        }
    }

    private func infoPill(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(RV.fog)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("\(film.showtimes.count)", film.showtimes.count > 1 ? "séances" : "séance")
            divider
            stat("\(film.days.count)", film.days.count > 1 ? "jours" : "jour")
            divider
            stat("\(film.cinemas.count)", film.cinemas.count > 1 ? "cinémas" : "cinéma")
        }
        .padding(.vertical, 16)
        .card(radius: 22)
    }

    private var divider: some View {
        Rectangle().fill(RV.line).frame(width: 1, height: 34)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.display(28))
                .foregroundStyle(RV.goldGradient)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(RV.mist)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Schedule

    private func daySection(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Paris.relative(group.day) ?? Paris.weekdayLong(group.day))
                    .font(.display(25))
                    .foregroundStyle(RV.ink)
                Text(Paris.dayMonth(group.day))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(RV.mist)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(group.venues, id: \.cinema.key) { venue in
                VStack(alignment: .leading, spacing: 12) {
                    CinemaLabel(cinema: venue.cinema)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(venue.showtimes) { ShowtimeChip(showtime: $0) }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(radius: 22)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(venue.cinema.tint.gradient)
                        .frame(width: 3, height: 26)
                        .padding(.leading, -1.5)
                        .padding(.top, -2)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 16)
                }
            }
        }
    }
}
