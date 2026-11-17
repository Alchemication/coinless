import AVFoundation

/// Soft interface sounds and the library's background music (Music.swift), all
/// synthesised: short triangle and filtered-square blips, and seven slow themes.
/// All original (no game's sounds), quiet by design, and silent while a game runs.
enum Cue: String, CaseIterable, Sendable {
    case move, bump, start, open, close, warn, welcome, error

    /// What each cue is for, shown by `./play --sounds`.
    var meaning: String {
        switch self {
        case .move: "browse to another game"
        case .bump: "the end of the list"
        case .start: "play or resume"
        case .open: "open settings"
        case .close: "close settings"
        case .warn: "new game, first press"
        case .welcome: "back from a game"
        case .error: "something went wrong"
        }
    }
}

enum Synth {
    static let sampleRate = 44_100.0

    enum Wave { case triangle, square, sine, bell }

    struct Note {
        var at: Double          // seconds from the cue's start
        var from: Double        // Hz
        var to: Double          // Hz (a short glide)
        var length: Double      // seconds
        var wave: Wave = .triangle
        var gain: Double = 0.18
        var attack: Double = 0.004   // seconds to full volume
        var decay: Double = 4.2      // exponential decay rate over the note's length
    }

    static func hz(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    /// The cues. Intervals are simple and bright (fifths, sixths, a major triad),
    /// all a little filtered so nothing is sharp.
    static func notes(_ cue: Cue) -> [Note] {
        switch cue {
        case .move:
            return [Note(at: 0, from: 1_320, to: 1_200, length: 0.045, gain: 0.10)]
        case .bump:
            return [Note(at: 0, from: 196, to: 165, length: 0.09, gain: 0.16)]
        case .start:
            return [Note(at: 0.00, from: 784, to: 784, length: 0.07, wave: .square, gain: 0.07),
                    Note(at: 0.06, from: 1_047, to: 1_047, length: 0.07, wave: .square, gain: 0.07),
                    Note(at: 0.12, from: 1_568, to: 1_568, length: 0.32, wave: .square, gain: 0.06),
                    Note(at: 0.12, from: 784, to: 784, length: 0.36, gain: 0.08)]
        case .open:
            return [Note(at: 0, from: 659, to: 659, length: 0.06, gain: 0.12),
                    Note(at: 0.05, from: 988, to: 988, length: 0.10, gain: 0.12)]
        case .close:
            return [Note(at: 0, from: 988, to: 988, length: 0.06, gain: 0.12),
                    Note(at: 0.05, from: 659, to: 659, length: 0.10, gain: 0.12)]
        case .warn:
            return [Note(at: 0, from: 440, to: 440, length: 0.06, wave: .square, gain: 0.06),
                    Note(at: 0.11, from: 440, to: 440, length: 0.06, wave: .square, gain: 0.06)]
        case .welcome:
            return [Note(at: 0.00, from: 523, to: 523, length: 0.16, gain: 0.11),
                    Note(at: 0.10, from: 659, to: 659, length: 0.16, gain: 0.11),
                    Note(at: 0.20, from: 784, to: 784, length: 0.45, gain: 0.11)]
        case .error:
            return [Note(at: 0, from: 392, to: 392, length: 0.12, gain: 0.14),
                    Note(at: 0.11, from: 294, to: 280, length: 0.22, gain: 0.14)]
        }
    }

    /// Mono samples for a cue, with a short fade-out.
    static func samples(_ cue: Cue) -> [Float] {
        let notes = notes(cue)
        var out = render(notes, length: (notes.map { $0.at + $0.length }.max() ?? 0) + 0.05)
        let fade = Int(0.03 * sampleRate)
        for i in 0..<min(fade, out.count) { out[out.count - 1 - i] *= Float(i) / Float(fade) }
        return out
    }

    /// Mixes notes: each with its attack and exponential decay, squares softened by a one-pole low-pass.
    static func render(_ notes: [Note], length: Double) -> [Float] {
        var out = [Float](repeating: 0, count: Int(length * sampleRate))
        for note in notes {
            let start = Int(note.at * sampleRate), count = Int(note.length * sampleRate)
            var phase = 0.0, smooth = 0.0
            for i in 0..<count where start + i < out.count {
                let t = Double(i) / sampleRate
                let progress = t / note.length
                let frequency = note.from + (note.to - note.from) * progress
                phase += frequency / sampleRate
                let cycle = phase - phase.rounded(.down)
                var value: Double
                switch note.wave {
                case .triangle: value = 4 * abs(cycle - 0.5) - 1
                case .square: value = cycle < 0.5 ? 1 : -1
                case .sine: value = sin(2 * .pi * cycle)
                // A bell: the fundamental plus a soft overtone that fades faster.
                case .bell: value = sin(2 * .pi * cycle) + 0.3 * sin(4 * .pi * cycle) * exp(-6 * progress)
                }
                if note.wave == .square { smooth += (value - smooth) * 0.22; value = smooth }
                let attack = min(1, t / note.attack)
                let decay = exp(-note.decay * progress)
                out[start + i] += Float(value * attack * decay * note.gain)
            }
        }
        return out
    }
}

/// Plays cues through a small pool of player nodes, so quick moves can overlap,
/// and the music on two decks behind one bus: the bus fades it in and out; the
/// decks crossfade from one theme to the next.
@MainActor final class Sounds {
    var enabled: Bool
    /// Told whenever a different theme starts.
    var onTheme: ((MusicTheme) -> Void)?
    private(set) var theme = Music.todayIndex()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var next = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!

    private let bus = AVAudioMixerNode()
    private let decks = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private var live = 0
    private var deckTheme: [Int?] = [nil, nil]
    private var rendered: [Int: AVAudioPCMBuffer] = [:]
    private var rendering: Set<Int> = []
    private var pendingSwitch: (theme: Int, seconds: Double)?
    private var audible = false
    private var elapsed = 0.0
    private var crossfading = false
    private var busFade: Task<Void, Never>?
    private var ticker: Task<Void, Never>?

    /// Each theme plays this many times before drifting into the next.
    static let loopsPerTheme = 2.0
    static let crossfadeSeconds = 8.0

    init(enabled: Bool) {
        self.enabled = enabled
        for cue in Cue.allCases { buffers[cue] = buffer(Synth.samples(cue)) }
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.attach(bus)
        engine.connect(bus, to: engine.mainMixerNode, format: format)
        for deck in decks {
            engine.attach(deck)
            engine.connect(deck, to: bus, format: format)
        }
        bus.outputVolume = 0
        engine.mainMixerNode.outputVolume = 0.9
        engine.prepare()
        prepare(theme)
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }

    private func running() -> Bool {
        if !engine.isRunning { try? engine.start() }
        return engine.isRunning
    }

    // MARK: Music

    /// Synthesises a theme in the background (a fraction of a second), once.
    private func prepare(_ index: Int) {
        guard rendered[index] == nil, !rendering.contains(index) else { return }
        rendering.insert(index)
        let theme = Music.themes[index]
        Task { [weak self] in
            let samples = await Task.detached(priority: .utility) { Music.render(theme) }.value
            guard let self else { return }
            self.rendering.remove(index)
            self.rendered[index] = self.buffer(samples)
            if index == self.theme && self.audible { self.startLive() }
            if let pending = self.pendingSwitch, pending.theme == index {
                self.pendingSwitch = nil
                self.crossfade(to: index, over: pending.seconds)
            }
        }
    }

    /// Fades the music in or out; it keeps its place while silent.
    func bed(playing: Bool) {
        audible = playing
        guard running() else { return }
        if playing { startLive() } else { ticker?.cancel(); ticker = nil }
        busFade?.cancel()
        let from = bus.outputVolume, to: Float = playing ? 1 : 0
        let steps = playing ? 50 : 16
        busFade = Task { [weak self] in
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(30))
                guard !Task.isCancelled, let self else { return }
                self.bus.outputVolume = from + (to - from) * Float(step) / Float(steps)
            }
            if !playing { self?.decks.forEach { $0.pause() } }
        }
    }

    /// Another theme, by a short crossfade (← → on the music setting).
    func skip(_ step: Int) {
        let count = Music.themes.count
        crossfade(to: ((theme + step) % count + count) % count, over: 2.5)
    }

    private func startLive() {
        guard let buffer = rendered[theme] else { prepare(theme); return }
        let deck = decks[live]
        if deckTheme[live] != theme {
            deck.stop()
            deck.volume = 1
            deck.scheduleBuffer(buffer, at: nil, options: .loops)
            deckTheme[live] = theme
            onTheme?(Music.themes[theme])
        }
        if !deck.isPlaying { deck.play() }
        if crossfading, !decks[1 - live].isPlaying, deckTheme[1 - live] != nil { decks[1 - live].play() }
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                self.elapsed += 0.5
                let due = Music.themes[self.theme].length * Self.loopsPerTheme
                let following = (self.theme + 1) % Music.themes.count
                if self.elapsed > due - 20 { self.prepare(following) }
                if self.elapsed >= due && !self.crossfading { self.crossfade(to: following, over: Self.crossfadeSeconds) }
            }
        }
    }

    private func crossfade(to index: Int, over seconds: Double) {
        guard index != theme || deckTheme[live] != index else { return }
        guard let buffer = rendered[index] else { pendingSwitch = (index, seconds); prepare(index); return }
        guard !crossfading else { return }
        crossfading = true
        let outgoing = live, incoming = 1 - live
        let outDeck = decks[outgoing], inDeck = decks[incoming]
        inDeck.stop()
        inDeck.volume = 0
        inDeck.scheduleBuffer(buffer, at: nil, options: .loops)
        deckTheme[incoming] = index
        if audible { inDeck.play() }
        live = incoming
        theme = index
        elapsed = 0
        onTheme?(Music.themes[index])
        let steps = max(1, Int(seconds / 0.1))
        let startVolume = outDeck.volume
        Task { [weak self] in
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(100))
                let x = Float(step) / Float(steps)
                inDeck.volume = x
                outDeck.volume = startVolume * (1 - x)
            }
            guard let self else { return }
            outDeck.stop()
            self.deckTheme[outgoing] = nil
            self.crossfading = false
            // Keep only what's playing and what plays next.
            let keep: Set<Int> = [self.theme, (self.theme + 1) % Music.themes.count]
            self.rendered = self.rendered.filter { keep.contains($0.key) }
        }
    }

    // MARK: Cues

    func play(_ cue: Cue) {
        guard enabled, let buffer = buffers[cue] else { return }
        guard running() else { return }
        let player = players[next]
        next = (next + 1) % players.count
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.play()
    }

    /// Length of a cue, for `./play --sounds`.
    nonisolated static func duration(_ cue: Cue) -> Double { Double(Synth.samples(cue).count) / Synth.sampleRate }
}
