import Foundation

/// Ten night themes, played from dusk (Music.swift says when). Each arranges its own
/// instruments (Voices, Instruments, Ambience) to sound like its title: a piano in the
/// rain, a music box after the first coin, a choir and a clock for the last credit.
/// Chords are written bass first; melodies in beats ("D5/2"), each bar adding up to
/// four. `--check` reads both (NightTheme.problems).
struct NightTheme: Sendable {
    let id: String, name: String
    /// The weekday whose night it opens, or "" for a theme that only drifts in.
    let day: String
    let bpm: Double
    let chords: [(String, Int)]
    var melody = ""
    var verb = (size: 0.85, damp: 0.35, wet: 0.35)
    var echoFeedback = 0.4, wow = 0.0
    let arrange: @Sendable (Score) -> Void

    var bars: Int { chords.reduce(0) { $0 + $1.1 } }
    var length: Double { Double(bars) * 4 * 60 / bpm }
    /// The originals' loudness (RMS, about -37 dBFS), so day and night sit at the same level.
    static let loudness: Float = 0.0145

    /// "C#4" → 61.
    static func midi(_ name: Substring) -> Int? {
        let chars = Array(name)
        let classes: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard chars.count >= 2, var pc = classes[chars[0]] else { return nil }
        var i = 1
        if chars[i] == "#" { pc += 1; i += 1 } else if chars[i] == "b" { pc -= 1; i += 1 }
        guard i < chars.count, let octave = Int(String(chars[i...])) else { return nil }
        return 12 * (octave + 1) + pc
    }

    /// Chords and melody in seconds, plus anything that doesn't add up.
    func parse() -> (changes: [(bar: Int, count: Int, notes: [Int])], events: [NoteEvent], problems: [String]) {
        var changes: [(bar: Int, count: Int, notes: [Int])] = [], events: [NoteEvent] = [], problems: [String] = []
        var bar = 0
        for (text, count) in chords {
            let notes = text.split(separator: " ").compactMap(Self.midi)
            if notes.count != text.split(separator: " ").count || notes.count < 3 {
                problems.append("\(name): chord “\(text)” needs a bass and at least two notes")
            }
            changes.append((bar, count, notes))
            bar += count
        }
        guard !melody.isEmpty else { return (changes, events, problems) }
        let beat = 60 / bpm
        var t = 0.0, barCount = 0
        for barText in melody.split(separator: "|") {
            var inBar = 0.0
            barCount += 1
            for token in barText.split(separator: " ") {
                let parts = token.split(separator: "/")
                guard parts.count == 2, let beats = Double(parts[1]), parts[0] == "r" || Self.midi(parts[0]) != nil else {
                    problems.append("\(name): melody bar \(barCount) has “\(token)”"); continue
                }
                if let midi = Self.midi(parts[0]) { events.append(NoteEvent(at: t * beat, midi: Double(midi), length: beats * beat)) }
                t += beats; inBar += beats
            }
            if abs(inBar - 4) > 0.001 { problems.append("\(name): melody bar \(barCount) has \(inBar) beats, not 4") }
        }
        if barCount != bars { problems.append("\(name): melody has \(barCount) bars, chords have \(bars)") }
        return (changes, events, problems)
    }

    static var problems: [String] { all.flatMap { $0.parse().problems } }

    /// Stereo samples ready to loop: the echo and reverb tail is folded back onto the
    /// start so the loop has no seam, then the whole theme is levelled.
    func render() -> (left: [Float], right: [Float]) {
        let tail = 9.0, n = Int((length + tail) * Synth.sampleRate)
        let s = Score(self, n: n)
        arrange(s)
        for mix in s.owned { s.dry.add(mix) }
        s.pingPong(s.send, into: s.dry, delay: 45 / bpm, feedback: echoFeedback)
        // The reverb hears the dry sound and the reverb-only sends; a little of the sends is heard dry too.
        let verbIn = s.space
        verbIn.add(s.dry)
        let wet = StereoMix(n)
        s.reverb(verbIn, into: wet, size: verb.size, damp: verb.damp, wet: verb.wet)
        let total = Int(length * Synth.sampleRate), looped = StereoMix(total)
        for i in 0..<n {
            looped.l[i % total] += s.dry.l[i] * 0.7 + verbIn.l[i] * 0.3 + wet.l[i]
            looped.r[i % total] += s.dry.r[i] * 0.7 + verbIn.r[i] * 0.3 + wet.r[i]
        }
        if wow > 0 { s.wobble(looped, depth: wow, cycles: (0.35 * length).rounded()) }
        let scale = Self.loudness / Float(max(looped.rms, 1e-9))
        return (looped.l.map { max(-1, min(1, $0 * scale)) }, looped.r.map { max(-1, min(1, $0 * scale)) })
    }
}

/// One night theme being rendered: its chords and melody in seconds, and the buffers
/// instruments play into (`dry`; `space` reaches only the reverb, `send` the echo).
final class Score: Studio {
    let beat: Double, bar: Double, loop: Double, bars: Int
    let changes: [(bar: Int, count: Int, notes: [Int])]
    let events: [NoteEvent]
    let dry: StereoMix, space: StereoMix, send: StereoMix
    private(set) var owned: [StereoMix] = []
    private let barChords: [[Int]]
    private let n: Int

    init(_ theme: NightTheme, n: Int) {
        let parsed = theme.parse()
        beat = 60 / theme.bpm; bar = beat * 4; bars = theme.bars; loop = theme.length
        changes = parsed.changes; events = parsed.events
        barChords = parsed.changes.flatMap { change in Array(repeating: change.notes, count: change.count) }
        self.n = n
        dry = StereoMix(n); space = StereoMix(n); send = StereoMix(n)
        super.init(seed: theme.id.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 })
    }

    var fx: StereoMix { dry }
    /// Where a part plays: the shared dry buffer, or (`own`) a buffer of its own, for a
    /// part that gets an effect to itself, like Attract Mode's bit-crushed chip.
    func layer(_ name: String, own: Bool = false) -> StereoMix {
        guard own else { return dry }
        let mix = StereoMix(n)
        owned.append(mix)
        return mix
    }
    func tones(_ bar: Int) -> [Int] { Array(barChords[bar % bars].dropFirst()) }
    func root(_ bar: Int) -> Int { barChords[bar % bars][0] }
}

extension NightTheme {
    static let all: [NightTheme] = [
        // Late at night, rain running down the arcade's window, a piano left on its own.
        NightTheme(id: "rain-on-the-glass", name: "Rain on the Glass", day: "Tuesday",
              bpm: 56,
              chords: [("D2 A3 C4 E4 F4", 2), ("Bb1 F3 A3 D4", 2), ("G1 D3 F3 A3 Bb3", 2), ("A1 E3 G3 D4", 1), ("A1 E3 G3 C#4", 1),
                       ("D2 A3 C4 E4 F4", 2), ("Bb1 F3 A3 D4 E4", 2), ("Eb2 G3 Bb3 D4", 2), ("A1 E3 A3 D4", 1), ("A1 E3 G3 C#4", 1)],
              melody: "r/2 A4/2 | D5/3 E5/1 | F5/2 E5/2 | r/4 | r/2 D5/1 C5/1 | Bb4/4 | A4/2 G4/2 | r/4 | r/2 A4/2 | D5/3 E5/1 | F5/2 A5/2 | G5/4 | r/2 F5/1 Eb5/1 | D5/4 | E5/2 D5/2 | C#5/2 r/2",
              verb: (0.9, 0.5, 0.45),
              arrange: { s in
                  let lead = s.layer("lead"), keys = s.layer("piano"), strings = s.layer("strings")
                  for e in s.events {
                      s.piano(lead, at: e.at, midi: e.midi, gain: 0.075, pan: 0.12, length: e.length + 0.8, soft: 0.55)
                  }
                  for c in s.changes {
                      let at = Double(c.bar) * s.bar, span = Double(c.count) * s.bar, tones = Array(c.notes.dropFirst())
                      s.pad(strings, tones.map { $0 - 12 }, at: at, gate: span,
                          PadSound(detune: 10, cutoff: 260, sweep: 400, q: 0.7, attack: 3, release: 3.5, gain: 0.008, vibrato: 6))
                      for b in 0..<c.count {
                          let t = at + Double(b) * s.bar
                          s.piano(keys, at: t, midi: Double(c.notes[0] + 12), gain: 0.028, pan: -0.25, length: s.bar, soft: 0.8)
                          s.piano(keys, at: t + s.beat, midi: Double(tones[0]), gain: 0.016, pan: -0.1, length: s.bar - s.beat, soft: 0.8)
                          s.piano(keys, at: t + 2.5 * s.beat, midi: Double(tones[min(2, tones.count - 1)]), gain: 0.014, pan: 0.1, length: 1.5 * s.beat, soft: 0.8)
                      }
                  }
                  s.rain(s.fx, length: s.loop + 8, gain: 0.03, drops: 6)
              }),

        // The pool's last warm evening: low sun, still water, crickets, summer nearly over.
        NightTheme(id: "dusk-at-the-pool", name: "Dusk at the Pool", day: "Sunday",
              bpm: 60,
              chords: [("G2 D3 F#3 A3 B3", 2), ("G2 A3 C#4 E4", 2), ("E2 B2 D3 F#3 G3", 2), ("C2 G3 B3 E4 F#4", 2),
                       ("G2 D3 F#3 A3 B3", 2), ("G2 A3 C#4 E4", 2), ("B1 F#3 A3 D4", 2), ("C2 G3 B3 E4 F#4", 2)],
              melody: "r/4 | B4/2 D5/2 | C#5/4 | r/2 A4/2 | B4/3 G4/1 | F#4/4 | E4/2 G4/2 | r/4 | r/4 | D5/2 F#5/2 | E5/4 | r/2 C#5/2 | D5/3 A4/1 | A4/4 | B4/2 F#4/2 | G4/4",
              verb: (0.8, 0.5, 0.35),
              arrange: { s in
                  let lead = s.layer("lead"), keys = s.layer("rhodes")
                  s.mono(lead, s.send, s.events,
                       MonoSound(kind: .flute, attack: 0.18, release: 0.7, glide: 0.06, vibrato: 14, vibratoDelay: 0.35, gain: 0.07, echo: 0.3))
                  for c in s.changes {
                      for b in 0..<c.count {
                          let t = Double(c.bar + b) * s.bar, tones = Array(c.notes.dropFirst())
                          s.ep(keys, at: t, midi: Double(c.notes[0]), gain: 0.05, length: s.bar)
                          let offset = (b % 2 == 0 ? 0.0 : 2.0) * s.beat
                          for (k, m) in tones.enumerated() {
                              s.ep(keys, at: t + offset + Double(k) * 0.03, midi: Double(m), gain: 0.02, pan: -0.3 + 0.2 * Double(k), length: 2 * s.beat)
                          }
                      }
                  }
                  s.water(s.fx, length: s.loop + 8, gain: 0.1, period: s.bar * 2)
                  s.crickets(s.fx, length: s.loop, gain: 0.008)
              }),

        // The very first coin: small, wide-eyed, a little magic.
        NightTheme(id: "first-coin", name: "First Coin", day: "Monday",
              bpm: 66,
              chords: [("C3 G3 E4", 2), ("A2 E3 C4", 2), ("F2 C3 A3", 2), ("G2 D3 B3", 2),
                       ("C3 G3 E4", 2), ("A2 E3 C4", 2), ("F2 C3 A3", 2), ("G2 D3 B3", 1), ("C3 G3 E4", 1)],
              melody: "r/1 G5/1 C6/1 D6/1 | E6/2 D6/2 | C6/1 E6/1 A6/2 | G6/4 | F6/1 E6/1 D6/1 C6/1 | A5/4 | B5/2 D6/2 | G5/4 | r/1 G5/1 C6/1 D6/1 | E6/2 G6/2 | A6/1 G6/1 E6/1 C6/1 | E6/4 | F6/2 A6/2 | C6/2 A5/2 | D6/2 B5/2 | C6/4",
              verb: (0.6, 0.5, 0.25),
              arrange: { s in
                  let lead = s.layer("lead"), box = s.layer("box"), air = s.layer("air")
                  for e in s.events {
                      s.musicBox(lead, at: e.at, midi: e.midi, gain: 0.06, pan: 0.15)
                  }
                  for c in s.changes {
                      for b in 0..<c.count {
                          let t = Double(c.bar + b) * s.bar
                          s.musicBox(box, at: t, midi: Double(c.notes[0] + 24), gain: 0.035, pan: -0.25)
                          s.musicBox(box, at: t + 2 * s.beat, midi: Double(c.notes[1] + 24), gain: 0.025, pan: -0.15)
                      }
                      s.pad(air, Array(c.notes.dropFirst()).map { $0 + 12 }, at: Double(c.bar) * s.bar, gate: Double(c.count) * s.bar,
                          PadSound(detune: 5, cutoff: 900, sweep: 300, attack: 2, release: 2.5, gain: 0.006, vibrato: 3, wave: 2))
                  }
                  s.coin(s.fx, at: 0.05, gain: 0.06)
              }),

        // Walking slow under signs that hum and flicker, the city sliding by in pink and blue.
        NightTheme(id: "neon-drift", name: "Neon Drift", day: "Wednesday",
              bpm: 72,
              chords: [("E2 B3 D4 F#4 G4", 2), ("C2 G3 B3 E4", 2), ("A1 E3 G3 B3 C4", 2), ("B1 F#3 A3 D#4", 2),
                       ("E2 B3 D4 F#4 G4", 2), ("C2 G3 B3 E4", 2), ("D2 A3 B3 F#4", 2), ("B1 F#3 A3 D4", 2)],
              melody: "r/4 | r/2 B4/2 | E5/3 D5/1 | B4/4 | r/4 | r/2 C5/1 B4/1 | A4/4 | r/4 | r/4 | r/2 G5/2 | F#5/3 E5/1 | B4/4 | r/4 | r/2 A5/1 G5/1 | F#5/4 | r/4",
              verb: (0.85, 0.4, 0.38), echoFeedback: 0.45,
              arrange: { s in
                  let lead = s.layer("lead"), seq = s.layer("sequencer"), pads = s.layer("pad"), low = s.layer("bass")
                  s.mono(lead, s.send, s.events,
                       MonoSound(kind: .sax, attack: 0.15, release: 0.6, glide: 0.09, vibrato: 22, vibratoDelay: 0.4, gain: 0.08, echo: 0.4))
                  for c in s.changes {
                      let at = Double(c.bar) * s.bar, span = Double(c.count) * s.bar
                      s.pad(pads, Array(c.notes.dropFirst()), at: at, gate: span, PadSound(detune: 12, cutoff: 300, sweep: 500, attack: 2.5, release: 3, gain: 0.008, vibrato: 4))
                      s.bass(low, at: at, midi: Double(c.notes[0]), length: span * 0.97, gain: 0.06, attack: 0.2, release: 0.8)
                  }
                  for k in 0..<(s.bars * 8) {
                      let t = Double(k) * s.beat / 2, b = Int(t / s.bar), tones = s.tones(b)
                      let pattern = [s.root(b) + 12, tones[0], s.root(b) + 24, tones[1]]
                      let drift = 0.5 - 0.5 * cos(2 * .pi * t / s.loop)
                      s.pluck(seq, at: t, midi: Double(pattern[k % 4]), gain: 0.022, pan: k % 2 == 0 ? -0.3 : 0.3,
                            cutoff: 250, sweep: 300 + 1500 * drift, decay: 0.22, q: 3)
                  }
                  s.hum(s.fx, length: s.loop + 2, gain: 0.004, flicker: 0.3)
              }),

        // The cabinet alone, playing its little demo tune to an empty room, INSERT COIN blinking.
        NightTheme(id: "attract-mode", name: "Attract Mode", day: "Thursday",
              bpm: 80,
              chords: [("F2 A3 C4 E4", 2), ("F2 G3 B3 D4", 2), ("E2 B3 D4 G4", 2), ("A1 E3 G3 C4", 2),
                       ("F2 A3 C4 E4", 2), ("F2 G3 B3 D4", 2), ("E2 B3 D4 G4", 2), ("D2 A3 C4 F4", 2)],
              melody: "C5/1 F5/1 A5/2 | G5/2 C5/2 | D5/1 G5/1 B5/2 | A5/2 D5/2 | B4/1 E5/1 G5/2 | E5/4 | C5/1 E5/1 A5/2 | G5/4 | C5/1 F5/1 A5/2 | G5/2 C5/2 | D5/1 G5/1 B5/2 | A5/2 D5/2 | B4/1 E5/1 G5/2 | E5/2 D5/2 | C5/2 D5/2 | E5/4",
              verb: (0.55, 0.5, 0.2),
              arrange: { s in
                  let lead = s.layer("lead", own: true), low = s.layer("bass", own: true), blink = s.layer("blink")
                  s.mono(lead, s.send, s.events,
                       MonoSound(kind: .chip, attack: 0.005, release: 0.12, glide: 0.01, vibrato: 10, vibratoDelay: 0.25, gain: 0.05, echo: 0.25))
                  for b in 0..<s.bars {
                      for k in [0.0, 2.0] { s.chipTri(low, at: Double(b) * s.bar + k * s.beat, midi: Double(s.root(b) + 12), length: 0.9 * s.beat, gain: 0.06) }
                  }
                  var t = s.beat, k = 0
                  while t < s.loop {
                      s.blip(blink, at: t, midi: k % 2 == 0 ? 84 : 89, length: 0.06, gain: 0.02, pan: k % 2 == 0 ? -0.6 : 0.6)
                      t += 2 * s.beat; k += 1
                  }
                  s.crush(lead, hold: 3, bits: 5); s.crush(low, hold: 3, bits: 5)
              }),

        // CONTINUE? 9… 8… 7… the last coin in your hand, and the clock running.
        NightTheme(id: "last-credit", name: "Last Credit", day: "Friday",
              bpm: 60,
              chords: [("A2 E3 A3 C4", 2), ("G2 E3 A3 C4", 2), ("F2 A3 C4 E4", 2), ("E2 G#3 B3 D4", 2),
                       ("D2 F3 A3 D4", 2), ("C2 E3 A3 C4", 2), ("B1 F3 A3 D4", 2), ("E2 G#3 B3 E4", 2)],
              melody: "r/4 | r/4 | E5/4 | C5/2 B4/2 | A4/4 | r/4 | G#4/4 | r/4 | F4/2 A4/2 | D5/4 | E5/4 | C5/2 A4/2 | B4/2 D5/2 | F5/4 | E5/4 | r/4",
              verb: (0.95, 0.4, 0.55),
              arrange: { s in
                  let lead = s.layer("lead"), choir = s.layer("choir"), low = s.layer("drone"), clock = s.layer("clock")
                  s.mono(lead, s.send, s.events,
                       MonoSound(kind: .choir, attack: 0.5, release: 1.2, glide: 0.12, vibrato: 18, vibratoDelay: 0.3, gain: 0.07, echo: 0.2))
                  for c in s.changes {
                      let at = Double(c.bar) * s.bar, span = Double(c.count) * s.bar
                      s.choirPad(choir, Array(c.notes.dropFirst()), at: at, gate: span, gain: 0.034)
                      s.bass(low, at: at, midi: Double(c.notes[0]), length: span, gain: 0.05, attack: 1.2, release: 2, bright: 0.1)
                  }
                  for k in 0..<(s.bars * 4) {
                      s.tick(clock, at: Double(k) * s.beat, gain: k % 4 == 0 ? 0.16 : 0.1, pan: k % 2 == 0 ? -0.25 : 0.25, tone: 2600)
                  }
                  for (k, m) in [81.0, 79, 77, 76, 74, 72, 71, 69].enumerated() {
                      s.blip(s.space, at: Double(k) * 2 * s.bar, midi: m, length: 0.18, gain: 0.02, cutoff: 1800)
                  }
              }),

        // No coins, no clock: all the time in the world, and the lights twinkling.
        NightTheme(id: "free-play", name: "Free Play", day: "Saturday",
              bpm: 68,
              chords: [("Bb1 F3 A3 C4 D4", 2), ("G1 D3 F3 A3 Bb3", 2), ("Eb2 G3 Bb3 D4", 2), ("F2 A3 C4 F4", 2),
                       ("Bb1 F3 A3 D4", 2), ("D2 A3 C4 F4", 2), ("Eb2 G3 Bb3 D4", 2), ("F2 C4 F4 Bb4", 1), ("F2 A3 C4 F4", 1)],
              melody: "F5/2 Bb5/2 | D6/4 | Bb5/2 A5/2 | G5/4 | Bb5/2 G5/2 | F5/4 | A5/2 C6/2 | F6/4 | D6/2 F6/2 | Bb5/4 | A5/2 C6/2 | F5/4 | G5/2 Bb5/2 | D6/4 | C6/4 | A5/4",
              verb: (0.8, 0.45, 0.35),
              arrange: { s in
                  let lead = s.layer("lead"), strings = s.layer("harp"), air = s.layer("pad"), low = s.layer("bass")
                  for e in s.events {
                      s.glock(lead, at: e.at, midi: e.midi, gain: 0.055, pan: 0.2)
                  }
                  for c in s.changes {
                      let at = Double(c.bar) * s.bar, span = Double(c.count) * s.bar, tones = Array(c.notes.dropFirst()).sorted()
                      let up = [c.notes[0] + 12] + tones + tones.map { $0 + 12 }
                      for (k, m) in up.prefix(6).enumerated() {
                          s.harp(strings, at: at + Double(k) * s.beat / 2, midi: Double(m), gain: 0.125, pan: -0.4 + 0.15 * Double(k), decay: 3)
                      }
                      s.pad(air, tones, at: at, gate: span, PadSound(detune: 6, cutoff: 700, sweep: 500, attack: 2, release: 3, gain: 0.006, wave: 2))
                      s.bass(low, at: at, midi: Double(c.notes[0]), length: span * 0.97, gain: 0.05, attack: 0.1, release: 0.8)
                  }
                  var t = 0.0
                  while t < s.loop {
                      if s.rand() < 0.15 {
                          let tones = s.tones(Int(t / s.bar))
                          s.glock(s.space, at: t, midi: Double(tones[Int(s.rand() * Double(tones.count))] + 24), gain: 0.012, pan: s.rand(-0.8, 0.8))
                      }
                      t += s.beat
                  }
              }),

        // Heaven's Gate's year: a summer remembered on an old tape, warm and a little wobbly.
        NightTheme(id: "summer-of-96", name: "Summer of '96", day: "",
              bpm: 74,
              chords: [("Eb2 G3 Bb3 D4", 2), ("C2 G3 Bb3 D4 Eb4", 2), ("Ab1 G3 C4 Eb4", 2), ("Bb1 F3 Bb3 Eb4", 1), ("Bb1 F3 Bb3 D4", 1),
                       ("Eb2 G3 Bb3 D4", 2), ("G1 F3 Bb3 D4", 2), ("Ab1 C4 D4 G4", 2), ("Bb1 F3 G3 D4", 2)],
              melody: "r/2 G5/2 | Bb5/3 G5/1 | Eb5/4 | r/4 | r/2 Eb5/1 F5/1 | G5/4 | F5/2 D5/2 | r/4 | r/2 G5/2 | Bb5/3 C6/1 | Bb5/2 G5/2 | F5/4 | r/2 Eb5/1 D5/1 | C5/4 | D5/4 | r/4",
              verb: (0.6, 0.6, 0.25), wow: 0.004,
              arrange: { s in
                  let lead = s.layer("lead"), juno = s.layer("polysynth"), low = s.layer("bass")
                  s.mono(lead, s.send, s.events,
                       MonoSound(kind: .whistle, attack: 0.08, release: 0.4, glide: 0.07, vibrato: 25, vibratoDelay: 0.2, vibratoRate: 6, gain: 0.06, echo: 0.3))
                  for b in 0..<s.bars {
                      for k in [0.0, 2.0] {
                          s.pad(juno, s.tones(b), at: Double(b) * s.bar + k * s.beat, gate: 1.4 * s.beat,
                              PadSound(detune: 14, spread: 0.8, cutoff: 700, sweep: 900, q: 1.2, attack: 0.02, release: 0.9, sweepTime: 0.05, gain: 0.006, vibrato: 3, wave: 1))
                      }
                  }
                  for c in s.changes {
                      s.bass(low, at: Double(c.bar) * s.bar, midi: Double(c.notes[0]), length: Double(c.count) * s.bar * 0.97, gain: 0.06, attack: 0.05, release: 0.5)
                  }
                  s.cicadas(s.fx, length: s.loop + 4, gain: 0.012)
                  s.hiss(s.fx, length: s.loop + 8, gain: 0.005)
              }),

        // Your name at the top of the table: slow, proud, a little bit epic.
        NightTheme(id: "high-score", name: "High Score", day: "",
              bpm: 58,
              chords: [("D2 D3 A3 F#4 A4", 2), ("D2 C3 G3 E4 G4", 2), ("D2 B2 G3 D4 B4", 2), ("A1 A2 E3 A3 C#5", 2),
                       ("B1 B2 F#3 B3 D5", 2), ("G1 G2 D3 G3 B4", 2), ("E2 E3 B3 D4 G4", 2), ("A1 A2 E3 C#4 A4", 2)],
              verb: (0.95, 0.35, 0.55),
              arrange: { s in
                  let lead = s.layer("lead"), bells = s.layer("bells"), low = s.layer("bass")
                  for c in s.changes {
                      let at = Double(c.bar) * s.bar, span = Double(c.count) * s.bar
                      s.pad(lead, Array(c.notes.dropFirst()), at: at, gate: span,
                          PadSound(detune: 9, spread: 0.8, cutoff: 380, sweep: 2600, q: 1.1, attack: 2.2, release: 3.2, sweepTime: 2.8, gain: 0.014, vibrato: 6))
                      s.bass(low, at: at, midi: Double(c.notes[0]), length: span * 0.97, gain: 0.08, attack: 0.3, release: 1.5, bright: 0.3)
                      s.bell(bells, at: at, midi: Double(c.notes.last!), gain: 0.04, pan: 0.2, ratio: 2.76, index: 1.5, decay: 3)
                  }
                  s.boom(s.fx, at: 0, gain: 0.14); s.boom(s.fx, at: 8 * s.bar, gain: 0.14)
                  for b in [3, 11] {
                      let start = Double(b) * s.bar + 2 * s.beat
                      for (k, m) in [86, 88, 90, 91, 93, 95].enumerated() {
                          s.blip(s.space, at: start + Double(k) * s.beat * 0.25, midi: Double(m), length: 0.04, gain: 0.012, pan: -0.4 + 0.12 * Double(k))
                      }
                      s.blip(s.space, at: start + 1.75 * s.beat, midi: 98, length: 0.12, gain: 0.016, pan: 0.3)
                  }
              }),

        // The one fighting-game cabinet in town, glowing in a dark room, waiting for you.
        NightTheme(id: "the-only-cabinet", name: "The Only Cabinet", day: "",
              bpm: 54,
              chords: [("C#2 G#3 D#4 E4", 4), ("A1 E3 G#3 C#4", 4), ("F#1 C#3 E3 G#3 A3", 4), ("G#1 D#3 G#3 C#4", 2), ("G#1 D#3 G#3 C4", 2)],
              melody: "r/2 G#4/2 | C#5/4 | D#5/2 E5/2 | D#5/4 | r/2 E5/1 G#5/1 | G#5/4 | E5/2 C#5/2 | B4/4 | r/2 A4/1 C#5/1 | E5/4 | G#5/3 F#5/1 | E5/4 | C#5/4 | r/4 | C5/4 | r/4",
              verb: (0.97, 0.35, 0.6), echoFeedback: 0.5,
              arrange: { s in
                  for c in s.changes {
                      let at = Double(c.bar) * s.bar, span = Double(c.count) * s.bar
                      s.pad(s.layer("pad"), Array(c.notes.dropFirst()), at: at, gate: span,
                            PadSound(cutoff: 300, sweep: 700, attack: 3, release: 3.5, gain: 0.014))
                      s.bass(s.layer("bass"), at: at, midi: Double(c.notes[0]), length: span * 0.97, gain: 0.1, attack: 0.08, release: 0.8)
                  }
                  s.lead(s.layer("lead"), s.send, s.events,
                         LeadSound(cutoff: 500, sweep: 1600, q: 1.2, attack: 0.3, release: 1.2, glide: 0.12, vibrato: 30, vibratoDelay: 0.6, gain: 0.09, echo: 0.4))
                  s.hum(s.fx, length: s.loop + 2, gain: 0.006, flicker: 0)
                  for b in stride(from: 1, to: s.bars, by: 2) {
                      let tones = s.tones(b)
                      for (k, idx) in [0, 2, 1, 3].enumerated() {
                          s.blip(s.space, at: Double(b) * s.bar + s.beat * (2 + Double(k) * 0.25), midi: Double(tones[idx % tones.count] + 24),
                                 length: 0.05, gain: 0.035, pan: 0.5, cutoff: 1200)
                      }
                  }
              }),
    ]
}
