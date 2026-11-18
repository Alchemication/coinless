import AVFoundation
import Foundation

/// Terminal commands, used by ./play in the project root.
enum CLI {
    static let commands: Set<String> = ["--check", "--list", "--play", "--previews", "--facts", "--inspect", "--sounds", "--help", "-h"]

    static let usage = """
    Usage: ./play [game] [options]

      ./play                    List games and whether they're ready to play
      ./play dino               Play a game with the Coinless app's settings
      ./play cad                Names can be shortened, or use the folder name
      ./play --check            Check MAME, games.json, and the installed games
      ./play --previews         Capture missing library pictures now
      ./play --facts dino       Every fact about a game, with sources
      ./play --sounds           Hear the interface sounds and the music themes
      ./play --inspect "final fight"
                                What MAME needs to run a game, and a games.json entry to start from

    Options when playing:
      --window, --fullscreen    Override the full-screen setting
      --fresh                   Start from the beginning (auto.sta is kept as auto.sta.bak)
      --no-save                 Don't resume or save this session
      --style smooth|sharp|crt  Display style
      --dry-run                 Show the MAME command without running it

    In a game: 5 adds a coin, 1 starts, Tab opens MAME's menu, Esc quits and saves.
    """

    static func run(_ arguments: [String]) -> Int32 {
        do {
            switch arguments[0] {
            case "--check": return try check()
            case "--list": return try list()
            case "--play": return try play(Array(arguments.dropFirst()))
            case "--previews": return try previews()
            case "--facts": return try facts(Array(arguments.dropFirst()))
            case "--inspect": return try inspect(arguments.dropFirst().joined(separator: " "))
            case "--sounds": return try sounds()
            default: print(usage); return 0
            }
        } catch {
            fputs(style("error: ", .red) + error.localizedDescription + "\n", stderr)
            return 1
        }
    }

    // MARK: Commands

    static func list() throws -> Int32 {
        let library = try Library()
        let idWidth = (library.catalog.map(\.id.count).max() ?? 8) + 2
        let titleWidth = (library.catalog.map(\.title.count).max() ?? 20) + 2
        print(style("Coinless", .bold) + style("  (\(library.root.path))", .dim) + "\n")
        for game in library.catalog {
            let status: String
            let missing = library.missingFiles(game)
            if !library.isInstalled(game) {
                status = style("not installed: add games/\(game.folder)/\(game.id).zip", .dim)
            } else if !missing.isEmpty {
                status = style("needs " + missing.map { $0 + ".zip" }.joined(separator: ", "), .yellow)
            } else if library.resumeSlot(game) != nil {
                status = style("ready", .green) + " · saved game"
            } else {
                status = style("ready", .green)
            }
            print("  " + style(pad(game.id, idWidth), .bold) + pad(game.title, titleWidth) + status)
        }
        if Library.mameURL() == nil { print("\n" + style("MAME isn't installed. Run: brew install mame", .yellow)) }
        print("\nPlay with " + style("./play <name>", .bold) + ". More options: ./play --help")
        return 0
    }

    static func play(_ arguments: [String]) throws -> Int32 {
        guard let query = arguments.first, !query.hasPrefix("-") else { print(usage); return 64 }
        let library = try Library()
        let game = try find(query, in: library.catalog)

        var fullscreen = Preferences.fullscreen
        var displayStyle = Preferences.displayStyle
        var mode: LaunchMode = Preferences.autoResume ? .resume : .noSave
        var dryRun = false
        var options = arguments.dropFirst().makeIterator()
        while let option = options.next() {
            switch option {
            case "--window": fullscreen = false
            case "--fullscreen": fullscreen = true
            case "--fresh": mode = .fresh
            case "--no-save": mode = .noSave
            case "--dry-run": dryRun = true
            case "--style":
                guard let value = options.next(), let chosen = DisplayStyle(rawValue: value) else {
                    throw ArcadeError("--style needs smooth, sharp or crt.")
                }
                displayStyle = chosen
            default: throw ArcadeError("Unknown option \(option). See ./play --help.")
            }
        }

        guard library.isInstalled(game) else {
            throw ArcadeError("\(game.title) isn't installed. Put \(game.id).zip in games/\(game.folder)/.")
        }
        let missing = library.missingFiles(game)
        guard missing.isEmpty else {
            throw ArcadeError("\(game.title) also needs \(missing.map { $0 + ".zip" }.joined(separator: ", ")) in games/\(game.folder)/ or games/bios/.")
        }
        guard let mame = Library.mameURL() else { throw ArcadeError("MAME isn't installed. Run: brew install mame") }

        let resuming = mode == .resume && library.resumeSlot(game) != nil
        let arguments = library.arguments(game, fullscreen: fullscreen, mode: mode, style: displayStyle, mame: mame)
        print(style("▶ \(game.title)", .bold) + (resuming ? " · resuming your saved game" : mode == .fresh ? " · starting fresh" : ""))
        print(style("  cd " + Library.shellQuoted([library.root.path]) + " && " + Library.shellQuoted(["mame"] + arguments), .dim))
        if let fact = try? library.loadFacts(game)?.facts.randomElement() {
            print(style("  \(fact.kind.label.capitalized): ", .bold) + fact.text)
        }
        if dryRun { return 0 }
        if mode == .fresh, try library.setAsideAutosave(game) {
            print(style("  Previous auto-save kept as sta/\(game.id)/auto.sta.bak", .dim))
        }
        Preferences.lastGame = game.id
        fflush(stdout)

        // Replace this process with MAME so the Terminal behaves exactly as if you'd typed the command.
        FileManager.default.changeCurrentDirectoryPath(library.root.path)
        let argv: [UnsafeMutablePointer<CChar>?] = ([mame.path] + arguments).map { strdup($0) } + [nil]
        execv(mame.path, argv)
        throw ArcadeError("Couldn't start MAME: \(String(cString: strerror(errno)))")
    }

    static func check() throws -> Int32 {
        let library = try Library()
        print("Project: \(library.root.path)")
        guard Library.exists(library.gamesFolder) else { throw ArcadeError("The project's games folder wasn't found.") }
        guard let mame = Library.mameURL() else { throw ArcadeError("MAME executable not found. Run: brew install mame") }
        print("MAME: \(mame.path)" + (Library.shareFolder(for: mame) == nil ? " (CRT style unavailable: bgfx files not found)" : ""))
        let games = library.games
        guard !games.isEmpty else { throw ArcadeError("No installed games found under games/.") }

        var warnings = 0
        for game in games {
            try verifyArguments(game, library: library, mame: mame)
            var notes: [String] = []
            let missing = library.missingFiles(game)
            if !missing.isEmpty { notes.append("missing " + missing.map { $0 + ".zip" }.joined(separator: ", ")) }
            do {
                if try library.loadFacts(game) == nil { notes.append("no facts yet (game-facts skill)") }
            } catch { notes.append(error.localizedDescription) }
            if let info = MachineInfo.load(game.id, mame: mame) {
                if info.saveStates != game.saveStates {
                    notes.append("games.json says saveStates: \(game.saveStates), but MAME reports \(info.saveStates ? "supported" : "unsupported")")
                }
                if Set(info.requires) != Set(game.requiredFiles) {
                    notes.append("games.json requires \(game.requiredFiles), but MAME needs \(info.requires)")
                }
            }
            warnings += notes.count
            print(notes.isEmpty
                  ? style("✓ ", .green) + "\(game.title) [\(game.id)]"
                  : style("! ", .yellow) + "\(game.title) [\(game.id)]: " + notes.joined(separator: "; "))
        }
        let music = NightTheme.problems
        for problem in music { print(style("! ", .yellow) + "Music: " + problem) }
        warnings += music.count
        print(warnings == 0 ? "Library and launch checks passed." : "Checks finished with \(warnings) warning\(warnings == 1 ? "" : "s").")
        return 0
    }

    static func previews() throws -> Int32 {
        let library = try Library()
        guard let mame = Library.mameURL() else { throw ArcadeError("MAME isn't installed. Run: brew install mame") }
        let previews = Previews(library: library, mame: mame)
        let jobs = library.games.flatMap { game in previews.pending(game).map { (game, $0) } }
        if jobs.isEmpty { print("All previews are up to date."); return 0 }
        for (game, kind) in jobs {
            print("Capturing \(kind.rawValue) picture for \(game.title)…", terminator: " ")
            fflush(stdout)
            do { try previews.capture(game, kind); print(style("done", .green)) } catch { print(style(error.localizedDescription, .yellow)) }
        }
        return 0
    }

    static func facts(_ arguments: [String]) throws -> Int32 {
        guard let query = arguments.first else { throw ArcadeError("Which game? For example: ./play --facts dino") }
        let library = try Library()
        let game = try find(query, in: library.catalog)
        guard let gameFacts = try library.loadFacts(game) else {
            throw ArcadeError("No facts for \(game.title) yet. Add launcher/facts/\(game.id).json with the game-facts skill.")
        }
        print(style(game.title, .bold) + style("  by \(gameFacts.developer)", .dim) + "\n")
        for fact in gameFacts.facts {
            let refs = fact.sources.map { "[\($0 + 1)]" }.joined()
            print(style(pad(fact.kind.label, 14), .bold) + fact.text + style(" " + refs, .dim))
        }
        print("\nSources")
        for (index, source) in gameFacts.sources.enumerated() {
            print(style("  [\(index + 1)] ", .dim) + source.title + (source.url.map { style("  " + $0, .dim) } ?? ""))
        }
        return 0
    }

    /// Looks a game up in MAME: exact short name for details, anything else searches titles.
    static func inspect(_ query: String) throws -> Int32 {
        guard !query.isEmpty else { throw ArcadeError("What should I look up? For example: ./play --inspect \"final fight\"") }
        guard let mame = Library.mameURL() else { throw ArcadeError("MAME isn't installed. Run: brew install mame") }
        guard let info = MachineInfo.load(query.lowercased(), mame: mame) else {
            let matches = MachineInfo.search(query, mame: mame)
            guard !matches.isEmpty else { throw ArcadeError("MAME doesn't know “\(query)”. Try part of the title.") }
            print("Games matching “\(query)” (parent sets only):\n")
            let width = (matches.prefix(25).map(\.id.count).max() ?? 8) + 2
            for match in matches.prefix(25) { print("  " + style(pad(match.id, width), .bold) + match.description) }
            if matches.count > 25 { print(style("  …and \(matches.count - 25) more. Be more specific.", .dim)) }
            print("\nDetails: ./play --inspect <name>")
            return 0
        }
        print(style(info.description, .bold) + style("  [\(info.id)]", .dim))
        print("\(info.year) · \(info.manufacturer) · \(info.players.map { "\($0) players" } ?? "? players") · \(info.buttons.map { "\($0) buttons" } ?? "? buttons")")
        if let parent = info.cloneOf { print(style("A clone of \(parent). Prefer the parent set: ./play --inspect \(parent)", .yellow)) }
        if let status = info.status, status != "good" { print(style("Emulation status: \(status). It may not play perfectly.", .yellow)) }
        print("Save states: \(info.saveStates ? "supported" : "not supported")")
        print("Files: \(([info.id] + info.requires).map { $0 + ".zip" }.joined(separator: ", "))"
              + (info.requires.isEmpty ? "" : style("  (extras go in games/bios/)", .dim)))
        if let library = try? Library(), let game = library.catalog.first(where: { $0.id == info.id }) {
            print(style("Already in games.json as \(game.title)" + (library.isInstalled(game) ? ", installed." : ", not installed yet."), .green))
        } else {
            print("\nStarting point for launcher/games.json:\n" + info.catalogDraft)
        }
        return 0
    }

    /// Plays every interface cue with its name, then a stretch of the background bed.
    static func sounds() throws -> Int32 {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { throw ArcadeError("Couldn't open the audio output: \(error.localizedDescription)") }
        func play(_ samples: [Float], for seconds: Double) {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
            player.scheduleBuffer(buffer, at: nil)
            player.play()
            Thread.sleep(forTimeInterval: seconds)
        }
        for cue in Cue.allCases {
            print(style(pad(cue.rawValue, 10), .bold) + cue.meaning)
            play(Synth.samples(cue), for: Sounds.duration(cue) + 0.45)
        }
        print("\nBackground music: High Score opens, then today's theme (the original by day, its night version from 6 pm). 8 seconds of each:")
        let stereo = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 2)!
        let deck = AVAudioPlayerNode()
        engine.attach(deck)
        engine.connect(deck, to: engine.mainMixerNode, format: stereo)
        let today = Music.today()
        for (index, track) in Music.tracks.enumerated() {
            let note = index == Music.opening ? "  · opens" : index == today ? "  · today, now" : ""
            print(style(pad(track.isNight ? "night" : "day", 7), .dim) + track.label + style(note, .green))
            let samples = track.render()
            guard let buffer = AVAudioPCMBuffer(pcmFormat: stereo, frameCapacity: AVAudioFrameCount(samples.left.count)) else { continue }
            buffer.frameLength = AVAudioFrameCount(samples.left.count)
            samples.left.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.left.count) }
            samples.right.withUnsafeBufferPointer { buffer.floatChannelData![1].update(from: $0.baseAddress!, count: samples.right.count) }
            deck.scheduleBuffer(buffer, at: nil, options: .interrupts)
            deck.play()
            Thread.sleep(forTimeInterval: 8)
        }
        deck.stop()
        return 0
    }

    // MARK: Helpers

    /// Exact short name or folder first, then a unique prefix or folder fragment.
    static func find(_ query: String, in catalog: [Game]) throws -> Game {
        let query = query.lowercased()
        if let exact = catalog.first(where: { $0.id == query || $0.folder == query }) { return exact }
        let matches = catalog.filter { $0.id.hasPrefix(query) || $0.folder.contains(query) }
        if matches.count == 1 { return matches[0] }
        if matches.isEmpty { throw ArcadeError("No game matches “\(query)”. Run ./play to see the list.") }
        throw ArcadeError("“\(query)” matches \(matches.map(\.id).joined(separator: ", ")). Be more specific.")
    }

    /// Self-test for the argument builder, run by --check after every build.
    private static func verifyArguments(_ game: Game, library: Library, mame: URL) throws {
        let resume = library.arguments(game, fullscreen: true, mode: .resume, style: .smooth, mame: mame)
        let noSave = library.arguments(game, fullscreen: false, mode: .noSave, style: .crt, mame: mame)
        let fresh = library.arguments(game, fullscreen: true, mode: .fresh, style: .sharp, mame: mame)
        guard resume.first == game.id, resume.contains("-nowindow"), noSave.contains("-window"),
              resume.contains(library.rompath(game)),
              resume.contains(game.saveStates ? "-autosave" : "-noautosave"),
              noSave.contains("-noautosave"), !fresh.contains("-state") else {
            throw ArcadeError("Launch arguments for \(game.title) failed the self-check.")
        }
    }

    private enum Style: String { case bold = "1", dim = "2", red = "31", green = "32", yellow = "33" }
    private static let colors = isatty(STDOUT_FILENO) == 1 && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    private static func style(_ text: String, _ style: Style) -> String {
        colors ? "\u{1B}[\(style.rawValue)m\(text)\u{1B}[0m" : text
    }
    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }
}
