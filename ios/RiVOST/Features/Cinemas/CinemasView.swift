import SwiftUI

struct CinemasView: View {
    @Environment(ShowtimesStore.self) private var store
    @Namespace private var zoom

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(eyebrow: "Riviera", title: "Cinémas", subtitle: "Quatre salles, une seule page.")

                    VStack(spacing: 16) {
                        ForEach(store.cinemas) { cinema in
                            NavigationLink(value: cinema) {
                                CinemaCard(cinema: cinema, films: store.films(day: nil, cinema: cinema.key))
                            }
                            .buttonStyle(PressableStyle())
                            .matchedTransitionSource(id: "cinema-\(cinema.key)", in: zoom)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)

                    FooterNote()
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { RivieraBackground() }
            .overlay(alignment: .top) { TopFade() }
            .refreshable { await store.load(force: true) }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Cinema.self) { cinema in
                CinemaDetailView(cinema: cinema, namespace: zoom)
                    .navigationTransition(.zoom(sourceID: "cinema-\(cinema.key)", in: zoom))
            }
            .navigationDestination(for: FilmRoute.self) { route in
                FilmDestination(route: route)
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: zoom))
            }
        }
    }
}

struct CinemaCard: View {
    let cinema: Cinema
    let films: [Film]

    private var count: Int { films.reduce(0) { $0 + $1.showtimes.count } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [cinema.tint.opacity(0.42), RV.surface.opacity(0.92), RV.night.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(cinema.tint.opacity(0.35))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 170, y: -40)

            PosterFan(films: Array(films.prefix(3)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(cinema.city, color: cinema.tint)
                Text(cinema.shortName)
                    .font(.display(30))
                    .foregroundStyle(RV.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .padding(.top, 6)
                Spacer(minLength: 12)
                HStack(spacing: 18) {
                    stat("\(count)", count > 1 ? "séances" : "séance")
                    stat("\(films.count)", films.count > 1 ? "films" : "film")
                }
            }
            .frame(maxWidth: 158, alignment: .leading)
            .padding(20)
        }
        .frame(height: 196)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 20, y: 12)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.display(26))
                .foregroundStyle(RV.ink)
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(RV.fog.opacity(0.75))
        }
    }
}

/// Three posters fanned like a hand of cards.
struct PosterFan: View {
    let films: [Film]

    var body: some View {
        ZStack {
            ForEach(Array(films.enumerated().reversed()), id: \.element.id) { index, film in
                let offset = CGFloat(index) - CGFloat(films.count - 1) / 2
                PosterView(movie: film.movie, cornerRadius: 9)
                    .frame(width: 78, height: 117)
                    .rotationEffect(.degrees(Double(offset) * 11), anchor: .bottom)
                    .offset(x: offset * 34, y: abs(offset) * 8)
                    .zIndex(Double(films.count - index))
            }
        }
        .frame(width: 170, height: 150)
    }
}
