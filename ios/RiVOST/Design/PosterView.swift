import SwiftUI
import UIKit

/// Tiny in-memory image pipeline: dedupes requests, retries flaky networks, keeps decoded posters while scrolling.
final class ImagePipeline {
    static let shared = ImagePipeline()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["Accept": "image/avif,image/webp,image/*;q=0.9,*/*;q=0.5"]
        return URLSession(configuration: config)
    }()

    init() { cache.countLimit = 250 }

    func cached(_ url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func cached(_ urls: [URL]) -> UIImage? { urls.lazy.compactMap(cached).first }

    /// First URL in the list that yields an image.
    func image(for urls: [URL]) async -> UIImage? {
        for url in urls {
            if let image = await image(for: url) { return image }
        }
        return nil
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let task = inFlight[url] { return await task.value }

        let session = session
        let task = Task<UIImage?, Never> {
            // Up to 3 attempts for transient failures (timeouts, 5xx); a 4xx or non-image is final.
            for attempt in 0..<3 {
                if attempt > 0 { try? await Task.sleep(for: .milliseconds(400 * attempt * attempt)) }
                guard !Task.isCancelled else { return nil }
                do {
                    let (data, response) = try await session.data(from: url)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                    if (500..<600).contains(status) { continue }
                    guard (200..<300).contains(status), let image = UIImage(data: data) else { return nil }
                    return await image.byPreparingForDisplay() ?? image
                } catch {
                    continue
                }
            }
            return nil
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }
}

/// Fills its frame with the first remote image that loads (aspect-fill). While loading it shimmers;
/// if every source fails it shows `fallback` — never an empty box.
struct RemoteImage<Fallback: View>: View {
    let urls: [URL]
    let fallback: Fallback

    @State private var image: UIImage?
    @State private var failed = false

    init(urls: [URL], @ViewBuilder fallback: () -> Fallback) {
        self.urls = urls
        self.fallback = fallback()
        _image = State(initialValue: ImagePipeline.shared.cached(urls))
    }

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if failed || urls.isEmpty {
                    fallback.transition(.opacity)
                } else {
                    Rectangle()
                        .fill(RV.surface2)
                        .phaseAnimator([0.45, 0.85]) { view, phase in
                            view.opacity(phase)
                        } animation: { _ in .easeInOut(duration: 0.9) }
                }
            }
            .clipped()
            .task(id: urls) {
                guard image == nil, !urls.isEmpty else { return }
                failed = false
                let loaded = await ImagePipeline.shared.image(for: urls)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    if let loaded { image = loaded } else { failed = true }
                }
            }
    }
}

/// A film's poster: the real one when any source loads, otherwise a designed poster made from its title.
struct MoviePoster: View {
    let movie: Movie

    var body: some View {
        RemoteImage(urls: movie.posterURLs) {
            GeneratedPoster(movie: movie)
        }
    }
}

/// Typographic poster drawn on device so a film is never shown without an affiche.
/// The palette and motif are derived from the title, so each film keeps the same look everywhere.
struct GeneratedPoster: View {
    let movie: Movie

    private struct Palette {
        let top: Color, bottom: Color, accent: Color
    }

    private static let palettes: [Palette] = [
        Palette(top: Color(hex: 0x3B2A1C), bottom: Color(hex: 0x0B121B), accent: Color(hex: 0xF0C57A)), // dusk gold
        Palette(top: Color(hex: 0x0F4A57), bottom: Color(hex: 0x061018), accent: Color(hex: 0x8FE3E8)), // Riviera sea
        Palette(top: Color(hex: 0x5A1F2E), bottom: Color(hex: 0x10080E), accent: Color(hex: 0xF29C9C)), // rouge cinéma
        Palette(top: Color(hex: 0x2E2457), bottom: Color(hex: 0x0A0816), accent: Color(hex: 0xC8B6FF)), // nuit violette
        Palette(top: Color(hex: 0x24452F), bottom: Color(hex: 0x07110B), accent: Color(hex: 0xD9E7A0)), // pinède
        Palette(top: Color(hex: 0x1D3557), bottom: Color(hex: 0x070B14), accent: Color(hex: 0xA8C8FF)), // bleu Klein
    ]

    /// FNV-1a over the title: stable across launches (Swift's hashValue is seeded per process) and well spread.
    private var seed: Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in movie.title.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return Int(truncatingIfNeeded: (hash ^ (hash >> 29)) & 0x7FFF_FFFF)
    }

    private var palette: Palette { Self.palettes[seed % Self.palettes.count] }

    private var credit: String {
        [movie.director, movie.year.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let p = palette
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [p.top, p.bottom], startPoint: .top, endPoint: .bottom)

                motif(w: w, h: h, accent: p.accent)

                Image(uiImage: Grain.image)
                    .resizable(resizingMode: .tile)
                    .blendMode(.overlay)
                    .opacity(0.12)

                // Inner frame, like a printed one-sheet.
                RoundedRectangle(cornerRadius: max(2, w * 0.02), style: .continuous)
                    .strokeBorder(p.accent.opacity(0.35), lineWidth: max(0.5, w * 0.006))
                    .padding(w * 0.045)

                VStack(alignment: .leading, spacing: 0) {
                    Text("VOST")
                        .font(.system(size: max(6, w * 0.05), weight: .heavy))
                        .tracking(w * 0.012)
                        .foregroundStyle(p.accent.opacity(0.9))
                    Spacer(minLength: 0)
                    Text(movie.title)
                        .font(.system(size: max(9, w * 0.13), weight: .bold, design: .serif))
                        .foregroundStyle(RV.ink)
                        .lineLimit(4)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.4), radius: w * 0.02)
                    if !credit.isEmpty, w > 90 {
                        Text(credit.uppercased())
                            .font(.system(size: max(6, w * 0.042), weight: .semibold))
                            .tracking(w * 0.006)
                            .foregroundStyle(p.accent.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.top, w * 0.03)
                    }
                }
                .padding(w * 0.1)
                .frame(width: w, height: h, alignment: .topLeading)
            }
            .frame(width: w, height: h)
        }
        .accessibilityElement()
        .accessibilityLabel("Affiche — \(movie.title)")
    }

    @ViewBuilder
    private func motif(w: CGFloat, h: CGFloat, accent: Color) -> some View {
        switch (seed / 7) % 3 {
        case 0: // setting sun with sea stripes
            Canvas { ctx, _ in
                let r = w * 0.3, cx = w * 0.5, cy = h * 0.42
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 2, y: cy - r * 2, width: r * 4, height: r * 4)),
                         with: .radialGradient(Gradient(colors: [accent.opacity(0.35), .clear]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r * 2))
                var sky = ctx
                sky.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: cy + r * 0.25)))
                sky.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                         with: .linearGradient(Gradient(colors: [RV.sun, accent]), startPoint: CGPoint(x: cx, y: cy - r), endPoint: CGPoint(x: cx, y: cy + r)))
                var y = cy + r * 0.38
                for i in 0..<5 {
                    let half = r * (0.95 - CGFloat(i) * 0.16)
                    let thick = max(1, h * 0.008)
                    ctx.fill(Path(roundedRect: CGRect(x: cx - half, y: y, width: half * 2, height: thick), cornerRadius: thick / 2),
                             with: .color(accent.opacity(0.7 - Double(i) * 0.12)))
                    y += h * 0.028
                }
            }
        case 1: // concentric arcs, like a projector beam
            Canvas { ctx, _ in
                let center = CGPoint(x: w * 0.82, y: h * 0.18)
                for i in 0..<7 {
                    let r = w * (0.18 + CGFloat(i) * 0.14)
                    ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                               with: .color(accent.opacity(0.55 - Double(i) * 0.065)), lineWidth: max(0.8, w * 0.012))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - w * 0.09, y: center.y - w * 0.09, width: w * 0.18, height: w * 0.18)),
                         with: .color(accent.opacity(0.9)))
            }
        default: // diagonal film-strip bands
            Canvas { ctx, _ in
                var band = ctx
                band.rotate(by: .degrees(-24))
                for i in 0..<4 {
                    let y = h * (0.12 + CGFloat(i) * 0.11)
                    band.fill(Path(CGRect(x: -w, y: y, width: w * 3, height: h * 0.05)),
                              with: .color(accent.opacity(0.42 - Double(i) * 0.08)))
                }
            }
        }
    }
}

/// Framed poster with a glass sheen and soft shadow (sized by its parent frame).
struct PosterView: View {
    let movie: Movie
    var cornerRadius: CGFloat = 12
    var shadow: Bool = true

    var body: some View {
        MoviePoster(movie: movie)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.14), .clear], startPoint: .topLeading, endPoint: UnitPoint(x: 0.5, y: 0.4)))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            }
            .shadow(color: .black.opacity(shadow ? 0.55 : 0), radius: 16, y: 10)
    }
}
