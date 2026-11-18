import Foundation

/// Struck and plucked instruments for the night themes: bells (FM), a felt piano, an
/// electric piano, a music box, a glockenspiel, a harp, sequencer plucks, chip
/// sounds, bass, drums, and the arcade's own noises (a coin, a clock tick, a drop).
extension Studio {
    /// FM bell: ratio 1 is an electric piano, 3.5 a bell, 2.76 metal.
    func bell(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double = 0, ratio: Double = 3.5,
              index: Double = 2, decay: Double = 1.6) {
        let start = Int(at * sr), n = Int(min(8, decay * 5) * sr), f = hz(midi), g = pan(p)
        for i in 0..<n {
            let t = Double(i) / sr
            let mod = index * exp(-t * 4 / decay) * sin(2 * .pi * f * ratio * t)
            let a = min(1, t / 0.002) * exp(-t / decay)
            m.add(start + i, sin(2 * .pi * f * t + mod) * a * gain, g)
        }
    }

    /// A soft felt piano: slightly stretched partials, the high ones dying first, a hint of hammer.
    func piano(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double = 0, length: Double = 3, soft: Double = 0.6) {
        let f = hz(midi), start = Int(at * sr), g = pan(p), n = Int((length + 0.6) * sr)
        var partials: [(w: Double, amp: Double, decay: Double)] = []
        for k in 1...10 {
            let fk = f * Double(k) * sqrt(1 + 0.0003 * Double(k * k))
            if fk > 9000 { break }
            partials.append((2 * .pi * fk / sr, pow(Double(k), -1.2) * exp(-Double(k - 1) * soft * 0.45),
                             2.8 * pow(262 / f, 0.45) / (1 + 0.6 * Double(k - 1))))
        }
        var hammer = SVF(); hammer.tune(1800, q: 0.7)
        for i in 0..<n {
            let t = Double(i) / sr
            var v = 0.0
            for p in partials { v += sin(p.w * Double(i)) * p.amp * (0.75 * exp(-t / p.decay) + 0.25 * exp(-t / (p.decay * 5))) }
            v += hammer.run(white()).lp * exp(-t / 0.004) * 0.6
            var a = min(1, t / 0.002)
            if t > length { a *= exp(-(t - length) / 0.12) }
            m.add(start + i, v * a * gain, g)
        }
    }

    /// An electric piano (FM, ratio 1) with a tine and a gentle stereo tremolo.
    func ep(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double = 0, length: Double = 2) {
        let f = hz(midi), start = Int(at * sr), n = Int((length + 0.5) * sr)
        let decay = 2.4 * pow(262 / f, 0.3), w = 2 * .pi * f / sr
        for i in 0..<n {
            let t = Double(i) / sr, x = Double(i)
            let mod = 1.4 * exp(-t * 2.2) * sin(w * x)
            let v = sin(w * x + mod) + 0.2 * exp(-t * 16) * sin(w * 13.9 * x)
            var a = min(1, t / 0.003) * exp(-t / decay)
            if t > length { a *= exp(-(t - length) / 0.15) }
            let trem = 0.3 * sin(2 * .pi * 4.2 * t + midi)
            m.add(start + i, v * a * gain, ((1 - trem) * 0.7 * (1 - p * 0.5), (1 + trem) * 0.7 * (1 + p * 0.5)))
        }
    }

    func musicBox(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double = 0) {
        bell(m, at: at, midi: midi, gain: gain, pan: p, ratio: 4.0, index: 0.7, decay: 0.8)
        bell(m, at: at, midi: midi, gain: gain * 0.5, pan: p, ratio: 1, index: 0.2, decay: 1.4)
    }

    func glock(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double = 0) {
        bell(m, at: at, midi: midi, gain: gain, pan: p, ratio: 2.76, index: 0.45, decay: 1.5)
        bell(m, at: at, midi: midi, gain: gain * 0.4, pan: p, ratio: 1, index: 0.1, decay: 0.8)
    }

    /// A plucked harp string (Karplus-Strong).
    func harp(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double = 0, decay: Double = 3) {
        let f = hz(midi), period = max(2, Int((sr / f).rounded())), start = Int(at * sr), g = pan(p)
        var buf = [Double](repeating: 0, count: period), smooth = 0.0
        for k in 0..<period { smooth += (white() - smooth) * 0.55; buf[k] = smooth }
        let loss = pow(0.001, 1 / (decay * f)), n = Int(decay * 1.2 * sr)
        var idx = 0, prev = 0.0
        for i in 0..<n {
            let y = buf[idx]
            buf[idx] = loss * (0.5 * y + 0.5 * prev); prev = y
            idx += 1; if idx == period { idx = 0 }
            m.add(start + i, y * gain * min(1, Double(i) / 30), g)
        }
    }

    /// A sequencer pluck: a saw whose filter snaps shut.
    func pluck(_ m: StereoMix, at: Double, midi: Double, gain: Double, pan p: Double, cutoff: Double, sweep: Double,
               decay: Double = 0.3, q: Double = 2.2, wave: Int = 0) {
        let start = Int(at * sr), n = Int(decay * 4 * sr), f = hz(midi), dt = f / sr, g = pan(p)
        var phase = rand(), filter = SVF()
        for i in 0..<n {
            let t = Double(i) / sr
            if i & 7 == 0 { filter.tune(cutoff + sweep * exp(-t / (decay * 0.45)), q: q) }
            phase += dt; if phase >= 1 { phase -= 1 }
            let osc = wave == 1 ? square(phase, dt) * 0.6 : saw(phase, dt)
            m.add(start + i, filter.run(osc).lp * min(1, t / 0.003) * exp(-t / decay) * gain, g)
        }
    }

    /// A chip blip: a short, softened square.
    func blip(_ m: StereoMix, at: Double, midi: Double, length: Double, gain: Double, pan p: Double = 0, cutoff: Double = 3000) {
        let start = Int(at * sr), n = Int((length + 0.05) * sr), f = hz(midi), dt = f / sr, g = pan(p)
        var phase = 0.0, filter = SVF(); filter.tune(cutoff, q: 0.7)
        for i in 0..<n {
            let t = Double(i) / sr
            phase += dt; if phase >= 1 { phase -= 1 }
            let a = min(1, t / 0.002) * (t < length ? 1 : exp(-(t - length) / 0.01))
            m.add(start + i, filter.run(square(phase, dt)).lp * a * gain, g)
        }
    }

    /// A stepped triangle, the old consoles' bass.
    func chipTri(_ m: StereoMix, at: Double, midi: Double, length: Double, gain: Double) {
        let f = hz(midi), start = Int(at * sr), n = Int((length + 0.02) * sr), g = pan(0)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            phase += f / sr; if phase >= 1 { phase -= 1 }
            let a = t < length ? 1 : exp(-(t - length) / 0.005)
            m.add(start + i, (tri(phase) * 8).rounded() / 8 * a * gain, g)
        }
    }

    func bass(_ m: StereoMix, at: Double, midi: Double, length: Double, gain: Double, attack: Double = 0.04,
              release: Double = 0.5, bright: Double = 0.25) {
        let start = Int(at * sr), n = Int((length + release * 4) * sr), f = hz(midi), dt = f / sr, g = pan(0)
        var phase = rand(), filter = SVF(); filter.tune(180 + f * 2, q: 0.8)
        for i in 0..<n {
            let t = Double(i) / sr
            phase += dt; if phase >= 1 { phase -= 1 }
            var a = min(1, t / attack)
            if t > length { a *= exp(-(t - length) / release) }
            let osc = sin(2 * .pi * phase) + bright * saw(phase, dt)
            m.add(start + i, filter.run(osc).lp * a * gain, g)
        }
    }

    /// A cinematic low drum: a sine falling in pitch, with a breath of noise.
    func boom(_ m: StereoMix, at: Double, gain: Double) {
        let start = Int(at * sr), n = Int(3 * sr), g = pan(0)
        var phase = 0.0, filter = SVF(); filter.tune(160, q: 0.7)
        for i in 0..<n {
            let t = Double(i) / sr
            phase += (36 + 54 * exp(-t * 7)) / sr
            let body = sin(2 * .pi * phase) * exp(-t / 0.9)
            let air = filter.run(white()).lp * exp(-t / 0.25) * 0.6
            m.add(start + i, (body + air) * min(1, t / 0.004) * gain, g)
        }
    }

    func tick(_ m: StereoMix, at: Double, gain: Double, pan p: Double = 0, tone: Double = 3400) {
        let start = Int(at * sr), n = Int(0.05 * sr), g = pan(p)
        var filter = SVF(); filter.tune(tone, q: 3)
        for i in 0..<n {
            let t = Double(i) / sr
            m.add(start + i, filter.run(white()).bp * exp(-t / 0.006) * gain, g)
        }
    }

    /// A water drop: a sine that falls a little in pitch, very short.
    func drop(_ m: StereoMix, at: Double, freq: Double, gain: Double, pan p: Double, length: Double = 0.012) {
        let start = Int(at * sr), n = Int(length * 6 * sr), g = pan(p)
        var phase = 0.0
        for i in 0..<n {
            let t = Double(i) / sr
            phase += freq * (1 + 0.6 * exp(-t * 90)) / sr
            m.add(start + i, sin(2 * .pi * phase) * min(1, t / 0.0008) * exp(-t / length) * gain, g)
        }
    }

    /// A coin into the slot: two metal tinks, a short roll, and the credit landing.
    func coin(_ m: StereoMix, at: Double, gain: Double) {
        bell(m, at: at, midi: 98, gain: gain, pan: 0.15, ratio: 2.76, index: 1.3, decay: 0.22)
        bell(m, at: at + 0.1, midi: 103, gain: gain * 0.85, pan: -0.1, ratio: 2.76, index: 1.1, decay: 0.3)
        var t = at + 0.24
        for k in 0..<5 {
            bell(m, at: t, midi: 100 - Double(k), gain: gain * 0.4 * pow(0.7, Double(k)), pan: 0.05, ratio: 2.76, index: 0.8, decay: 0.06)
            t += 0.045 + Double(k) * 0.012
        }
        bass(m, at: t + 0.05, midi: 40, length: 0.05, gain: gain * 0.9, attack: 0.002, release: 0.08, bright: 0.6)
    }
}
