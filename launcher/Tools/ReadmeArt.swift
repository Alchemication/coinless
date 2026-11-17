import SwiftUI

// Renders two README images. Run through launcher/Tools/readme-images.sh.
//   then.png    the arcade: one cabinet, one game, empty pockets (original pixel art)
//   before.png  playing MAME from Terminal. The commands and the error are real
//               (the error is MAME 0.289 without qsound_hle.zip).
// Usage: readme-art <then.png> <before.png>

enum Tone { case prompt, command, error, comment, cursor }

let session: [(Tone, String)] = [
    (.command, "cd ~/emu"),
    (.command, "export GAME_NAME=hvnsgate"),
    (.command, "export GAME_PATH=\"$PWD/games/heavens-gate\""),
    (.command, "mame \"${GAME_NAME}\" -rompath \"${GAME_PATH}\" -nowindow -video opengl -filter -keepaspect"),
    (.comment, "# Another game? Set both variables again…"),
    (.command, "export GAME_NAME=dino"),
    (.command, "export GAME_PATH=\"$PWD/games/cadillacs-and-dinosaurs\""),
    (.command, "mame \"${GAME_NAME}\" -rompath \"${GAME_PATH}\" -nowindow -video opengl -filter -keepaspect"),
    (.error, "dl-1425.bin NOT FOUND (tried in qsound_hle qsound dino)"),
    (.error, "Fatal error: Required files are missing, the machine cannot be run."),
    (.comment, "# …the BIOS ZIP was in another folder. And the keys to remember:"),
    (.comment, "#   5 coin · 1 start · Tab menu · P pause · Esc quit (and save settings)"),
    (.comment, "#   Shift+F7 save, then pick a slot · F7 load, then the same slot"),
    (.comment, "#   Option+Return full screen · Fn+F11 speed"),
    (.comment, "# Which slot was my Cadillacs run in again?"),
    (.cursor, ""),
]

struct TerminalWindow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    ForEach(["FF5F57", "FEBC2E", "28C840"], id: \.self) { Circle().fill(color($0)).frame(width: 12, height: 12) }
                    Spacer()
                }
                Text("emu — zsh — 100×24").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(color("2B2B2E"))

            VStack(alignment: .leading, spacing: 5) {
                ForEach(session.indices, id: \.self) { index in line(session[index]) }
            }
            .font(.system(size: 14, design: .monospaced))
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 900)
        .background(color("1C1C1E"))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
        .padding(36)
        .background(color("0C0E12"))
    }

    @ViewBuilder func line(_ entry: (Tone, String)) -> some View {
        let (tone, text) = entry
        switch tone {
        case .error:
            Text(text).foregroundStyle(color("FF6B6B"))
        case .cursor:
            HStack(spacing: 0) { prompt; Rectangle().fill(.white.opacity(0.8)).frame(width: 8, height: 16) }
        default:
            HStack(alignment: .top, spacing: 0) {
                prompt
                Text(text).foregroundStyle(tone == .comment ? color("8E8E93") : .white)
            }
        }
    }

    var prompt: some View { Text("~/emu % ").foregroundStyle(color("B8EA78")) }

}

// MARK: The arcade, in pixels

/// A child at one arcade cabinet, pockets turned out, while the game counts down to GAME OVER.
struct ArcadeScene: View {
    static let grid = CGSize(width: 200, height: 112)
    static let pixel: CGFloat = 7

    var body: some View {
        let p = Self.pixel
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in Self.draw(&context) }
                .frame(width: Self.grid.width * p, height: Self.grid.height * p)

            // Neon sign on the wall.
            Text("ARCADE")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .tracking(6)
                .foregroundStyle(color("FF7AD9"))
                .shadow(color: color("FF3FB4"), radius: 12)
                .shadow(color: color("FF3FB4"), radius: 4)
                .position(x: 36 * p, y: 9 * p)

            // The marquee and the screen of the one game in front of us.
            Text("★ COIN-OP ★")
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundStyle(color("5A1A0E"))
                .position(x: 94 * p, y: 15 * p)
            VStack(spacing: 2) {
                Text("CONTINUE?").font(.system(size: 20, weight: .black, design: .monospaced)).foregroundStyle(color("FF6B6B"))
                Text("9").font(.system(size: 64, weight: .black, design: .monospaced)).foregroundStyle(color("FFD34E"))
                    .shadow(color: color("FF9F43"), radius: 10)
                Text("INSERT COIN").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
            }
            .position(x: 94 * p, y: 34.5 * p)
            Text("25¢").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(color("FFB35C"))
                .position(x: 94 * p, y: 77 * p)

            // The question every player asked.
            Text("?").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(.white)
                .position(x: 124 * p, y: 45 * p)
        }
        .frame(width: Self.grid.width * p, height: Self.grid.height * p)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    static func draw(_ context: inout GraphicsContext) {
        let p = pixel
        func px(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ hex: String, _ alpha: Double = 1) {
            context.fill(Path(CGRect(x: x * p, y: y * p, width: w * p, height: h * p)), with: .color(color(hex).opacity(alpha)))
        }

        // Room: wall, a neon strip, and the classic cosmic carpet.
        context.fill(Path(CGRect(x: 0, y: 0, width: grid.width * p, height: 86 * p)),
                     with: .linearGradient(Gradient(colors: [color("120A22"), color("261845")]),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: 86 * p)))
        px(0, 21, 200, 1, "7B4DFF", 0.55)
        px(0, 86, 200, 26, "100E24")
        var seed: UInt64 = 7
        for _ in 0..<170 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = Double((seed >> 33) % 200), y = 87 + Double((seed >> 17) % 25)
            px(x, y, 1, 1, ["2DE2E6", "FF3FB4", "FFD34E", "7B4DFF"][Int(seed % 4)], 0.55)
        }

        // Neighbouring cabinets, switched off: tonight there's only one game.
        for x in [10.0, 154.0] {
            px(x, 26, 36, 70, "1A1332")
            px(x + 4, 36, 28, 20, "0B1220")
            px(x - 2, 58, 40, 5, "241A45")
            px(x + 14, 68, 8, 12, "120D24")
        }

        // The cabinet.
        let glow = Gradient(colors: [color("FF9F43").opacity(0.33), .clear])
        context.fill(Path(ellipseIn: CGRect(x: 44 * p, y: 8 * p, width: 100 * p, height: 104 * p)),
                     with: .radialGradient(glow, center: CGPoint(x: 94 * p, y: 40 * p), startRadius: 0, endRadius: 52 * p))
        px(70, 8, 48, 88, "3B2A6E")
        px(70, 8, 2, 88, "5B45A8")
        px(116, 8, 2, 88, "2A1E52")
        px(72, 10, 44, 10, "FFD34E")             // marquee
        px(72, 18, 44, 2, "F0A830")
        px(74, 22, 40, 25, "05060A")             // screen
        px(73, 21, 42, 1, "1E1640"); px(73, 47, 42, 1, "1E1640")
        px(66, 52, 56, 8, "4A3790")              // control panel
        px(66, 52, 56, 1, "6E58C8")
        px(80, 51, 1, 3, "9A9AA8")               // joystick
        px(79, 48, 3, 3, "E2504F"); px(79, 48, 1, 1, "FF9A9A")
        for (x, hex) in [(92.0, "E2504F"), (97.0, "FFD34E"), (102.0, "2DE2E6")] {
            px(x, 54, 3, 2, hex); px(x, 54, 1, 1, "FFFFFF", 0.5)
        }
        px(72, 60, 44, 36, "2F235C")             // lower cabinet
        px(86, 65, 16, 19, "1A1530")             // coin door
        px(86, 65, 16, 1, "6B5BB0"); px(86, 83, 16, 1, "6B5BB0")
        for x in [89.0, 97.0] {                  // lit coin slots
            px(x - 1, 67, 4, 8, "FF9F43", 0.25)
            px(x, 68, 2, 6, "FF9F43")
            px(x + 0.5, 69, 1, 4, "3A1A00")
        }
        px(92, 80.5, 4, 2, "0A0814")             // coin return
        px(70, 96, 48, 2, "171030")              // kick plate

        // A child, seen from behind, both pockets pulled inside out.
        let kx = 106.0, ky = 50.0
        func kid(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ hex: String) { px(kx + x, ky + y, w, h, hex) }
        context.fill(Path(ellipseIn: CGRect(x: (kx - 2) * p, y: (ky + 43) * p, width: 20 * p, height: 4 * p)), with: .color(.black.opacity(0.45)))
        kid(5, 0, 6, 1, "3B2416"); kid(4, 1, 8, 1, "3B2416"); kid(3, 2, 10, 5, "3B2416")   // hair
        kid(2, 4, 1, 2, "F1C27D"); kid(13, 4, 1, 2, "F1C27D")                               // ears
        kid(6, 7, 4, 1, "E0AC69")                                                            // neck
        kid(1, 8, 14, 15, "E2504F")                                                          // T-shirt
        for row in [11.0, 15.0, 19.0] { kid(1, row, 14, 1, "F3F0E8") }
        kid(-1, 9, 2, 12, "E2504F"); kid(15, 9, 2, 12, "E2504F")                            // sleeves and arms
        kid(-1, 13, 2, 7, "F1C27D"); kid(15, 13, 2, 7, "F1C27D")
        kid(2, 23, 12, 1, "4A2A12")                                                          // belt
        kid(2, 24, 12, 9, "3D6BB3")                                                          // jeans
        kid(2, 33, 5, 9, "3D6BB3"); kid(9, 33, 5, 9, "3D6BB3")
        kid(7, 30, 2, 3, "2E5596")
        for (x, step) in [(0.0, -1.0), (14.0, 1.0)] {                                         // empty pockets
            kid(x, 24, 2, 1, "F5F5F5"); kid(x + step, 25, 2, 2, "F5F5F5"); kid(x + 2 * step, 27, 2, 2, "F5F5F5")
            kid(x + 2 * step, 28, 2, 1, "CFCFCF")
        }
        kid(1, 42, 6, 2, "F5F5F5"); kid(9, 42, 6, 2, "F5F5F5")                              // sneakers
        kid(1, 43, 6, 1, "E2504F"); kid(9, 43, 6, 1, "E2504F")

        // A moth escapes the empty pocket.
        px(128, 62, 1, 1, "C9C2B8", 0.6); px(130, 60, 1, 1, "C9C2B8", 0.8)
        px(132, 57, 3, 2, "C9C2B8"); px(133, 56, 1, 1, "8E877C")

        // The last coin, rolling away under the next machine.
        px(141, 99, 1, 1, "FFFFFF", 0.35); px(138, 99, 2, 1, "FFFFFF", 0.25)
        px(144, 98, 3, 3, "FFD34E"); px(144, 98, 1, 1, "FFF5C2"); px(146, 100, 1, 1, "C9971E")
    }
}

func color(_ hex: String) -> Color {
    let value = UInt64(hex, radix: 16) ?? 0
    return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
}

@MainActor func render<V: View>(_ view: V, to path: String) {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    renderer.scale = 2
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(1) }
    do { try png.write(to: URL(fileURLWithPath: path)) } catch { print(error); exit(1) }
}

MainActor.assumeIsolated {
    render(ArcadeScene(), to: CommandLine.arguments[1])
    render(TerminalWindow(), to: CommandLine.arguments[2])
}
