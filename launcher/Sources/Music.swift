import Foundation

/// The library's background music: seventeen themes. High Score opens; then today's
/// title takes over, the original (soft, bell-led) by day and its night version
/// (NightThemes.swift) from dusk. Each plays a couple of times, then drifts into the
/// next of its half of the day, so the library can be left on as something to
/// listen to. The name playing shows in the library's top bar.

/// One piece of library music.
enum Track: Sendable {
    case original(MusicTheme), night(NightTheme)

    var name: String {
        switch self { case .original(let t): t.name; case .night(let t): t.name }
    }
    /// "Tuesday · Rain on the Glass", "Tuesday night · Rain on the Glass", or just "High Score".
    var label: String {
        switch self {
        case .original(let t): "\(t.day) · \(t.name)"
        case .night(let t): t.day.isEmpty ? t.name : "\(t.day) night · \(t.name)"
        }
    }
    var length: Double {
        switch self { case .original(let t): t.length; case .night(let t): t.length }
    }
    var isNight: Bool { if case .night = self { true } else { false } }

    /// Stereo samples, ready to loop (an original is mono, on both sides).
    func render() -> (left: [Float], right: [Float]) {
        switch self {
        case .original(let t): let samples = Music.render(t); return (samples, samples)
        case .night(let t): return t.render()
        }
    }
}

/// One of the seven originals.
struct MusicTheme: Sendable {
    let name: String
    let day: String
    let bpm: Double
    /// MIDI notes, lowest first; each chord lasts `barsPerChord` bars.
    let chords: [[Int]]
    let barsPerChord: Int
    /// A faint, sparse arpeggio, only where a theme wants a retro wink.
    let arpeggio: Synth.Wave?
    let seed: UInt64

    var bar: Double { 4 * 60 / bpm }
    var length: Double { Double(chords.count * barsPerChord) * bar }
}

enum Music {
    /// Sunday first, matching Calendar's weekday numbering (1 = Sunday).
    static let themes: [MusicTheme] = [
        MusicTheme(name: "Dusk at the Pool", day: "Sunday", bpm: 60,
              chords: [[55, 59, 62, 66], [52, 55, 59, 62], [48, 55, 59, 62], [50, 54, 57, 59]],
              barsPerChord: 2, arpeggio: nil, seed: 7),
        MusicTheme(name: "First Coin", day: "Monday", bpm: 72,
              chords: [[48, 52, 55, 59], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 64]],
              barsPerChord: 2, arpeggio: nil, seed: 11),
        MusicTheme(name: "Rain on the Glass", day: "Tuesday", bpm: 64,
              chords: [[50, 53, 57, 64], [46, 50, 53, 57], [55, 58, 62, 65], [57, 62, 64, 67]],
              barsPerChord: 2, arpeggio: nil, seed: 23),
        MusicTheme(name: "Neon Drift", day: "Wednesday", bpm: 84,
              chords: [[52, 55, 59, 66], [57, 61, 66, 67], [48, 52, 55, 59], [47, 50, 54, 57]],
              barsPerChord: 2, arpeggio: .sine, seed: 31),
        MusicTheme(name: "Attract Mode", day: "Thursday", bpm: 76,
              chords: [[53, 57, 59, 64], [55, 59, 62, 64], [52, 55, 59, 62], [57, 60, 64, 67]],
              barsPerChord: 2, arpeggio: nil, seed: 43),
        MusicTheme(name: "Last Credit", day: "Friday", bpm: 80,
              chords: [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [52, 55, 59, 62],
                       [50, 53, 57, 60], [53, 57, 60, 64], [48, 55, 60, 62], [55, 59, 62, 64]],
              barsPerChord: 1, arpeggio: nil, seed: 53),
        MusicTheme(name: "Free Play", day: "Saturday", bpm: 92,
              chords: [[46, 50, 53, 57], [55, 58, 62, 65], [51, 55, 58, 62], [53, 57, 60, 62]],
              barsPerChord: 2, arpeggio: .square, seed: 61),
    ]

    /// Today's original.
    static func todayIndex(_ date: Date = Date()) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    // MARK: The playlist

    /// Every track, in the order ← → steps through them in Settings: High Score, then
    /// each day's original and night version, then the night themes without a day.
    static let tracks: [Track] = {
        let nights = NightTheme.all
        var list: [Track] = nights.filter { $0.name == "High Score" }.map(Track.night)
        for theme in themes {
            list.append(.original(theme))
            list += nights.filter { $0.day == theme.day }.map(Track.night)
        }
        list += nights.filter { $0.day.isEmpty && $0.name != "High Score" }.map(Track.night)
        return list
    }()
    /// Plays first whenever Coinless opens.
    static let opening = tracks.firstIndex { $0.name == "High Score" } ?? 0

    /// Night runs from 6 pm to 6 am.
    static func isNight(_ date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 18 || hour < 6
    }

    /// Each half of the day's tracks, in the order they drift: the originals by weekday;
    /// at night, each weekday's night theme, then the ones without a day.
    private static func order(night: Bool) -> [Int] {
        let days = themes.map(\.day)
        func rank(_ track: Track) -> Int {
            switch track {
            case .original(let t): days.firstIndex(of: t.day) ?? 0
            case .night(let t): days.firstIndex(of: t.day) ?? days.count
            }
        }
        return tracks.indices.filter { tracks[$0].isNight == night }.sorted { (rank(tracks[$0]), $0) < (rank(tracks[$1]), $1) }
    }

    /// Today's title, in the version for the time of day.
    static func today(_ date: Date = Date()) -> Int {
        let day = themes[todayIndex(date)].day, night = isNight(date)
        return tracks.firstIndex { track in
            switch track {
            case .original(let t): !night && t.day == day
            case .night(let t): night && t.day == day
            }
        } ?? opening
    }

    /// What plays after `index`: the next of this half of the day's tracks, or today's
    /// when `index` belongs to the other half (the evening turning into night).
    static func next(after index: Int, date: Date = Date()) -> Int {
        let list = order(night: isNight(date))
        guard let position = list.firstIndex(of: index) else { return today(date) }
        return list[(position + 1) % list.count]
    }

    /// One theme, ready to loop: a slow detuned pad, a soft bass note per chord, a
    /// sparse bell melody moving to the nearest chord tone, and (in a couple of themes)
    /// a faint arpeggio of at most two notes a bar. A gentle echo gives it space; the
    /// tail is folded onto the start so it loops without a seam; every theme is levelled
    /// to the same quiet peak.
    static func render(_ theme: MusicTheme) -> [Float] {
        typealias Note = Synth.Note
        var random = theme.seed
        func chance(_ p: Double) -> Bool {
            random = random &* 6364136223846793005 &+ 1442695040888963407
            return Double(random >> 11) / Double(1 << 53) < p
        }
        let beat = theme.bar / 4
        var pad: [Note] = [], melody: [Note] = []
        var previous = theme.chords[0][2] + 12

        for (index, chord) in theme.chords.enumerated() {
            let start = Double(index * theme.barsPerChord) * theme.bar
            let span = Double(theme.barsPerChord) * theme.bar
            for midi in chord {
                for detune in [0.996, 1.004] {
                    let hz = Synth.hz(midi) * detune
                    pad.append(Note(at: start, from: hz, to: hz, length: span + 1.5, gain: 0.006, attack: 1.4, decay: 1.1))
                }
                let hz = Synth.hz(midi)
                pad.append(Note(at: start, from: hz, to: hz, length: span + 1.5, wave: .sine, gain: 0.008, attack: 1.4, decay: 1.1))
            }
            let bass = Synth.hz(chord[0] - 12)
            pad.append(Note(at: start, from: bass, to: bass, length: span * 0.95, wave: .sine, gain: 0.05, attack: 0.05, decay: 2.2))

            for barIndex in 0..<theme.barsPerChord {
                let barStart = start + Double(barIndex) * theme.bar
                // The melody: a note on the downbeat most bars, an answer on beat 3 now and then.
                for (offset, probability) in [(0.0, barIndex == 0 ? 0.9 : 0.55), (2.5, 0.3)] where chance(probability) {
                    let tones = chord.flatMap { [$0 + 12, $0 + 24] }.filter { (64...84).contains($0) }
                    // The nearest chord tone that isn't the last note: a line that moves gently.
                    let note = tones.filter { $0 != previous }.min { abs($0 - previous) < abs($1 - previous) } ?? previous
                    previous = note
                    let hz = Synth.hz(note)
                    melody.append(Note(at: barStart + offset * beat, from: hz, to: hz, length: 2.6, wave: .bell,
                                       gain: 0.045, attack: 0.008, decay: 3.2))
                }
                if let wave = theme.arpeggio, barIndex % 2 == 1 || theme.barsPerChord == 1 {
                    for (offset, voice) in [(1.0, 1), (3.0, 3)] {
                        let hz = Synth.hz(chord[voice] + 12)
                        melody.append(Note(at: barStart + offset * beat, from: hz, to: hz, length: 0.45, wave: wave,
                                           gain: wave == .square ? 0.006 : 0.012, attack: 0.008, decay: 5))
                    }
                }
            }
        }

        let tail = 3.5
        let dry = Synth.render(pad, length: theme.length + tail)
        let bells = Synth.render(melody, length: theme.length + tail)
        var out = dry
        // A soft echo on the melody, in time with the beat (a dotted eighth and a half note).
        let taps: [(Double, Float)] = [(0.75 * beat, 0.32), (2 * beat, 0.18), (3.5 * beat, 0.09)]
        for i in out.indices {
            var value = bells[i]
            for (delay, gain) in taps {
                let j = i - Int(delay * Synth.sampleRate)
                if j >= 0 { value += bells[j] * gain }
            }
            out[i] += value
        }
        let total = Int(theme.length * Synth.sampleRate)
        for i in total..<out.count { out[i - total] += out[i] }
        out.removeLast(out.count - total)
        var smooth: Float = 0
        for i in out.indices { smooth += (out[i] - smooth) * 0.45; out[i] = smooth }
        let peak = out.map { abs($0) }.max() ?? 1
        let scale = peak > 0 ? 0.07 / peak : 1
        for i in out.indices { out[i] *= scale }
        return out
    }
}
