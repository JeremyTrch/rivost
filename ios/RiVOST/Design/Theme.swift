import SwiftUI
import UIKit

/// RiVOST palette — "Riviera night": deep sea navy, warm lamp gold.
enum RV {
    static let night = Color(hex: 0x081018)
    static let surface = Color(hex: 0x101822)
    static let surface2 = Color(hex: 0x16202C)
    static let ink = Color(hex: 0xF4EFE6)
    static let mist = Color(hex: 0x8B9AAB)
    static let fog = Color(hex: 0xC5D0DB)
    static let gold = Color(hex: 0xD4A45A)
    static let goldHot = Color(hex: 0xF0C57A)
    static let sun = Color(hex: 0xFFE3A8)
    static let sea = Color(hex: 0x1C6B7A)
    static let seaDeep = Color(hex: 0x0D3A48)
    static let dusk = Color(hex: 0x5C3A18)
    static let line = Color(hex: 0xF4EFE6, opacity: 0.11)

    static let goldGradient = LinearGradient(
        colors: [sun, goldHot, gold],
        startPoint: .top,
        endPoint: .bottom
    )
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension Font {
    /// Editorial serif (New York) — the app's display voice, echoing Fraunces on the web.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func numeral(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: - Background

struct RivieraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x071018), Color(hex: 0x0A121C), Color(hex: 0x0C1520)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(colors: [RV.sea.opacity(0.42), .clear], center: UnitPoint(x: 0.5, y: -0.12), startRadius: 0, endRadius: 540)
            RadialGradient(colors: [RV.dusk.opacity(0.36), .clear], center: UnitPoint(x: 1.08, y: 0.06), startRadius: 0, endRadius: 380)
            RadialGradient(colors: [RV.seaDeep.opacity(0.5), .clear], center: UnitPoint(x: -0.15, y: 0.5), startRadius: 0, endRadius: 400)
            Image(uiImage: Grain.image)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.07)
        }
        .ignoresSafeArea()
    }
}

/// Film grain, generated once.
enum Grain {
    static let image: UIImage = {
        let size = 160
        var pixels = [UInt8](repeating: 0, count: size * size)
        for i in pixels.indices { pixels[i] = UInt8.random(in: 0...255) }
        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let cg = CGImage(
                width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
            )
        else { return UIImage() }
        return UIImage(cgImage: cg)
    }()
}

/// Thin gold-to-sea line that breathes slowly, like the horizon at night.
struct HorizonLine: View {
    @State private var glow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LinearGradient(
            colors: [.clear, RV.gold.opacity(0.7), RV.sea.opacity(0.55), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .opacity(glow ? 1 : 0.45)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { glow = true }
        }
    }
}

/// Fades content scrolling under the status bar into the night.
struct TopFade: View {
    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: RV.night.opacity(0.95), location: 0),
                    .init(color: RV.night.opacity(0.7), location: 0.55),
                    .init(color: RV.night.opacity(0), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: proxy.safeAreaInsets.top + 14)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Sunset mark (the app icon, in SwiftUI)

struct SunsetMark: View {
    var risen: CGFloat = 1

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let horizon = h * 0.6
            let sunR = w * 0.21

            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)), with: .linearGradient(
                Gradient(colors: [Color(hex: 0x060D16), Color(hex: 0x0D1E2C), Color(hex: 0x3B2A1C)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

            let sunY = horizon + sunR * (1 - risen) * 1.1
            ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - w * 0.42, y: sunY - w * 0.42, width: w * 0.84, height: w * 0.84)),
                     with: .radialGradient(Gradient(colors: [RV.goldHot.opacity(0.42), .clear]),
                                           center: CGPoint(x: w / 2, y: sunY), startRadius: 0, endRadius: w * 0.42))

            var sky = ctx
            sky.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: horizon)))
            sky.fill(Path(ellipseIn: CGRect(x: w / 2 - sunR, y: sunY - sunR, width: sunR * 2, height: sunR * 2)),
                     with: .linearGradient(Gradient(colors: [RV.sun, RV.goldHot, RV.gold]),
                                           startPoint: CGPoint(x: w / 2, y: sunY - sunR), endPoint: CGPoint(x: w / 2, y: horizon)))

            ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .linearGradient(
                Gradient(colors: [RV.seaDeep, RV.night]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))

            var y = horizon + h * 0.03
            for i in 0..<6 {
                let t = CGFloat(i)
                let half = w * 0.2 * (1 - t / 7) * risen
                let thick = h * 0.011 * (1 - t / 9)
                ctx.fill(Path(roundedRect: CGRect(x: w / 2 - half, y: y, width: half * 2, height: thick), cornerRadius: thick / 2),
                         with: .color(RV.goldHot.opacity(0.75 - Double(i) * 0.1)))
                y += h * 0.038 * (1 + t * 0.18)
            }

            ctx.fill(Path(CGRect(x: 0, y: horizon - h * 0.0015, width: w, height: h * 0.003)), with: .linearGradient(
                Gradient(colors: [.clear, RV.goldHot.opacity(0.9), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: 0)))
        }
    }
}

// MARK: - Interaction

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// Soft card used for list content (glass is reserved for controls).
    func card(radius: CGFloat = 22) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [RV.surface.opacity(0.82), RV.surface.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
        }
    }
}
