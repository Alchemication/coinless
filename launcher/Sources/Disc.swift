import SwiftUI

/// A game shown as a round CRT screen: its preview behind curved glass, scanlines and a bezel.
struct Disc: View {
    let game: Game
    let image: NSImage?
    let selected: Bool
    let saved: Bool
    let diameter: CGFloat
    var marquee: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(game.tint)
                .frame(width: diameter, height: diameter)
                .blur(radius: diameter * 0.14)
                .opacity(selected ? 0.32 : 0)

            CRTScreen(image: image, game: game, diameter: diameter)

            Circle()
                .strokeBorder(game.tint.opacity(selected ? 0.95 : 0.35), lineWidth: selected ? 3 : 1.5)
                .frame(width: diameter + 18, height: diameter + 18)

            if selected, let marquee {
                MarqueeRing(text: marquee, diameter: diameter + 58, color: game.tint)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }

            // Console games say which console; arcade games need no label.
            if let platform = game.platform {
                DiscBadge(text: platform, symbol: "gamecontroller.fill", tint: game.tint)
                    .offset(y: -diameter / 2 + 2)
            }

            if saved {
                DiscBadge(text: "SAVED", symbol: "clock.arrow.circlepath", tint: game.tint)
                    .offset(y: diameter / 2 - 2)
            }
        }
        .frame(width: diameter + 90, height: diameter + 90)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.title + (game.platform.map { ", \($0.capitalized)" } ?? "") + (saved ? ", saved game" : ""))
        .accessibilityAddTraits(.isButton)
    }
}

/// A small label sitting on the disc's bezel: SAVED below, the console above.
struct DiscBadge: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.bezel, in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.6), lineWidth: 1))
    }
}

struct CRTScreen: View {
    let image: NSImage?
    let game: Game
    let diameter: CGFloat

    var body: some View {
        Color.black
            .overlay {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        LinearGradient(colors: [game.tint.opacity(0.6), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: game.symbol)
                            .font(.system(size: diameter * 0.3, weight: .light))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .overlay { Scanlines(spacing: max(3, diameter / 120)).opacity(0.3) }
            // Curved-glass vignette and a soft reflection.
            .overlay {
                RadialGradient(colors: [.clear, .black.opacity(0.7)], center: .center,
                               startRadius: diameter * 0.28, endRadius: diameter * 0.52)
            }
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: diameter * 0.66, height: diameter * 0.3)
                    .offset(x: -diameter * 0.07, y: diameter * 0.06)
                    .blur(radius: 4)
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.bezel, lineWidth: max(6, diameter * 0.035)))
    }
}

/// Monospaced text running around a circle, turning slowly like an arcade marquee.
struct MarqueeRing: View {
    let text: String
    let diameter: CGFloat
    let color: Color
    @State private var spinning = false

    var body: some View {
        let glyphs = Self.glyphs(for: text, circumference: .pi * diameter)
        ZStack {
            ForEach(glyphs.indices, id: \.self) { index in
                Text(String(glyphs[index]))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .offset(y: -diameter / 2)
                    .rotationEffect(.degrees(Double(index) / Double(glyphs.count) * 360))
            }
        }
        .frame(width: diameter + 24, height: diameter + 24)
        .drawingGroup()
        .rotationEffect(.degrees(spinning ? 360 : 0))
        .animation(.linear(duration: 80).repeatForever(autoreverses: false), value: spinning)
        .onAppear { spinning = true }
        .allowsHitTesting(false)
    }

    /// Repeats the text a whole number of times so the ring closes without a gap.
    static func glyphs(for text: String, circumference: CGFloat) -> [Character] {
        let unit = Array(text)
        guard !unit.isEmpty else { return [] }
        let fits = Int(circumference / 10.5)
        let repeats = max(1, Int((Double(fits) / Double(unit.count)).rounded()))
        return Array(repeating: unit, count: repeats).flatMap { $0 }
    }
}

struct Scanlines: View {
    var spacing: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: spacing * 0.45)), with: .color(.black))
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

/// The selected game's picture, blurred to fill the screen behind the carousel.
struct Backdrop: View {
    let image: NSImage?
    let tint: Color
    let id: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.background
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 80, opaque: true)
                        .saturation(1.3)
                        .opacity(0.4)
                        .clipped()
                        .id(id)
                        .transition(.opacity)
                }
                RadialGradient(colors: [tint.opacity(0.2), .clear], center: UnitPoint(x: 0.5, y: 0.42),
                               startRadius: 0, endRadius: geometry.size.width * 0.55)
                LinearGradient(colors: [Theme.background.opacity(0.35), .clear, Theme.background.opacity(0.95)],
                               startPoint: .top, endPoint: .bottom)
                Scanlines(spacing: 4).opacity(0.14)
            }
        }
        .ignoresSafeArea()
    }
}
