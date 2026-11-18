import SwiftUI
import GameController

@MainActor final class ArcadeModel: ObservableObject {
    struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    enum HelpItem: Int, CaseIterable { case fullscreen, autoResume, display, music, interfaceSounds, quit }

    @Published private(set) var games: [Game] = []
    @Published var selection = 0 {
        didSet { if selection != oldValue { confirmingFresh = nil; restartFacts() } }
    }
    /// Set by Launching.swift, like the game-session state below.
    @Published var running: Game?
    @Published var notice: Notice? { didSet { if notice != nil && oldValue == nil { sounds.play(.error) } } }
    @Published var help = false {
        didSet { if help != oldValue { helpFocus = .fullscreen; sounds.play(help ? .open : .close) } }
    }
    @Published var helpFocus: HelpItem = .fullscreen
    @Published var controllerCount = 0
    /// Games with a save that the next launch will resume.
    @Published private(set) var savedGames: Set<String> = []
    @Published private(set) var artwork: [String: NSImage] = [:]
    @Published private(set) var previewStatus: String?
    /// Set after the first New Game press; a second press confirms.
    @Published var confirmingFresh: String?
    /// Researched facts per game id, from launcher/facts/.
    @Published private(set) var facts: [String: GameFacts] = [:]
    /// Which fact each game is showing; starts at a random one each session.
    @Published private(set) var factPosition: [String: Int] = [:]
    /// Bumped whenever a fact's reading timer restarts, so the view restarts its progress bar.
    @Published private(set) var factCycle = 0
    /// A tip shown on the now-playing screen.
    @Published var playingTip: GameFacts.Fact?
    @Published var fullscreen = Preferences.fullscreen { didSet { Preferences.fullscreen = fullscreen } }
    @Published var autoResume = Preferences.autoResume { didSet { Preferences.autoResume = autoResume; reloadArtwork() } }
    @Published var displayStyle = Preferences.displayStyle { didSet { Preferences.displayStyle = displayStyle } }
    @Published var music = Preferences.music { didSet { Preferences.music = music; updateBed() } }
    @Published var interfaceSounds = Preferences.interfaceSounds {
        didSet { Preferences.interfaceSounds = interfaceSounds; sounds.enabled = interfaceSounds && !Self.quiet }
    }
    /// The track playing now (or next, while the music is paused); its name is in the top bar,
    /// and Settings shows `nowPlaying`, e.g. "Tuesday night · Rain on the Glass".
    @Published private(set) var theme = Music.tracks[Music.opening]
    var nowPlaying: String { theme.label }
    /// Soft interface cues and the background music (Sounds.swift, Music.swift).
    let sounds = Sounds(enabled: Preferences.interfaceSounds && !ArcadeModel.quiet)
    /// The smoke test and --preview stay silent.
    static var quiet: Bool { isSmokeTest || isPreview }

    let library: Library?
    /// Brings the launcher window to the front; set by the app delegate.
    var onReturn: (() -> Void)?

    static let isSmokeTest = CommandLine.arguments.contains("--smoke-test")
    static let isPreview = CommandLine.arguments.contains("--preview")

    // The game session, used by Launching.swift.
    var process: Process?
    var mameLog: FileHandle?
    var quitAfterGame: (() -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var previewTask: Task<Void, Never>?
    private var previewGeneration = 0
    var confirmTask: Task<Void, Never>?
    private var factTask: Task<Void, Never>?
    // Controller and trackpad state, used by Input.swift.
    var heldDirections: [String: Direction] = [:]
    var repeatTasks: [String: Task<Void, Never>] = [:]
    var returnDeadline: Date?
    var scrollAccumulator: CGFloat = 0
    var exitChord: [String: Set<String>] = [:]
    var exitTask: Task<Void, Never>?
    var exitHeldSince: Date?
    /// Keeps macOS from napping Coinless behind MAME, so the controller is still heard (Options + Share).
    var gameActivity: NSObjectProtocol?
    /// The file launcher/quit.lua watches for: creating it asks MAME to quit like Esc.
    var quitRequest: URL?

    init() {
        do { library = try Library() } catch {
            library = nil
            notice = Notice(title: "Coinless needs setting up", message: error.localizedDescription)
        }
        // Keep receiving controller input if macOS doesn't hand focus back after a game; see acceptsController.
        GCController.shouldMonitorBackgroundEvents = true
        sounds.onTheme = { [weak self] theme in withAnimation(.easeInOut(duration: 0.6)) { self?.theme = theme } }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateBed() }
            })
        }
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.configureControllers() }
            })
        }
        refresh()
        configureControllers()
    }

    var active: Game? { games.indices.contains(selection) ? games[selection] : nil }
    var isPlaying: Bool { process != nil }
    func hasResume(_ game: Game) -> Bool { autoResume && savedGames.contains(game.id) }
    var resumeAvailable: Bool { active.map(hasResume) ?? false }

    // MARK: Library

    func refresh() {
        let previous = active?.id ?? Preferences.lastGame
        games = library?.games ?? []
        selection = games.firstIndex { $0.id == previous } ?? min(selection, max(0, games.count - 1))
        refreshSaves()
        reloadArtwork()
        loadFacts()
        updatePreviews()
    }

    func select(_ index: Int) {
        guard games.indices.contains(index), index != selection else { return }
        sounds.play(.move)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { selection = index }
    }

    func move(_ delta: Int) {
        guard running == nil, !help, notice == nil, !games.isEmpty else { return }
        let target = min(max(selection + delta, 0), games.count - 1)
        if target == selection { sounds.play(.bump) } else { select(target) }
    }

    func refreshSaves() {
        savedGames = Set(games.filter { library?.resumeSlot($0) != nil }.map(\.id))
    }

    func reloadArtwork(_ only: Game? = nil) {
        guard let library else { return }
        for game in only.map({ [$0] }) ?? games {
            let url = Previews.image(for: game, in: library, showResume: hasResume(game))
            artwork[game.id] = url.flatMap { NSImage(contentsOf: $0) }
        }
    }

    // MARK: Sound

    /// The bed plays only on the library: music on, no game running, the app in front.
    func updateBed() {
        sounds.bed(playing: music && running == nil && !Self.quiet && NSApp?.isActive == true)
    }

    // MARK: Facts

    /// The fact on screen for the selected game, with its place in the list.
    var currentFact: (fact: GameFacts.Fact, index: Int, count: Int)? {
        guard let game = active, let list = facts[game.id]?.facts, !list.isEmpty else { return nil }
        let index = (factPosition[game.id] ?? 0) % list.count
        return (list[index], index, list.count)
    }

    private func loadFacts() {
        guard let library else { return }
        var loaded: [String: GameFacts] = [:]
        for game in games {
            guard let gameFacts = try? library.loadFacts(game) else { continue }
            loaded[game.id] = gameFacts
            if factPosition[game.id] == nil {
                // --preview renders the first fact, so README images are reproducible.
                factPosition[game.id] = Self.isPreview ? 0 : Int.random(in: 0..<gameFacts.facts.count)
            }
        }
        facts = loaded
        restartFacts()
    }

    /// Steps through the selected game's facts; ↑ ↓, L1 R1, or a click.
    func stepFact(_ delta: Int) {
        guard running == nil, !help, notice == nil,
              let game = active, let count = facts[game.id]?.facts.count, count > 0 else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            factPosition[game.id] = ((factPosition[game.id] ?? 0) + delta % count + count) % count
        }
        restartFacts()
    }

    /// Restarts the reading timer; when it runs out the next fact appears. Waits while anything covers the library.
    func restartFacts() {
        factTask?.cancel()
        factCycle += 1
        guard let current = currentFact, !Self.isPreview else { return }
        let wait = GameFacts.readingTime(current.fact.text)
        factTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled, let self else { return }
            if self.running == nil, !self.help, self.notice == nil { self.stepFact(1) } else { self.restartFacts() }
        }
    }

    // MARK: Previews

    /// Captures missing previews one at a time in the background. Paused while a game runs.
    func updatePreviews() {
        stopPreviews()
        guard running == nil, !Self.isSmokeTest, !Self.isPreview, let library, let mame = Library.mameURL() else { return }
        let previews = Previews(library: library, mame: mame)
        let jobs = games.flatMap { game in previews.pending(game).map { (game, $0) } }
        guard !jobs.isEmpty else { return }
        let generation = previewGeneration
        previewTask = Task { [weak self] in
            for (index, (game, kind)) in jobs.enumerated() {
                guard let self, !Task.isCancelled else { return }
                self.previewStatus = jobs.count == 1 ? "Preparing preview" : "Preparing previews \(index + 1)/\(jobs.count)"
                let worker = Task.detached(priority: .utility) { (try? previews.capture(game, kind)) != nil }
                let captured = await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
                if captured { self.reloadArtwork(game) }
            }
            guard let self, self.previewGeneration == generation else { return }
            self.previewStatus = nil
            self.previewTask = nil
        }
    }

    func stopPreviews() {
        previewTask?.cancel()
        previewTask = nil
        previewGeneration += 1
        previewStatus = nil
    }

    func rebuildPreviews() {
        guard let library, let mame = Library.mameURL() else { return }
        stopPreviews()
        for game in games { Previews(library: library, mame: mame).clear(game) }
        reloadArtwork()
        updatePreviews()
    }
}
