import SwiftUI

struct FeaturedCarousel: View {
    let films: [Film]
    let namespace: Namespace.ID

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(films) { film in
                    NavigationLink(value: FilmRoute(filmID: film.id, sourceID: "hero-\(film.id)")) {
                        FeaturedCard(film: film)
                    }
                    .buttonStyle(PressableStyle())
                    .matchedTransitionSource(id: "hero-\(film.id)", in: namespace) { source in
                        source.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                    .containerRelativeFrame(.horizontal) { width, _ in width * 0.7 }
                    .scrollTransition(axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.9)
                            .opacity(phase.isIdentity ? 1 : 0.6)
                            .rotation3DEffect(.degrees(phase.value * -10), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

struct FeaturedCard: View {
    let film: Film

    var body: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { MoviePoster(movie: film.movie) }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.28),
                        .init(color: RV.night.opacity(0.5), location: 0.5),
                        .init(color: RV.night.opacity(0.88), location: 0.72),
                        .init(color: RV.night.opacity(0.98), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    if let next = film.nextShowtime {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle").font(.system(size: 10, weight: .bold))
                            Text("\(Paris.when(next)) · \(next.time)")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RV.goldHot)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(RV.night.opacity(0.3)), in: .capsule)
                    }
                    Text(film.movie.title)
                        .font(.display(25))
                        .foregroundStyle(RV.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.5), radius: 8)
                    Text("\(film.showtimes.count.counted("séance")) · \(film.cinemas.map(\.chipName).joined(separator: ", "))")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(RV.fog.opacity(0.9))
                        .lineLimit(1)
                }
                .padding(16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 24, y: 16)
    }
}
