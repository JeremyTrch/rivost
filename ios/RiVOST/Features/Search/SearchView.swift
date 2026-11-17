import SwiftUI

struct SearchView: View {
    @Environment(ShowtimesStore.self) private var store
    @State private var query = ""
    @Namespace private var zoom

    private var results: [Film] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return store.allFilms }
        return store.allFilms.filter { $0.movie.matches(q) }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 80)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        Eyebrow(query.isEmpty ? "\(results.count) films en VOST cette semaine" : "\(results.count) résultat\(results.count > 1 ? "s" : "")")
                            .padding(.horizontal, 20)
                            .padding(.top, 4)

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(results) { film in
                                NavigationLink(value: FilmRoute(filmID: film.id, sourceID: "grid-\(film.id)")) {
                                    PosterTile(film: film)
                                }
                                .buttonStyle(PressableStyle())
                                .matchedTransitionSource(id: "grid-\(film.id)", in: zoom)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .background { RivieraBackground() }
            .navigationTitle("Rechercher")
            .searchable(text: $query, prompt: "Film, réalisateur, titre original")
            .navigationDestination(for: FilmRoute.self) { route in
                FilmDestination(route: route)
                    .navigationTransition(.zoom(sourceID: route.sourceID, in: zoom))
            }
        }
    }
}

struct PosterTile: View {
    let film: Film

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { PosterView(movie: film.movie, cornerRadius: 16) }
                .overlay(alignment: .topTrailing) {
                    if let next = film.nextShowtime {
                        Text(next.time)
                            .font(.numeral(12, .bold))
                            .foregroundStyle(RV.goldHot)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(RV.night.opacity(0.4)), in: .capsule)
                            .padding(8)
                    }
                }
            Text(film.movie.title)
                .font(.display(16))
                .foregroundStyle(RV.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text("\(film.showtimes.count.counted("séance")) · \(film.cinemas.map(\.chipName).joined(separator: ", "))")
                .font(.system(size: 12))
                .foregroundStyle(RV.mist)
                .lineLimit(1)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
