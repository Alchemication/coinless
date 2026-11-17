import SwiftUI

struct ArcadeView: View {
    @ObservedObject var model: ArcadeModel

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 1100 || geometry.size.height < 760
            let diameter = max(180, min(geometry.size.height * 0.4, geometry.size.width * 0.3, 500))
            ZStack {
                Backdrop(image: model.active.flatMap { model.artwork[$0.id] }, tint: model.active?.tint ?? Theme.accent, id: model.active?.id)
                VStack(spacing: 0) {
                    header
                    if model.games.isEmpty {
                        emptyState
                    } else {
                        Spacer(minLength: 6)
                        Carousel(model: model, diameter: diameter)
                            .frame(height: diameter + 90)
                        ZStack {
                            if let game = model.active {
                                details(game, compact: compact).id(game.id).transition(.opacity)
                            }
                        }
                        .padding(.top, compact ? 10 : 20)
                        Spacer(minLength: 10)
                        PageDots(model: model)
                    }
                    footer.padding(.top, 20)
                }
                .padding(.horizontal, compact ? 28 : 48)
                .padding(.top, 34)
                .padding(.bottom, 24)
            }
        }
        .foregroundStyle(.white)
        .background(Theme.background)
        .overlay {
            if let game = model.running {
                NowPlaying(game: game, image: model.artwork[game.id], tip: model.playingTip).transition(.opacity)
            }
        }
        .sheet(isPresented: $model.help) { HelpView(model: model) }
        .alert(model.notice?.title ?? "", isPresented: Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } }),
               presenting: model.notice) { _ in
            Button("OK", role: .cancel) { model.notice = nil }
        } message: { notice in
            Text(notice.message)
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            HStack(spacing: 10) {
                CoinlessMark(size: 24)
                Text("COINLESS").font(.system(size: 16, weight: .black, design: .monospaced)).tracking(4)
            }
            Spacer()
            if let status = model.previewStatus {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text(status.uppercased())
                }
                .transition(.opacity)
            }
            HStack(spacing: 8) {
                Circle().fill(model.controllerCount > 0 ? Theme.accent : .gray).frame(width: 6, height: 6)
                Text(model.controllerCount > 0 ? "\(model.controllerCount) CONTROLLER\(model.controllerCount == 1 ? "" : "S")" : "KEYBOARD READY")
            }
            Button { model.help.toggle() } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Settings and help (Options or ?)")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .tracking(1)
        .foregroundStyle(.white.opacity(0.62))
        .animation(.easeInOut(duration: 0.25), value: model.previewStatus)
    }

    private func details(_ game: Game, compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            Text([game.genre, game.year, game.players.uppercased()].joined(separator: "  ·  "))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(game.tint)
            Text(game.title)
                .font(.system(size: compact ? 38 : 52, weight: .heavy, design: .rounded))
                .tracking(-1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(model.resumeAvailable ? "Pick up right where you left off." : game.subtitle)
                .font(.system(size: compact ? 14 : 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            HStack(spacing: 12) {
                playButton(game)
                if model.resumeAvailable { newGameButton(game) }
            }
            .padding(.top, compact ? 4 : 8)
            if model.currentFact != nil {
                FactTicker(model: model, tint: game.tint).padding(.top, compact ? 4 : 10)
            } else {
                Text(model.resumeAvailable ? "Quit normally and your place is saved again." : game.note)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private func playButton(_ game: Game) -> some View {
        Button { model.launch() } label: {
            HStack(spacing: 10) {
                Image(systemName: model.resumeAvailable ? "arrow.clockwise" : "play.fill")
                Text(model.resumeAvailable ? "RESUME" : "PLAY").tracking(2)
                KeyCap("✕", onTint: true)
            }
            .font(.system(size: 14, weight: .black))
            .padding(.leading, 26)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
            .foregroundStyle(Theme.ink)
            .background(game.tint, in: Capsule())
            .shadow(color: game.tint.opacity(0.45), radius: 18, y: 6)
        }
        .buttonStyle(PressableStyle())
    }

    private func newGameButton(_ game: Game) -> some View {
        let confirming = model.confirmingFresh == game.id
        return Button { model.newGame() } label: {
            HStack(spacing: 10) {
                Image(systemName: confirming ? "exclamationmark.arrow.circlepath" : "arrow.counterclockwise")
                Text(confirming ? "PRESS AGAIN TO START OVER" : "NEW GAME").tracking(2)
                KeyCap("□", onTint: confirming)
            }
            .font(.system(size: 13, weight: .heavy))
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 12)
            .foregroundStyle(confirming ? Theme.ink : .white)
            .background(confirming ? Theme.caution : .white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(confirming ? 0 : 0.18)))
        }
        .buttonStyle(PressableStyle())
        .help("Start from the beginning. Your previous auto-save is kept as auto.sta.bak.")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your arcade is waiting", systemImage: "gamecontroller")
        } description: {
            Text("Coinless ships no games. Ask your coding agent to “Add Final Fight”,\nor see docs/games.md. Then refresh with R or △.")
        } actions: {
            Button("Open games folder") {
                if let root = model.library?.root { NSWorkspace.shared.open(root.appendingPathComponent("games")) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 22) {
            Hint(keys: "← →", label: "Browse")
            if model.currentFact != nil { Hint(keys: "↑ ↓ L1 R1", label: "Facts") }
            Hint(keys: "✕ ⏎", label: model.resumeAvailable ? "Resume" : "Play")
            if model.resumeAvailable { Hint(keys: "□ N", label: "New game") }
            Hint(keys: "△ R", label: "Refresh")
            Hint(keys: "OPTIONS ?", label: "Settings")
            Spacer()
            Text("\(model.games.count) GAME\(model.games.count == 1 ? "" : "S") · NO MORE CONTINUE? 9… 8… 7…")
                .foregroundStyle(.white.opacity(0.3))
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.5))
    }
}

/// Selected game in the middle, neighbours shrinking away to each side.
struct Carousel: View {
    @ObservedObject var model: ArcadeModel
    let diameter: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(model.games.enumerated()), id: \.element.id) { index, game in
                let distance = index - model.selection
                if abs(distance) <= 3 {
                    Disc(game: game, image: model.artwork[game.id], selected: distance == 0, saved: model.hasResume(game),
                         diameter: diameter, marquee: Self.marquee(game, developer: model.facts[game.id]?.developer))
                        .scaleEffect(Self.scale(distance))
                        .saturation(distance == 0 ? 1 : 0.55)
                        .opacity(Self.opacity(distance))
                        .offset(x: Self.offset(distance) * diameter, y: CGFloat(abs(distance)) * diameter * 0.06)
                        .zIndex(Double(-abs(distance)))
                        .onTapGesture { distance == 0 ? model.launch() : model.select(index) }
                        .help(distance == 0 ? "Play \(game.title)" : game.title)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    static func marquee(_ game: Game, developer: String?) -> String {
        [developer?.uppercased(), game.genre, game.year, "PRESS START"].compactMap { $0 }.joined(separator: " • ") + " • "
    }

    static func scale(_ distance: Int) -> CGFloat { [1, 0.56, 0.4, 0.3][min(abs(distance), 3)] }
    static func opacity(_ distance: Int) -> Double { [1, 0.62, 0.32, 0.12][min(abs(distance), 3)] }
    static func offset(_ distance: Int) -> CGFloat {
        let steps = abs(distance)
        let magnitude: CGFloat = steps == 0 ? 0 : 0.92 + CGFloat(steps - 1) * 0.56
        return distance < 0 ? -magnitude : magnitude
    }
}

struct PageDots: View {
    @ObservedObject var model: ArcadeModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(model.games.enumerated()), id: \.element.id) { index, game in
                Capsule()
                    .fill(index == model.selection ? game.tint : .white.opacity(0.22))
                    .frame(width: index == model.selection ? 24 : 7, height: 7)
                    .contentShape(Rectangle().inset(by: -6))
                    .onTapGesture { model.select(index) }
            }
        }
    }
}

struct NowPlaying: View {
    let game: Game
    let image: NSImage?
    let tip: GameFacts.Fact?

    var body: some View {
        ZStack {
            Backdrop(image: image, tint: game.tint, id: game.id)
            Theme.background.opacity(0.5)
            VStack(spacing: 24) {
                Disc(game: game, image: image, selected: true, saved: false, diameter: 260,
                     marquee: "NOW PLAYING • \(game.title.uppercased()) • ")
                Text("Enjoy the game.").font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Quit MAME to come back here: press Esc, or the controller button you set as UI Cancel.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: 440)
                if let tip {
                    VStack(spacing: 8) {
                        Label(tip.kind.label, systemImage: tip.kind.symbol)
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(game.tint)
                        Text(tip.text)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                    .padding(.top, 8)
                }
            }
        }
    }
}

/// The logo: a coin slot behind a "no" sign, matching the app icon.
struct CoinlessMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: size * 0.16, height: size * 0.5)
            Rectangle()
                .fill(Theme.accent)
                .frame(width: size * 0.12, height: size)
                .rotationEffect(.degrees(-45))
            Circle()
                .strokeBorder(Theme.accent, lineWidth: size * 0.12)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct KeyCap: View {
    let symbol: String
    let onTint: Bool
    init(_ symbol: String, onTint: Bool = false) {
        self.symbol = symbol
        self.onTint = onTint
    }

    var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .frame(minWidth: 22, minHeight: 22)
            .background(Circle().fill(onTint ? Color.black.opacity(0.16) : Color.white.opacity(0.14)))
    }
}

struct Hint: View {
    let keys: String
    let label: String

    var body: some View {
        HStack(spacing: 7) {
            Text(keys).foregroundStyle(.white.opacity(0.85))
            Text(label.uppercased())
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
