import Foundation

/// Library pictures for each game, kept in art/<game>/:
/// - cover.png / cover.jpg: your own image, used instead of the attract screenshot
/// - resume.png: where you left off, rendered from the save Coinless will resume
/// - attract.png: a frame of the game's attract mode, captured by MAME without a window
struct Previews: Sendable {
    enum Kind: String, Sendable { case attract, resume }

    let library: Library
    let mame: URL

    static let defaultSeconds = 50

    func file(_ game: Game, _ kind: Kind) -> URL {
        library.artFolder(game).appendingPathComponent(kind.rawValue + ".png")
    }

    static func cover(_ game: Game, in library: Library) -> URL? {
        ["cover.png", "cover.jpg", "cover.jpeg"].lazy
            .map { library.artFolder(game).appendingPathComponent($0) }
            .first(where: Library.exists)
    }

    /// The picture to show: the resume point when a save will be resumed, otherwise a cover or attract frame.
    static func image(for game: Game, in library: Library, showResume: Bool) -> URL? {
        let folder = library.artFolder(game)
        var candidates: [URL?] = [cover(game, in: library), folder.appendingPathComponent("attract.png")]
        if showResume { candidates.insert(folder.appendingPathComponent("resume.png"), at: 0) }
        return candidates.compactMap { $0 }.first(where: Library.exists)
    }

    /// The captures still needed for a game, quickest first.
    func pending(_ game: Game) -> [Kind] {
        var kinds: [Kind] = []
        if let save = library.resumeFile(game), Library.modified(file(game, .resume)) < Library.modified(save) {
            kinds.append(.resume)
        }
        if Self.cover(game, in: library) == nil, !Library.exists(file(game, .attract)) { kinds.append(.attract) }
        return kinds
    }

    func clear(_ game: Game) {
        for kind in [Kind.attract, .resume] { try? FileManager.default.removeItem(at: file(game, kind)) }
    }

    /// Runs MAME without video or sound in a scratch folder, so your settings, NVRAM and saves are never touched.
    /// Blocks until done; call it off the main thread. Stops early when the calling task is cancelled.
    func capture(_ game: Game, _ kind: Kind) throws {
        let fileManager = FileManager.default
        let scratch = fileManager.temporaryDirectory.appendingPathComponent("coinless-preview-" + UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: scratch) }
        let snaps = scratch.appendingPathComponent("snap", isDirectory: true)
        let states = scratch.appendingPathComponent("sta", isDirectory: true)
        try fileManager.createDirectory(at: states.appendingPathComponent(game.id), withIntermediateDirectories: true)

        var arguments = [game.id, "-rompath", library.rompath(game), "-noreadconfig",
                         "-video", "none", "-sound", "none", "-nothrottle", "-skip_gameinfo", "-noautosave",
                         "-cfg_directory", scratch.path, "-nvram_directory", scratch.path, "-diff_directory", scratch.path,
                         "-state_directory", states.path, "-snapshot_directory", snaps.path]
        switch kind {
        case .attract:
            // MAME saves a snapshot when -seconds_to_run ends.
            arguments += ["-seconds_to_run", String(game.previewAt ?? Self.defaultSeconds)]
        case .resume:
            guard let save = library.resumeFile(game) else { return }
            try fileManager.copyItem(at: save, to: states.appendingPathComponent(game.id).appendingPathComponent(save.lastPathComponent))
            arguments += ["-state", save.deletingPathExtension().lastPathComponent, "-seconds_to_run", "1"]
        }

        let task = Process()
        task.executableURL = mame
        task.arguments = arguments
        task.currentDirectoryURL = scratch
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try task.run()
        let deadline = Date().addingTimeInterval(120)
        while task.isRunning {
            if Task.isCancelled || Date() > deadline { task.terminate(); task.waitUntilExit(); throw CancellationError() }
            Thread.sleep(forTimeInterval: 0.1)
        }

        let shots = (try? fileManager.contentsOfDirectory(at: snaps.appendingPathComponent(game.id), includingPropertiesForKeys: nil)) ?? []
        guard let shot = shots.first(where: { $0.pathExtension == "png" }) else {
            throw ArcadeError("MAME didn't capture a preview for \(game.title).")
        }
        let target = file(game, kind)
        try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if Library.exists(target) { try fileManager.removeItem(at: target) }
        try fileManager.moveItem(at: shot, to: target)
    }
}
