import Foundation

/// The night themes' synthesiser (NightThemes.swift): a stereo buffer, a filter,
/// band-limited oscillators, and the sustained voices: CS-80-style pads, a gliding
/// lead, breathy and sung solo voices, and a choir. Instruments.swift and
/// Ambience.swift add the struck instruments, textures and effects.

/// Two channels of samples, mixed into by every instrument.
final class StereoMix {
    var l: [Float], r: [Float]
    init(_ n: Int) { l = [Float](repeating: 0, count: n); r = l }
    var count: Int { l.count }
    @inline(__always) func add(_ i: Int, _ v: Double, _ g: (Double, Double)) {
        if i < 0 || i >= l.count { return }
        l[i] += Float(v * g.0); r[i] += Float(v * g.1)
    }
    func add(_ other: StereoMix, _ gain: Float = 1) {
        for i in 0..<min(count, other.count) { l[i] += other.l[i] * gain; r[i] += other.r[i] * gain }
    }
    var rms: Double {
        var sum = 0.0
        for i in 0..<count { sum += Double(l[i] * l[i] + r[i] * r[i]) }
        return sqrt(sum / Double(max(1, 2 * count)))
    }
}

/// Zero-delay-feedback state-variable filter.
struct SVF {
    var ic1 = 0.0, ic2 = 0.0, g = 0.1, k = 1.0
    mutating func tune(_ cutoff: Double, q: Double) {
        g = tan(.pi * min(max(cutoff, 20), Synth.sampleRate * 0.45) / Synth.sampleRate); k = 1 / q
    }
    @inline(__always) mutating func run(_ x: Double) -> (lp: Double, bp: Double) {
        let a1 = 1 / (1 + g * (g + k)), a2 = g * a1, a3 = g * a2
        let v3 = x - ic2, v1 = a1 * ic1 + a2 * v3, v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1; ic2 = 2 * v2 - ic2
        return (v2, v1)
    }
}

/// Renders one theme: owns its random numbers (seeded, so a theme always sounds the
/// same), and every instrument is a method. Made and used inside one render task.
class Studio {
    let sr = Synth.sampleRate
    private var seed: UInt64
    init(seed: UInt64) { self.seed = seed | 1 }

    func rand() -> Double {
        seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
        return Double(seed >> 11) / Double(UInt64(1) << 53)
    }
    func rand(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * rand() }
    func white() -> Double { rand() * 2 - 1 }
    func hz(_ m: Double) -> Double { 440 * pow(2, (m - 69) / 12) }
    func pan(_ p: Double) -> (Double, Double) { let a = (p + 1) * .pi / 4; return (cos(a), sin(a)) }

    @inline(__always) func blep(_ t: Double, _ dt: Double) -> Double {
        if t < dt { let x = t / dt; return x + x - x * x - 1 }
        if t > 1 - dt { let x = (t - 1) / dt; return x * x + x + x + 1 }
        return 0
    }
    @inline(__always) func saw(_ t: Double, _ dt: Double) -> Double { 2 * t - 1 - blep(t, dt) }
    @inline(__always) func square(_ t: Double, _ dt: Double) -> Double {
        var t2 = t + 0.5; if t2 >= 1 { t2 -= 1 }
        return (t < 0.5 ? 1 : -1) + blep(t, dt) - blep(t2, dt)
    }
    @inline(__always) func tri(_ t: Double) -> Double { 4 * abs(t - 0.5) - 1 }
}

/// CS-80-ish brass and string pads: three detuned oscillators per note, a resonant
/// low-pass that sweeps open as the chord swells, and a slow vibrato.
struct PadSound {
    var detune = 8.0, spread = 0.7, cutoff = 450.0, sweep = 1400.0, q = 0.85
    var attack = 1.4, release = 2.5, sweepTime = 2.0, gain = 0.022, vibrato = 4.0, wave = 0
}

struct NoteEvent { var at: Double; var midi: Double; var length: Double }

/// A monophonic lead that glides between legato notes, with vibrato that blooms
/// a moment after each note starts.
struct LeadSound {
    var saw = 1.0, square = 0.0, sine = 0.0, sub = 0.0, detune = 7.0
    var cutoff = 650.0, sweep = 2200.0, q = 1.1, attack = 0.08, release = 0.5
    var glide = 0.08, vibrato = 22.0, vibratoDelay = 0.45, gain = 0.085, echo = 0.32, pan = 0.0
}

enum MonoKind { case sax, flute, whistle, chip, choir }

/// Breathy and vocal solo voices: a flute, a whistle, a sax and a sung "ah" through
/// formant filters, and a chip square. Same glide and blooming vibrato as the lead.
struct MonoSound {
    var kind = MonoKind.flute, attack = 0.1, release = 0.5, glide = 0.07, vibrato = 15.0, vibratoDelay = 0.4, vibratoRate = 5.2
    var gain = 0.07, echo = 0.3, pan = 0.0
}

extension Studio {
    func pad(_ m: StereoMix, _ notes: [Int], at: Double, gate: Double, _ s: PadSound) {
        let start = Int(at * sr), n = Int((gate + s.release * 1.6) * sr)
        let offsets = [-s.detune, 0, s.detune], pans = [-s.spread, 0, s.spread]
        for midi in notes {
            for k in 0..<3 {
                let f = hz(Double(midi) + offsets[k] / 100), g = pan(pans[k])
                var phase = rand(), filter = SVF(), lfo = rand() * 2 * .pi
                let lfoStep = rand(4.6, 5.6) * 2 * .pi / sr
                let track = pow(f / 262, 0.3)
                for i in 0..<n {
                    let t = Double(i) / sr
                    var a = t < s.attack ? sin(.pi / 2 * t / s.attack) : 1
                    if t > gate { a *= exp(-(t - gate) * 3 / s.release) }
                    var fe = min(1, t / s.sweepTime); fe = fe * fe * (3 - 2 * fe)
                    fe *= 0.6 + 0.4 * exp(-max(0, t - s.sweepTime) / 3)
                    if t > gate { fe *= exp(-(t - gate) * 2 / s.release) }
                    if i & 15 == 0 { filter.tune((s.cutoff + s.sweep * fe) * track, q: s.q) }
                    lfo += lfoStep
                    let freq = f * (1 + s.vibrato / 1731 * sin(lfo) * min(1, t / 2))
                    let dt = freq / sr
                    phase += dt; if phase >= 1 { phase -= 1 }
                    let osc: Double
                    switch s.wave {
                    case 1: osc = square(phase, dt) * 0.7
                    case 2: osc = tri(phase)
                    default: osc = saw(phase, dt)
                    }
                    m.add(start + i, filter.run(osc).lp * a * s.gain, g)
                }
            }
        }
    }

    func lead(_ m: StereoMix, _ send: StereoMix, _ events: [NoteEvent], _ s: LeadSound) {
        guard let first = events.first, let last = events.last else { return }
        let begin = Int(first.at * sr), end = min(m.count, Int((last.at + last.length + s.release * 5) * sr))
        var index = 0, pitch = first.midi, env = 0.0, noteStart = first.at, active = false
        var p1 = rand(), p2 = rand(), p3 = rand(), filter = SVF(), vib = 0.0
        let attackK = 1 - exp(-1 / (s.attack * sr)), releaseK = exp(-3 / (s.release * sr)), glideK = 1 - exp(-1 / (s.glide * sr))
        let g = pan(s.pan)
        for i in begin..<end {
            let t = Double(i) / sr
            while index + 1 < events.count && t >= events[index + 1].at { index += 1 }
            let e = events[index]
            let gate = t >= e.at && t < e.at + e.length * 0.97
            if gate && (!active || noteStart != e.at) {
                if !active && env < 0.08 { pitch = e.midi }
                noteStart = e.at
            }
            active = gate
            pitch += (e.midi - pitch) * glideK
            env = gate ? env + (1 - env) * attackK : env * releaseK
            vib += 2 * .pi * 5.3 / sr
            let depth = s.vibrato * min(1, max(0, t - noteStart - s.vibratoDelay) / 0.8)
            let f = hz(pitch + depth / 100 * sin(vib)), dt = f / sr
            p1 += dt; if p1 >= 1 { p1 -= 1 }
            let dt2 = dt * (1 + s.detune / 1731); p2 += dt2; if p2 >= 1 { p2 -= 1 }
            p3 += dt / 2; if p3 >= 1 { p3 -= 1 }
            var osc = s.saw * (saw(p1, dt) + saw(p2, dt2)) * 0.5
            osc += s.square * (square(p1, dt) + square(p2, dt2)) * 0.35
            osc += s.sine * sin(2 * .pi * p1) + s.sub * sin(2 * .pi * p3)
            if i & 15 == 0 { filter.tune((s.cutoff + s.sweep * env * env) * pow(f / 523, 0.5), q: s.q) }
            let y = filter.run(osc).lp * env * s.gain
            m.add(i, y, g); send.add(i, y * s.echo, g)
        }
    }

    func mono(_ m: StereoMix, _ send: StereoMix, _ events: [NoteEvent], _ s: MonoSound) {
        guard let first = events.first, let last = events.last else { return }
        let begin = Int(first.at * sr), end = min(m.count, Int((last.at + last.length + s.release * 5) * sr))
        var index = 0, pitch = first.midi, env = 0.0, noteStart = first.at, active = false
        var p1 = rand(), p2 = rand(), vib = 0.0
        var f1 = SVF(), f2 = SVF(), f3 = SVF(), breath = SVF(), tone = SVF()
        let formants: [(Double, Double, Double)]
        switch s.kind {
        case .sax: formants = [(520, 4, 1), (1450, 5, 0.7), (2550, 6, 0.35)]
        case .choir: formants = [(760, 6, 1), (1180, 7, 0.55), (2600, 8, 0.25)]
        default: formants = [(500, 1, 0), (1000, 1, 0), (2000, 1, 0)]
        }
        f1.tune(formants[0].0, q: formants[0].1); f2.tune(formants[1].0, q: formants[1].1); f3.tune(formants[2].0, q: formants[2].1)
        tone.tune(s.kind == .chip ? 2600 : 3400, q: 0.7)
        let attackK = 1 - exp(-1 / (s.attack * sr)), releaseK = exp(-3 / (s.release * sr)), glideK = 1 - exp(-1 / (s.glide * sr))
        let g = pan(s.pan)
        for i in begin..<end {
            let t = Double(i) / sr
            while index + 1 < events.count && t >= events[index + 1].at { index += 1 }
            let e = events[index]
            let gate = t >= e.at && t < e.at + e.length * 0.97
            if gate && (!active || noteStart != e.at) {
                if !active && env < 0.08 { pitch = e.midi }
                noteStart = e.at
            }
            active = gate
            pitch += (e.midi - pitch) * glideK
            env = gate ? env + (1 - env) * attackK : env * releaseK
            vib += 2 * .pi * s.vibratoRate / sr
            let depth = s.vibrato * min(1, max(0, t - noteStart - s.vibratoDelay) / 0.6)
            let f = hz(pitch + depth / 100 * sin(vib)), dt = f / sr
            p1 += dt; if p1 >= 1 { p1 -= 1 }
            p2 += dt * (1 + 5 / 1731); if p2 >= 1 { p2 -= 1 }
            var y: Double
            switch s.kind {
            case .flute:
                if i & 31 == 0 { breath.tune(f * 2, q: 1.5) }
                y = sin(2 * .pi * p1) + 0.18 * sin(4 * .pi * p1) + breath.run(white()).bp * breath.k * 0.35
            case .whistle:
                if i & 31 == 0 { breath.tune(f, q: 6) }
                y = sin(2 * .pi * p1) + breath.run(white()).bp * breath.k * 0.12
            case .chip:
                y = tone.run(square(p1, dt) * 0.6).lp
            case .sax, .choir:
                let src = 0.6 * saw(p1, dt) + 0.4 * saw(p2, dt) + white() * (s.kind == .sax ? 0.22 : 0.05)
                y = f1.run(src).bp * f1.k * formants[0].2 + f2.run(src).bp * f2.k * formants[1].2 + f3.run(src).bp * f3.k * formants[2].2
                y = tone.run(y * 2.5).lp
            }
            let out = y * env * s.gain
            m.add(i, out, g); send.add(i, out * s.echo, g)
        }
    }

    /// A choir pad: detuned saws sung through "ah" formants, each voice with its own vibrato.
    func choirPad(_ m: StereoMix, _ notes: [Int], at: Double, gate: Double, gain: Double, attack: Double = 2, release: Double = 3) {
        let start = Int(at * sr), n = Int((gate + release * 1.5) * sr)
        for (j, midi) in notes.enumerated() {
            for k in 0..<3 {
                let f = hz(Double(midi) + [-7.0, 0, 7][k] / 100), g = pan([-0.6, 0.1, 0.6][k] * (j % 2 == 0 ? 1 : -1))
                var phase = rand(), vib = rand() * 2 * .pi, a1 = SVF(), a2 = SVF(), a3 = SVF()
                a1.tune(760 * rand(0.97, 1.03), q: 6); a2.tune(1180, q: 7); a3.tune(2600, q: 8)
                let rate = rand(4.8, 5.8) * 2 * .pi / sr
                for i in 0..<n {
                    let t = Double(i) / sr
                    var a = t < attack ? sin(.pi / 2 * t / attack) : 1
                    if t > gate { a *= exp(-(t - gate) * 3 / release) }
                    vib += rate
                    let dt = f * (1 + 14 / 1731 * sin(vib)) / sr
                    phase += dt; if phase >= 1 { phase -= 1 }
                    let src = saw(phase, dt) + white() * 0.04
                    let y = a1.run(src).bp * a1.k + a2.run(src).bp * a2.k * 0.5 + a3.run(src).bp * a3.k * 0.22
                    m.add(start + i, y * a * gain, g)
                }
            }
        }
    }
}
