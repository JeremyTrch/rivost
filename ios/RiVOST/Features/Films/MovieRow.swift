import SwiftUI

struct MovieRow: View {
    let film: Film
    var showsDay = false

    private var tags: [Showtime] {
        let upcoming = film.upcoming
        return Array((upcoming.isEmpty ? film.showtimes : upcoming).prefix(4))
    }

    private var overflow: Int {
        (film.upcoming.isEmpty ? film.showtimes.count : film.upcoming.count) - tags.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            PosterView(movie: film.movie, cornerRadius: 11)
                .frame(width: 94, height: 141)

            VStack(alignment: .leading, spacing: 0) {
                Text(film.movie.title)
                    .font(.display(21))
                    .foregroundStyle(RV.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !film.movie.metaLine.isEmpty {
                    Text(film.movie.metaLine)
                        .font(.system(size: 13))
                        .foregroundStyle(RV.mist)
                        .lineLimit(1)
                        .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    ForEach(film.cinemas) { cinema in
                        HStack(spacing: 5) {
                            Circle().fill(cinema.tint).frame(width: 6, height: 6)
                            Text(cinema.chipName)
                        }
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RV.fog.opacity(0.85))
                .lineLimit(1)
                .padding(.top, 9)

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    ForEach(tags) { TimeTag(showtime: $0, showsDay: showsDay) }
                    if overflow > 0 {
                        Text("+\(overflow)")
                            .font(.numeral(13))
                            .foregroundStyle(RV.mist)
                            .padding(.leading, 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 141, alignment: .topLeading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RV.mist.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(12)
        .card(radius: 24)
        .contentShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityHint("\(film.showtimes.count.counted("séance"))")
    }
}
