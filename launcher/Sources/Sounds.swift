import AVFoundation

/// Soft interface sounds and a quiet background bed, synthesised at launch: short
/// triangle and filtered-square blips, and a slow retro lounge loop. All original
/// (no game's sounds), quiet by design, and silent while a game runs.
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

    enum Wave { case triangle, square }

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

    /// The background bed: eight slow bars at 80 BPM (about 24 seconds), a warm
    /// detuned pad, a soft bass note per bar and a sparse filtered arpeggio, then
    /// warmed by a low-pass. Its tail is folded onto its start, so it loops seamlessly.
    static func bed() -> [Float] {
        let beat = 0.75, bar = beat * 4
        // Am7, Fmaj7, Cmaj7, Em7, Dm7, Fmaj7, Cadd9, G6
        let chords = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [52, 55, 59, 62],
                      [50, 53, 57, 60], [53, 57, 60, 64], [48, 55, 60, 62], [55, 59, 62, 64]]
        var notes: [Note] = []
        for (index, chord) in chords.enumerated() {
            let start = Double(index) * bar
            for midi in chord {
                for detune in [0.997, 1.003] {
                    notes.append(Note(at: start, from: hz(midi) * detune, to: hz(midi) * detune, length: bar + 0.8,
                                      gain: 0.011, attack: 0.7, decay: 1.3))
                }
            }
            notes.append(Note(at: start, from: hz(chord[0] - 12), to: hz(chord[0] - 12), length: bar * 0.95,
                              gain: 0.045, attack: 0.02, decay: 2.6))
            for (step, voice) in [0, 2, 1, 3].enumerated() where (index + step) % 2 == 0 || step == 0 {
                let midi = chord[voice] + 12
                notes.append(Note(at: start + Double(step) * beat, from: hz(midi), to: hz(midi), length: 0.5,
                                  wave: .square, gain: 0.012, attack: 0.006, decay: 5.5))
            }
        }
        let total = Int(Double(chords.count) * bar * sampleRate)
        var out = render(notes, length: Double(chords.count) * bar + 1.2)
        for i in total..<out.count { out[i - total] += out[i] }
        out.removeLast(out.count - total)
        var smooth: Float = 0
        for i in out.indices { smooth += (out[i] - smooth) * 0.3; out[i] = smooth }
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
                var value = note.wave == .triangle ? 4 * abs(cycle - 0.5) - 1 : (cycle < 0.5 ? 1 : -1)
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
/// and the bed on its own node, faded in and out.
@MainActor final class Sounds {
    var enabled: Bool
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var next = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: Synth.sampleRate, channels: 1)!
    private let bedPlayer = AVAudioPlayerNode()
    private var bedBuffer: AVAudioPCMBuffer?
    private var bedWanted = false
    private var bedScheduled = false
    private var fade: Task<Void, Never>?

    init(enabled: Bool) {
        self.enabled = enabled
        for cue in Cue.allCases { buffers[cue] = buffer(Synth.samples(cue)) }
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.attach(bedPlayer)
        engine.connect(bedPlayer, to: engine.mainMixerNode, format: format)
        bedPlayer.volume = 0
        engine.mainMixerNode.outputVolume = 0.9
        engine.prepare()
        // The bed takes a moment to synthesise; do it off the main thread.
        Task { [weak self] in
            let samples = await Task.detached(priority: .utility) { Synth.bed() }.value
            guard let self else { return }
            self.bedBuffer = self.buffer(samples)
            if self.bedWanted { self.bed(playing: true) }
        }
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

    /// Fades the bed in or out; it keeps its place in the loop while silent.
    func bed(playing: Bool) {
        bedWanted = playing
        guard let bedBuffer, running() else { return }
        if playing && !bedScheduled {
            bedPlayer.scheduleBuffer(bedBuffer, at: nil, options: .loops)
            bedScheduled = true
        }
        if playing && !bedPlayer.isPlaying { bedPlayer.play() }
        fade?.cancel()
        let target: Float = playing ? 1 : 0
        let steps = playing ? 40 : 16
        let from = bedPlayer.volume
        fade = Task { [weak self] in
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(30))
                guard !Task.isCancelled, let self else { return }
                self.bedPlayer.volume = from + (target - from) * Float(step) / Float(steps)
            }
            if !playing { self?.bedPlayer.pause() }
        }
    }

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
