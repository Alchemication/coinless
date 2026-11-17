import Foundation

/// Researched facts about a game, in launcher/facts/<id>.json. Written with the game-facts skill.
struct GameFacts: Codable, Sendable {
    struct Fact: Codable, Sendable, Hashable {
        let kind: Kind
        let text: String
        /// Indexes into `sources`.
        let sources: [Int]
    }

    struct Source: Codable, Sendable {
        let title: String
        let url: String?
    }

    enum Kind: String, Codable, Sendable {
        case origin, people, trivia, tip, combo, secret

        var label: String {
            switch self {
            case .origin: "THE STORY"
            case .people: "THE MAKERS"
            case .trivia: "DID YOU KNOW"
            case .tip: "TIP"
            case .combo: "COMBO"
            case .secret: "SECRET"
            }
        }

        var symbol: String {
            switch self {
            case .origin: "book.closed.fill"
            case .people: "person.2.fill"
            case .trivia: "lightbulb.fill"
            case .tip: "gamecontroller.fill"
            case .combo: "bolt.fill"
            case .secret: "lock.open.fill"
            }
        }

        var isAdvice: Bool { self == .tip || self == .combo }
    }

    /// Who made it, shown on the marquee ring.
    let developer: String
    let facts: [Fact]
    let sources: [Source]

    /// Long enough for two lines on the library screen, short enough to read at a glance.
    static let maxLength = 140

    /// Seconds a fact stays up: time to read it, plus a beat.
    static func readingTime(_ text: String) -> Double {
        let words = Double(text.split(separator: " ").count)
        return min(max(3 + words * 0.36, 7), 14)
    }
}

extension Library {
    func factsFile(_ game: Game) -> URL { root.appendingPathComponent("launcher/facts/\(game.id).json") }

    /// Nil when the game has no facts file yet; throws when the file is invalid.
    func loadFacts(_ game: Game) throws -> GameFacts? {
        let file = factsFile(game)
        guard Self.exists(file) else { return nil }
        let facts: GameFacts
        do { facts = try JSONDecoder().decode(GameFacts.self, from: Data(contentsOf: file)) }
        catch { throw ArcadeError("launcher/facts/\(game.id).json couldn't be read: \(error.localizedDescription)") }
        guard !facts.facts.isEmpty else { throw ArcadeError("launcher/facts/\(game.id).json has no facts.") }
        for (index, fact) in facts.facts.enumerated() {
            if fact.text.count > GameFacts.maxLength {
                throw ArcadeError("Fact #\(index + 1) for \(game.title) is \(fact.text.count) characters; keep it under \(GameFacts.maxLength).")
            }
            if fact.sources.isEmpty || fact.sources.contains(where: { !facts.sources.indices.contains($0) }) {
                throw ArcadeError("Fact #\(index + 1) for \(game.title) needs sources that exist in its sources list.")
            }
        }
        return facts
    }
}
