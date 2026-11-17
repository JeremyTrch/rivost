// Renders the RiVOST app icon (1024×1024, opaque PNG).
// Usage: swift ios/Tools/make-icon.swift ios/RiVOST/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import AppKit
import SwiftUI

func c(_ hex: UInt32, _ opacity: Double = 1) -> Color {
    Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
}

struct Icon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let horizon = h * 0.6
            let sunR = w * 0.21

            // Night sky warming toward the horizon
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: horizon)), with: .linearGradient(
                Gradient(stops: [
                    .init(color: c(0x050B13), location: 0),
                    .init(color: c(0x0C1D2B), location: 0.55),
                    .init(color: c(0x46301D), location: 1),
                ]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))

            // A few stars
            let stars: [(CGFloat, CGFloat, CGFloat)] = [(0.18, 0.14, 4), (0.32, 0.24, 2.5), (0.74, 0.12, 3.5), (0.86, 0.3, 2.5), (0.62, 0.2, 2), (0.1, 0.34, 2)]
            for (x, y, r) in stars {
                ctx.fill(Path(ellipseIn: CGRect(x: w * x - r, y: h * y - r, width: r * 2, height: r * 2)), with: .color(c(0xF4EFE6, 0.55)))
            }

            // Glow
            ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - w * 0.46, y: horizon - w * 0.46, width: w * 0.92, height: w * 0.92)),
                     with: .radialGradient(Gradient(colors: [c(0xF0C57A, 0.5), c(0xF0C57A, 0)]),
                                           center: CGPoint(x: w / 2, y: horizon), startRadius: 0, endRadius: w * 0.46))

            // Setting sun
            var sky = ctx
            sky.clip(to: Path(CGRect(x: 0, y: 0, width: w, height: horizon)))
            sky.fill(Path(ellipseIn: CGRect(x: w / 2 - sunR, y: horizon - sunR, width: sunR * 2, height: sunR * 2)),
                     with: .linearGradient(Gradient(colors: [c(0xFFE7B3), c(0xF0C57A), c(0xD4A45A)]),
                                           startPoint: CGPoint(x: w / 2, y: horizon - sunR), endPoint: CGPoint(x: w / 2, y: horizon)))

            // Sea
            ctx.fill(Path(CGRect(x: 0, y: horizon, width: w, height: h - horizon)), with: .linearGradient(
                Gradient(colors: [c(0x0F4351), c(0x081018)]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: h)))

            // Reflection
            var y = horizon + h * 0.03
            for i in 0..<6 {
                let t = CGFloat(i)
                let half = w * 0.2 * (1 - t / 7)
                let thick = h * 0.012 * (1 - t / 9)
                ctx.fill(Path(roundedRect: CGRect(x: w / 2 - half, y: y, width: half * 2, height: thick), cornerRadius: thick / 2),
                         with: .color(c(0xF0C57A, 0.8 - Double(i) * 0.11)))
                y += h * 0.04 * (1 + t * 0.18)
            }

            // Horizon line
            ctx.fill(Path(CGRect(x: 0, y: horizon - 2, width: w, height: 4)), with: .linearGradient(
                Gradient(colors: [c(0xF0C57A, 0), c(0xF0C57A, 0.95), c(0xF0C57A, 0)]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: 0)))
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor func render() throws {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    guard let image = renderer.cgImage else { fatalError("render failed") }

    // Flatten onto an opaque bitmap (App Store icons must not have alpha).
    let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("wrote \(CommandLine.arguments[1])")
}

try MainActor.assumeIsolated { try render() }
