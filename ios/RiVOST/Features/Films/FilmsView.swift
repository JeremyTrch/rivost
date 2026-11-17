import SwiftUI

struct FilmsView: View {
    @Environment(ShowtimesStore.self) private var store
    @State private var day: String? = Paris.dayKey()
    @State private var cinema: String?
    @Namespace private var zoom

    private var activeDay: String? {
        guard let day, store.days.contains(day) else { return nil }
        return day
    }

    var body: some View {
        let films = store.films(day: activeDay, cinema: cinema)
        let count = films.reduce(0) { $0 + $1.showtimes.count }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BrandHeader()

                    if !store.featured.isEmpty {
                        SectionTitle(eyebrow: "Cette semaine", title: "À l’affiche")
                            .padding(.horizontal, 20)
                            .padding(.top, 30)
                            .padding(.bottom, 14)
                        FeaturedCarousel(films: store.featured, namespace: zoom)
                    }

                    SectionTitle(eyebrow: "Programme", title: activeDay.map(Paris.title) ?? "Toute la semaine")
                        .padding(.horizontal, 20)
                        .padding(.top, 34)
                        .padding(.bottom, 8)
                        .animation(.snappy, value: activeDay)

                    DayStrip(days: store.days, selection: $day)
                    CinemaChips(cinemas: store.cinemas, selection: $cinema)
                        .padding(.top, 2)

                    Text("\(count) séance\(count > 1 ? "s" : "") · \(films.count) film\(films.count > 1 ? "s" : "")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RV.mist)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .animation(.snappy, value: count)

                    if films.isEmpty {
                        EmptyStateCard(
                            title: "Rien pour ces filtres",
                            message: "Aucune séance VOST ne correspond. Élargis à toute la semaine ?",
                            actionTitle: "Voir toute la semaine"
                        ) {
                            withAnimation(.snappy) { day = nil; cinema = nil }
                        }
                        .padding(.top, 16)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(films) { film in
                                NavigationLink(value: FilmRoute(filmID: film.id, sourceID: "row-\(film.id)", cinemaKey: cinema)) {
                                    MovieRow(film: film, showsDay: activeDay == nil)
                                }
                                .buttonStyle(PressableStyle())
                                .matchedTransitionSource(id: "row-\(film.id)", in: zoom)
                                .scrollTransition(.animated(.smooth)) { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.5)
                                        .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }

                    FooterNote()
                }
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background { RivieraBackground() }
            .overlay(alignment: .top) { TopFade() }
            .refreshable { await store.load(force: true) }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FilmRoute.self) { route in
                FilmDestination(route: route)
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: zoom))
            }
        }
    }
}

/// Resolves a route to the full (unfiltered) film.
struct FilmDestination: View {
    @Environment(ShowtimesStore.self) private var store
    let route: FilmRoute

    var body: some View {
        if let film = store.film(id: route.filmID) {
            MovieDetailView(film: film, initialCinema: route.cinemaKey)
        } else {
            ContentUnavailableView("Film introuvable", systemImage: "film", description: Text("Ce film n’est plus à l’affiche."))
        }
    }
}

struct BrandHeader: View {
    @Environment(ShowtimesStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Eyebrow("Côte d’Azur · VOST")
                Spacer()
                SyncStatus()
            }
            Logotype(size: 68)
                .padding(.top, 10)
            Text("Toutes les séances en version originale — Cannes, Nice, Cagnes, Antibes.")
                .font(.system(size: 16))
                .foregroundStyle(RV.mist)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            HorizonLine().padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct SyncStatus: View {
    @Environment(ShowtimesStore.self) private var store

    var body: some View {
        Group {
            if store.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(RV.mist)
                    Text("Actualisation")
                }
            } else if store.errorMessage != nil {
                Label("Hors ligne", systemImage: "wifi.slash")
                    .foregroundStyle(RV.goldHot)
            } else if let fetchedAt = store.fetchedAt {
                Text(Paris.updatedLabel(fetchedAt))
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(RV.mist)
        .animation(.easeInOut, value: store.isLoading)
    }
}
