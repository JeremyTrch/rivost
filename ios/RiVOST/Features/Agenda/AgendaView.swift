import SwiftUI

struct AgendaView: View {
    @Environment(ShowtimesStore.self) private var store
    @State private var day: String? = Paris.dayKey()
    @State private var cinema: String?
    @State private var showPast = false
    @Namespace private var zoom

    private var activeDay: String? {
        if let day, store.days.contains(day) { return day }
        return store.days.first
    }

    private var daySelection: Binding<String?> {
        Binding(get: { activeDay }, set: { day = $0; showPast = false })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    PageHeader(eyebrow: "Heure par heure", title: "Agenda", subtitle: "Toutes les séances VOST, dans l’ordre.")

                    DayStrip(days: store.days, selection: daySelection, allowsAll: false)
                        .padding(.top, 14)
                    CinemaChips(cinemas: store.cinemas, selection: $cinema)
                        .padding(.top, 2)

                    TimelineView(.everyMinute) { _ in
                        timeline
                    }
                    .padding(.top, 18)

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

    @ViewBuilder
    private var timeline: some View {
        let items = store.filtered(day: activeDay, cinema: cinema)
        let isToday = activeDay == Paris.dayKey()
        let past = isToday ? items.filter(\.hasStarted) : []
        let visible = showPast ? items : items.filter { !isToday || !$0.hasStarted }
        let hours = hourGroups(visible)

        VStack(alignment: .leading, spacing: 18) {
            if !past.isEmpty {
                Button {
                    withAnimation(.snappy) { showPast.toggle() }
                } label: {
                    Label(
                        showPast ? "Masquer les séances passées" : "\(past.count) séance\(past.count > 1 ? "s" : "") déjà commencée\(past.count > 1 ? "s" : "")",
                        systemImage: showPast ? "chevron.up" : "clock.arrow.circlepath"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RV.fog)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.horizontal, 20)
            }

            if isToday && !showPast && !visible.isEmpty {
                NowMarker().padding(.horizontal, 20)
            }

            if visible.isEmpty {
                EmptyStateCard(
                    title: items.isEmpty ? "Pas de séance" : "C’est fini pour aujourd’hui",
                    message: items.isEmpty ? "Aucune séance VOST ce jour-là pour ce filtre." : "Les séances VOST de demain t’attendent.",
                    actionTitle: items.isEmpty ? nil : "Voir demain"
                ) {
                    if let next = store.days.first(where: { $0 > (activeDay ?? "") }) {
                        withAnimation(.snappy) { day = next }
                    }
                }
            } else {
                ForEach(hours, id: \.hour) { group in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 8) {
                            Text("\(group.hour)h")
                                .font(.display(24))
                                .foregroundStyle(RV.goldGradient)
                            Rectangle()
                                .fill(LinearGradient(colors: [RV.gold.opacity(0.45), RV.gold.opacity(0)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 1)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(width: 46)

                        VStack(spacing: 10) {
                            ForEach(group.items) { showtime in
                                AgendaRow(
                                    showtime: showtime,
                                    route: FilmRoute(filmID: showtime.movie.groupKey, sourceID: "agenda-\(showtime.id)", cinemaKey: showtime.cinema.key),
                                    namespace: zoom
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .animation(.snappy, value: activeDay)
        .animation(.snappy, value: cinema)
    }

    private func hourGroups(_ items: [Showtime]) -> [(hour: String, items: [Showtime])] {
        var order: [String] = []
        var buckets: [String: [Showtime]] = [:]
        for st in items {
            let hour = String(st.time.prefix(2))
            if buckets[hour] == nil { order.append(hour) }
            buckets[hour, default: []].append(st)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }
}

struct NowMarker: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(RV.goldHot)
                .frame(width: 8, height: 8)
                .shadow(color: RV.goldHot, radius: 6)
            Text("Maintenant · \(Paris.clock(.now))")
                .font(.system(size: 12, weight: .bold))
                .tracking(1)
                .foregroundStyle(RV.goldHot)
            Rectangle()
                .fill(LinearGradient(colors: [RV.goldHot.opacity(0.6), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
    }
}

struct AgendaRow: View {
    let showtime: Showtime
    let route: FilmRoute
    let namespace: Namespace.ID
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(value: route) {
                HStack(spacing: 12) {
                    PosterView(movie: showtime.movie, cornerRadius: 8, shadow: false)
                        .frame(width: 48, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(showtime.time)
                                .font(.numeral(18, .bold))
                                .foregroundStyle(RV.ink)
                            if let countdown = showtime.countdown {
                                Text(countdown)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(RV.night)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(RV.goldGradient))
                            }
                        }
                        Text(showtime.movie.title)
                            .font(.display(17))
                            .foregroundStyle(RV.ink)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Circle().fill(showtime.cinema.tint).frame(width: 6, height: 6)
                            Text(showtime.cinema.chipName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RV.fog)
                            Text("·").foregroundStyle(RV.mist)
                            RoomBadge(label: showtime.roomLabel)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .matchedTransitionSource(id: route.sourceID, in: namespace)

            if let url = showtime.bookingURL, !showtime.hasStarted {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RV.goldHot)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Réserver \(showtime.movie.title) à \(showtime.time)")
            }
        }
        .padding(10)
        .card(radius: 20)
        .opacity(showtime.hasStarted ? 0.45 : 1)
    }
}
