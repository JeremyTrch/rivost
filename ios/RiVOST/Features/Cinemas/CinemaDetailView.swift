import SwiftUI

struct CinemaDetailView: View {
    @Environment(ShowtimesStore.self) private var store
    let cinema: Cinema
    let namespace: Namespace.ID

    @State private var day: String? = Paris.dayKey()

    private var days: [String] { store.days(for: cinema.key) }

    private var activeDay: String? {
        guard let day, days.contains(day) else { return nil }
        return day
    }

    var body: some View {
        let films = store.films(day: activeDay, cinema: cinema.key)
        let weekFilms = store.films(day: nil, cinema: cinema.key)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(weekFilms: weekFilms)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                SectionTitle(eyebrow: "Programme VOST", title: activeDay.map(Paris.title) ?? "Toute la semaine")
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 8)

                DayStrip(days: days, selection: $day)

                if films.isEmpty {
                    EmptyStateCard(title: "Relâche", message: "Pas de séance VOST ce jour-là ici.", actionTitle: "Voir la semaine") {
                        withAnimation(.snappy) { day = nil }
                    }
                    .padding(.top, 14)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(films) { film in
                            NavigationLink(value: FilmRoute(filmID: film.id, sourceID: "cinema-row-\(film.id)", cinemaKey: cinema.key)) {
                                MovieRow(film: film, showsDay: activeDay == nil)
                            }
                            .buttonStyle(PressableStyle())
                            .matchedTransitionSource(id: "cinema-row-\(film.id)", in: namespace)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .animation(.snappy, value: activeDay)
                }

                FooterNote()
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background { RivieraBackground() }
        .navigationTitle(cinema.shortName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(weekFilms: [Film]) -> some View {
        let count = weekFilms.reduce(0) { $0 + $1.showtimes.count }
        let premium = Set(weekFilms.flatMap(\.showtimes).filter(\.isPremium).map(\.roomLabel)).sorted()

        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(cinema.city, color: cinema.tint)
            Text(cinema.label)
                .font(.display(34))
                .foregroundStyle(RV.ink)
                .padding(.top, 8)
            Text("\(count.counted("séance")) VOST · \(weekFilms.count.counted("film")) cette semaine")
                .font(.system(size: 14))
                .foregroundStyle(RV.fog.opacity(0.85))
                .padding(.top, 6)

            if !premium.isEmpty {
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(premium, id: \.self) { label in
                        Text(label.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(RV.goldHot)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .overlay(Capsule().strokeBorder(RV.gold.opacity(0.45)))
                    }
                }
                .padding(.top, 14)
            }

            Link(destination: cinema.mapsURL) {
                Label("Itinéraire", systemImage: "location.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(cinema.tint)
            .padding(.top, 20)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [cinema.tint.opacity(0.4), RV.surface.opacity(0.9), RV.night], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle()
                    .fill(cinema.tint.opacity(0.3))
                    .frame(width: 260)
                    .blur(radius: 70)
                    .offset(x: 140, y: -80)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
