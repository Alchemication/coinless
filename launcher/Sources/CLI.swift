import Foundation

/// Terminal commands, used by ./play in the project root.
enum CLI {
    static let commands: Set<String> = ["--check", "--list", "--play", "--previews", "--help", "-h"]

    static let usage = """
    Usage: ./play [game] [options]

      ./play                    List games and whether they're ready to play
      ./play dino               Play a game with the Coinless app's settings
      ./play cad                Names can be shortened, or use the folder name
      ./play --check            Check MAME, games.json, and the installed games
      ./play --previews         Capture missing library pictures now

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
            if let supported = Library.driverSupportsSaves(game.id, mame: mame), supported != game.saveStates {
                notes.append("games.json says saveStates: \(game.saveStates), but MAME reports \(supported ? "supported" : "unsupported")")
            }
            warnings += notes.count
            print(notes.isEmpty
                  ? style("✓ ", .green) + "\(game.title) [\(game.id)]"
                  : style("! ", .yellow) + "\(game.title) [\(game.id)]: " + notes.joined(separator: "; "))
        }
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
