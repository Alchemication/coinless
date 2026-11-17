import SwiftUI

/// One entry in launcher/games.json.
struct Game: Codable, Identifiable, Equatable, Sendable {
    /// MAME short name, which is also the game ZIP's name without ".zip".
    let id: String
    /// Folder under games/ that holds the game ZIP.
    let folder: String
    let title: String
    let subtitle: String
    let genre: String
    let year: String
    let players: String
    let symbol: String
    let color: String
    let note: String
    /// Whether the installed MAME driver supports save states (`mame <id> -listxml`).
    let saveStates: Bool
    /// Extra BIOS/device ZIPs MAME needs, without ".zip". Looked up in the game folder and games/bios/.
    let requires: [String]?
    /// Seconds of attract mode to run before capturing the library preview.
    let previewAt: Int?

    var tint: Color { Color(hex: color) }
    var requiredFiles: [String] { requires ?? [] }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex, radix: 16) ?? 0xB8EA78
        self.init(red: Double((value >> 16) & 255) / 255,
                  green: Double((value >> 8) & 255) / 255,
                  blue: Double(value & 255) / 255)
    }
}

enum Theme {
    static let background = Color(hex: "0C0E12")
    static let surface = Color(hex: "191D23")
    static let bezel = Color(hex: "07080A")
    static let accent = Color(hex: "B8EA78")
    static let ink = Color(hex: "111510")
    /// Asks for a second press before something can't be taken back (New game).
    static let caution = Color(hex: "FFB35C")
}

struct ArcadeError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
