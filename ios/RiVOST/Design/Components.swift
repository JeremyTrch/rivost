import SwiftUI

// MARK: - Typography blocks

struct Eyebrow: View {
    let text: String
    var color: Color = RV.gold

    init(_ text: String, color: Color = RV.gold) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(2.6)
            .foregroundStyle(color)
    }
}

struct SectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(eyebrow)
            Text(title)
                .font(.display(28))
                .foregroundStyle(RV.ink)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(eyebrow)
            Text(title)
                .font(.display(48, .medium))
                .tracking(-1)
                .foregroundStyle(RV.ink)
                .padding(.top, 8)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(RV.mist)
                .padding(.top, 4)
            HorizonLine().padding(.top, 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var dot: Color? = nil
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) { action() }
        } label: {
            HStack(spacing: 7) {
                if let dot {
                    Circle().fill(dot).frame(width: 7, height: 7)
                        .shadow(color: dot.opacity(0.8), radius: isOn ? 4 : 0)
                }
                Text(title)
            }
            .font(.system(size: 14, weight: isOn ? .semibold : .medium))
            .foregroundStyle(isOn ? RV.goldHot : RV.fog)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(RV.gold.opacity(0.3)).interactive() : .regular.interactive(), in: .capsule)
    }
}

struct CinemaChips: View {
    let cinemas: [Cinema]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Chip(title: "Tous les cinés", isOn: selection == nil) { selection = nil }
                    ForEach(cinemas) { cinema in
                        Chip(title: cinema.chipName, dot: cinema.tint, isOn: selection == cinema.key) {
                            selection = selection == cinema.key ? nil : cinema.key
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Calendar strip: weekday + day number, the selected day lit in gold.
struct DayStrip: View {
    let days: [String]
    @Binding var selection: String?
    var allowsAll = true

    @Namespace private var namespace

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    if allowsAll { pill(nil) }
                    ForEach(days, id: \.self) { pill($0) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .onChange(of: selection) { _, value in
                withAnimation(.snappy) { proxy.scrollTo(value ?? "all", anchor: .center) }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func pill(_ key: String?) -> some View {
        let isOn = selection == key
        let isToday = key == Paris.dayKey()
        return Button {
            withAnimation(.snappy(duration: 0.35)) { selection = key }
        } label: {
            VStack(spacing: 3) {
                Text(key.map(Paris.weekdayShort) ?? "SEM.")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .opacity(isOn ? 0.8 : 0.7)
                Group {
                    if let key {
                        Text(Paris.dayNumber(key))
                    } else {
                        Image(systemName: "square.grid.3x3.fill").font(.system(size: 15, weight: .semibold))
                            .frame(height: 26)
                    }
                }
                .font(.display(23))
                Circle()
                    .frame(width: 4, height: 4)
                    .opacity(isToday ? 1 : 0)
            }
            .foregroundStyle(isOn ? RV.night : RV.fog)
            .frame(width: 54, height: 74)
            .background {
                if isOn {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(RV.goldGradient)
                        .shadow(color: RV.gold.opacity(0.5), radius: 14, y: 6)
                        .matchedGeometryEffect(id: "selected-day", in: namespace)
                }
            }
            .contentShape(.rect(cornerRadius: 19))
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .identity : .regular.interactive(), in: .rect(cornerRadius: 19, style: .continuous))
        .id(key ?? "all")
        .accessibilityLabel(key.map(Paris.title) ?? "Toute la semaine")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Showtimes

struct RoomBadge: View {
    let label: String

    var body: some View {
        let premium = RoomStyle.isPremium(label)
        Text(label.uppercased())
            .font(.system(size: 9.5, weight: premium ? .heavy : .semibold))
            .tracking(0.7)
            .foregroundStyle(premium ? RV.goldHot : RV.mist)
            .lineLimit(1)
    }
}

/// Tappable showtime → opens the cinema's ticketing page.
struct ShowtimeChip: View {
    let showtime: Showtime
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = showtime.bookingURL { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(showtime.time)
                    .font(.numeral(18))
                    .foregroundStyle(RV.ink)
                RoomBadge(label: showtime.roomLabel)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .frame(minWidth: 74, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(showtime.isPremium ? AnyShapeStyle(LinearGradient(colors: [RV.gold.opacity(0.16), RV.surface2.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(RV.surface2.opacity(0.9)))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(showtime.isPremium ? AnyShapeStyle(LinearGradient(colors: [RV.goldHot.opacity(0.65), RV.gold.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(RV.line), lineWidth: 1)
            }
            .opacity(showtime.hasStarted ? 0.38 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(showtime.bookingURL == nil)
        .accessibilityLabel("\(showtime.time), \(showtime.roomLabel)")
        .accessibilityHint(showtime.bookingURL == nil ? "" : "Ouvre la billetterie")
    }
}

/// Display-only compact time tag used in list rows.
struct TimeTag: View {
    let showtime: Showtime
    var showsDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if showsDay {
                Text(Paris.weekdayShort(showtime.day))
                    .font(.system(size: 8.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(RV.mist)
            }
            Text(showtime.time)
                .font(.numeral(14.5))
                .foregroundStyle(showtime.isPremium ? RV.goldHot : RV.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5.5)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(RV.surface2.opacity(0.95)))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(showtime.isPremium ? RV.gold.opacity(0.4) : RV.line, lineWidth: 1)
        }
    }
}

struct CinemaLabel: View {
    let cinema: Cinema
    var showsCity = true

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(cinema.tint).frame(width: 7, height: 7)
                .shadow(color: cinema.tint.opacity(0.7), radius: 3)
            Text(cinema.shortName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(RV.fog)
            if showsCity {
                Text(cinema.city)
                    .font(.system(size: 13))
                    .foregroundStyle(RV.mist)
            }
        }
    }
}

// MARK: - States

struct EmptyStateCard: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(RV.gold)
            Text(title)
                .font(.display(22))
                .foregroundStyle(RV.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(RV.mist)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.glass)
                    .tint(RV.goldHot)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .card(radius: 26)
        .padding(.horizontal, 16)
    }
}

struct FooterNote: View {
    var body: some View {
        VStack(spacing: 6) {
            HorizonLine().padding(.horizontal, 40).padding(.bottom, 12)
            Text("Horaires indicatifs — vérifie toujours sur le site du cinéma.")
            Text("Données API Cinéma · affiches TMDB et cinémas.")
        }
        .font(.system(size: 12))
        .foregroundStyle(RV.mist.opacity(0.85))
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 36)
    }
}
