import Foundation

/// How a launch treats MAME's automatic save.
enum LaunchMode: Sendable {
    /// Resume the automatic save (or newest manual save) and save again on exit.
    case resume
    /// Set the automatic save aside, start from the beginning, and save on exit.
    case fresh
    /// Neither load nor save automatically.
    case noSave
}

enum DisplayStyle: String, CaseIterable, Identifiable, Sendable {
    case smooth, sharp, crt
    var id: String { rawValue }
    var label: String {
        switch self {
        case .smooth: "Smooth"
        case .sharp: "Sharp pixels"
        case .crt: "CRT"
        }
    }
    var detail: String {
        switch self {
        case .smooth: "Softly scaled with OpenGL. The original setup."
        case .sharp: "Crisp, square pixels with OpenGL."
        case .crt: "Curved glass, scanlines and glow, rendered with Metal (bgfx crt-geom)."
        }
    }

    func arguments(share: URL?, root: URL) -> [String] {
        switch self {
        case .smooth: return ["-video", "opengl", "-filter"]
        case .sharp: return ["-video", "opengl", "-nofilter"]
        case .crt:
            // bgfx_path and artpath default to folders relative to the working directory,
            // so point them at MAME's installed shaders and artwork explicitly.
            guard let share else { return DisplayStyle.smooth.arguments(share: nil, root: root) }
            return ["-video", "bgfx", "-bgfx_backend", "metal",
                    "-bgfx_path", share.appendingPathComponent("bgfx").path,
                    "-artpath", [root.appendingPathComponent("artwork").path,
                                 share.appendingPathComponent("artwork").path].joined(separator: ";"),
                    "-bgfx_screen_chains", "crt-geom"]
        }
    }
}

/// Settings shared by the app and the `./play` command.
enum Preferences {
    private static var defaults: UserDefaults { .standard }
    static var fullscreen: Bool {
        get { defaults.object(forKey: "gameFullscreen") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "gameFullscreen") }
    }
    static var autoResume: Bool {
        get { defaults.object(forKey: "autoResume") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "autoResume") }
    }
    static var displayStyle: DisplayStyle {
        get { defaults.string(forKey: "displayStyle").flatMap(DisplayStyle.init(rawValue:)) ?? .smooth }
        set { defaults.set(newValue.rawValue, forKey: "displayStyle") }
    }
    static var interfaceSounds: Bool {
        get { defaults.object(forKey: "interfaceSounds") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "interfaceSounds") }
    }
    static var music: Bool {
        get { defaults.object(forKey: "music") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "music") }
    }
    static var lastGame: String? {
        get { defaults.string(forKey: "lastGame") }
        set { defaults.set(newValue, forKey: "lastGame") }
    }

    /// Copies settings once from the app's former identity (Arcade, local.emu.arcade).
    static func migrateFromArcade() {
        guard !defaults.bool(forKey: "migratedFromArcade") else { return }
        let old = defaults.persistentDomain(forName: "local.emu.arcade") ?? [:]
        for key in ["gameFullscreen", "autoResume", "displayStyle", "lastGame"] where defaults.object(forKey: key) == nil {
            if let value = old[key] { defaults.set(value, forKey: key) }
        }
        defaults.set(true, forKey: "migratedFromArcade")
    }
}

/// The project folder: catalog, game files, saves, and the MAME command line built from them.
struct Library: Sendable {
    let root: URL
    let catalog: [Game]

    init(bundle: Bundle = .main) throws {
        root = try Self.locateRoot(bundle: bundle)
        // Prefer the project's catalog so edits apply without a rebuild.
        let projectCatalog = root.appendingPathComponent("launcher/games.json")
        guard let catalogURL = Self.exists(projectCatalog) ? projectCatalog : bundle.url(forResource: "games", withExtension: "json") else {
            throw ArcadeError("launcher/games.json is missing.")
        }
        do { catalog = try JSONDecoder().decode([Game].self, from: Data(contentsOf: catalogURL)) }
        catch { throw ArcadeError("launcher/games.json couldn't be read. \(Self.describe(error))") }
        try Self.validate(catalog)
    }

    /// Uses the folder containing Coinless.app, so the project can move; falls back to the path recorded at build time.
    static func locateRoot(bundle: Bundle) throws -> URL {
        let beside = bundle.bundleURL.deletingLastPathComponent().standardizedFileURL
        if isProject(beside) { return beside }
        if let file = bundle.url(forResource: "project-path", withExtension: "txt"),
           let text = try? String(contentsOf: file, encoding: .utf8) {
            let saved = URL(fileURLWithPath: text.trimmingCharacters(in: .whitespacesAndNewlines), isDirectory: true)
            if isProject(saved) { return saved }
        }
        throw ArcadeError("Couldn't find the project folder. Keep Coinless.app inside the project folder, or rebuild it with launcher/build.sh.")
    }

    static func isProject(_ url: URL) -> Bool { exists(url.appendingPathComponent("launcher/games.json")) }

    static func validate(_ catalog: [Game]) throws {
        let ids = catalog.map(\.id)
        if let duplicate = Dictionary(grouping: ids, by: { $0 }).first(where: { $0.value.count > 1 })?.key {
            throw ArcadeError("games.json lists “\(duplicate)” more than once.")
        }
        for game in catalog {
            guard matches(game.id, "^[a-z0-9_]+$") else { throw ArcadeError("“\(game.id)” in games.json isn't a valid MAME short name.") }
            guard matches(game.folder, "^[a-z0-9-]+$") else { throw ArcadeError("The folder for \(game.title) must use lowercase letters, digits and dashes.") }
            for file in game.requiredFiles where !matches(file, "^[a-z0-9_]+$") {
                throw ArcadeError("“\(file)” in \(game.title)'s requires list should be a ZIP name without “.zip”.")
            }
            if let seconds = game.previewAt, !(5...600).contains(seconds) {
                throw ArcadeError("previewAt for \(game.title) should be between 5 and 600 seconds.")
            }
        }
    }

    // MARK: Paths

    var gamesFolder: URL { root.appendingPathComponent("games", isDirectory: true) }
    /// Shared BIOS/device ZIPs, so files like qsound_hle.zip are needed only once.
    var biosFolder: URL { gamesFolder.appendingPathComponent("bios", isDirectory: true) }
    var stateRoot: URL { root.appendingPathComponent("sta", isDirectory: true) }
    var logFile: URL { root.appendingPathComponent("launcher/.build/mame-last.log") }
    func romFolder(_ game: Game) -> URL { gamesFolder.appendingPathComponent(game.folder, isDirectory: true) }
    func stateFolder(_ game: Game) -> URL { stateRoot.appendingPathComponent(game.id, isDirectory: true) }
    func artFolder(_ game: Game) -> URL { root.appendingPathComponent("art", isDirectory: true).appendingPathComponent(game.id, isDirectory: true) }
    func rompath(_ game: Game) -> String { [romFolder(game).path, biosFolder.path].joined(separator: ";") }

    // MARK: Installed files

    func isInstalled(_ game: Game) -> Bool { Self.exists(romFolder(game).appendingPathComponent(game.id + ".zip")) }
    var games: [Game] { catalog.filter(isInstalled) }
    func missingFiles(_ game: Game) -> [String] {
        game.requiredFiles.filter { name in
            ![romFolder(game), biosFolder].contains { Self.exists($0.appendingPathComponent(name + ".zip")) }
        }
    }

    // MARK: Saves

    /// The slot a launch resumes from: "auto" (MAME's exit save) or, before one exists, the newest manual save.
    func resumeSlot(_ game: Game) -> String? {
        guard game.saveStates else { return nil }
        let directory = stateFolder(game)
        if Self.exists(directory.appendingPathComponent("auto.sta")) { return "auto" }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey])) ?? []
        return files
            .filter { $0.pathExtension == "sta" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .max { Self.modified($0) < Self.modified($1) }?
            .deletingPathExtension().lastPathComponent
    }

    func resumeFile(_ game: Game) -> URL? {
        resumeSlot(game).map { stateFolder(game).appendingPathComponent($0 + ".sta") }
    }

    /// Moves auto.sta to auto.sta.bak so the next launch starts from the beginning. Returns whether there was one.
    @discardableResult
    func setAsideAutosave(_ game: Game) throws -> Bool {
        let auto = stateFolder(game).appendingPathComponent("auto.sta")
        guard Self.exists(auto) else { return false }
        let backup = stateFolder(game).appendingPathComponent("auto.sta.bak")
        if Self.exists(backup) { try FileManager.default.removeItem(at: backup) }
        try FileManager.default.moveItem(at: auto, to: backup)
        return true
    }

    // MARK: MAME

    func arguments(_ game: Game, fullscreen: Bool, mode: LaunchMode, style: DisplayStyle, mame: URL?) -> [String] {
        var arguments = [game.id, "-rompath", rompath(game), fullscreen ? "-nowindow" : "-window",
                         "-keepaspect", "-joystick", "-skip_gameinfo",
                         "-state_directory", stateRoot.path]
        arguments += style.arguments(share: mame.flatMap(Self.shareFolder), root: root)
        let saving = game.saveStates && mode != .noSave
        arguments.append(saving ? "-autosave" : "-noautosave")
        // With -autosave, MAME loads auto.sta by itself; a manual slot has to be named.
        if saving, mode == .resume, let slot = resumeSlot(game), slot != "auto" { arguments += ["-state", slot] }
        return arguments
    }

    static func mameURL() -> URL? {
        // Apps opened from the Dock get a minimal PATH, so check the usual install locations first.
        var candidates = ["/opt/homebrew/bin/mame", "/usr/local/bin/mame", "/opt/local/bin/mame"]
        candidates += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/mame" }
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }).map { URL(fileURLWithPath: $0) }
    }

    /// MAME's installed share/mame folder (shaders and artwork), if present.
    static func shareFolder(for mame: URL) -> URL? {
        let share = mame.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("share/mame", isDirectory: true)
        return exists(share.appendingPathComponent("bgfx/chains/crt-geom.json")) ? share : nil
    }

    /// A plain-language reason for a MAME exit status (see MAME's documented exit codes).
    static func exitSummary(status: Int32, reason: Process.TerminationReason) -> String {
        if reason == .uncaughtSignal { return "MAME stopped unexpectedly (signal \(status))." }
        switch status {
        case 2: return "Some of the game's files are missing or don't match this version of MAME. Check its ZIP and any BIOS files."
        case 5: return "This version of MAME doesn't know this game's short name."
        case 6: return "MAME rejected its configuration. Check for a mame.ini in the project folder."
        default: return "MAME exited with code \(status)."
        }
    }

    static func shellQuoted(_ arguments: [String]) -> String {
        arguments.map { argument in
            matches(argument, #"^[A-Za-z0-9_@%+=:,./-]+$"#) ? argument : "'" + argument.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
        }.joined(separator: " ")
    }

    // MARK: Helpers

    static func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
    static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
    static func matches(_ text: String, _ pattern: String) -> Bool { text.range(of: pattern, options: .regularExpression) != nil }

    private static func describe(_ error: Error) -> String {
        guard let error = error as? DecodingError else { return error.localizedDescription }
        switch error {
        case .keyNotFound(let key, let context):
            return "Missing “\(key.stringValue)” in entry \(entry(context.codingPath))."
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            return "\(context.debugDescription) (\(entry(context.codingPath)))"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func entry(_ path: [CodingKey]) -> String {
        guard let index = path.first?.intValue else { return "top level" }
        return "#\(index + 1)" + (path.count > 1 ? ", “\(path[1].stringValue)”" : "")
    }
}
