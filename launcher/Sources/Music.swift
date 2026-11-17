import Foundation

/// The library's background music: seven original themes, one for each day of
/// the week. The app opens on today's theme (its name shows in the library's
/// top bar), plays it a couple of times, then drifts into the next, so the
/// library can be left on as something to listen to.
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

    /// Today's theme.
    static func todayIndex(_ date: Date = Date()) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
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
