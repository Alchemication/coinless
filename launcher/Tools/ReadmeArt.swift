import SwiftUI

// Renders docs/images/before.png: playing MAME from Terminal, the way it was before Coinless.
// The commands and the error are real (the error is MAME 0.289 without qsound_hle.zip).
// Usage: readme-art <output.png>. Run through launcher/Tools/readme-images.sh.

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

    func color(_ hex: String) -> Color {
        let value = UInt64(hex, radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: TerminalWindow().environment(\.colorScheme, .dark))
    renderer.scale = 2
    guard let image = renderer.cgImage,
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { exit(1) }
    do { try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1])) } catch { print(error); exit(1) }
}
