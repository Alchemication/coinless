import Foundation

/// The night themes' surroundings and space: rain, water, crickets, cicadas, mains hum,
/// tape hiss; then the effects: a ping-pong echo, a reverb, tape wow and a bit-crusher.
extension Studio {
    /// Rain on a window: two bands of noise that breathe, small drops all over and a
    /// heavier drip now and then.
    func rain(_ m: StereoMix, length: Double, gain: Double, drops: Double) {
        let n = min(m.count, Int(length * sr))
        var hiL = SVF(), hiR = SVF(), loL = SVF(), loR = SVF()
        hiL.tune(3200, q: 0.5); hiR.tune(3000, q: 0.5); loL.tune(650, q: 0.5); loR.tune(700, q: 0.5)
        var level = 0.85, target = 0.85
        for i in 0..<n {
            if i % 22050 == 0 { target = rand(0.6, 1.0) }
            level += (target - level) * 0.00002
            let a = white(), b = white()
            m.l[i] += Float((hiL.run(a).bp * 0.9 + loL.run(a).lp * 0.45) * gain * level)
            m.r[i] += Float((hiR.run(b).bp * 0.9 + loR.run(b).lp * 0.45) * gain * level)
            if rand() < drops / sr {
                drop(m, at: Double(i) / sr, freq: rand(1800, 5200), gain: gain * rand(0.8, 3), pan: rand(-0.85, 0.85))
            }
            if rand() < 0.55 / sr {
                drop(m, at: Double(i) / sr, freq: rand(700, 1300), gain: gain * rand(4, 7), pan: rand(-0.5, 0.5), length: 0.03)
            }
        }
    }

    /// Water lapping at the edge of a pool, swelling with a slow period.
    func water(_ m: StereoMix, length: Double, gain: Double, period: Double) {
        let n = min(m.count, Int(length * sr))
        var fl = SVF(), fr = SVF(); fl.tune(380, q: 0.8); fr.tune(420, q: 0.8)
        for i in 0..<n {
            let t = Double(i) / sr
            let swell = pow(0.5 - 0.5 * cos(2 * .pi * t / period), 2)
            let a = 0.25 + 0.75 * swell
            m.l[i] += Float(fl.run(white()).lp * gain * a)
            m.r[i] += Float(fr.run(white()).lp * gain * (0.25 + 0.75 * pow(0.5 - 0.5 * cos(2 * .pi * t / period + 1.3), 2)))
        }
    }

    /// Summer-evening crickets: chirps of three quick pulses, here and there.
    func crickets(_ m: StereoMix, length: Double, gain: Double) {
        var t = rand(0.3, 1.2)
        while t < length {
            let g = pan(rand(-0.9, 0.9)), f = rand(4100, 4700), level = gain * rand(0.5, 1)
            for pulse in 0..<3 {
                let start = Int((t + Double(pulse) * 0.05) * sr), n = Int(0.032 * sr)
                for i in 0..<n {
                    let u = Double(i) / sr, env = pow(sin(.pi * u / 0.032), 2)
                    m.add(start + i, sin(2 * .pi * f * u) * env * level, g)
                }
            }
            t += rand(0.9, 2.4)
        }
    }

    /// Cicadas in the heat: a high buzz that pulses and swells.
    func cicadas(_ m: StereoMix, length: Double, gain: Double) {
        let n = min(m.count, Int(length * sr))
        var fl = SVF(), fr = SVF(); fl.tune(6200, q: 6); fr.tune(5800, q: 6)
        for i in 0..<n {
            let t = Double(i) / sr
            let buzz = pow(0.5 + 0.5 * sin(2 * .pi * 47 * t), 4)
            let swell = 0.3 + 0.7 * pow(0.5 - 0.5 * cos(2 * .pi * t / 7.3), 2)
            let swell2 = 0.3 + 0.7 * pow(0.5 - 0.5 * cos(2 * .pi * t / 9.1 + 2), 2)
            m.l[i] += Float(fl.run(white()).bp * buzz * swell * gain)
            m.r[i] += Float(fr.run(white()).bp * buzz * swell2 * gain)
        }
    }

    /// Mains hum (50 Hz, as in Poland). Flicker makes it a buzzing neon tube.
    func hum(_ m: StereoMix, length: Double, gain: Double, flicker: Double) {
        let n = min(m.count, Int(length * sr))
        var dip = 0, crackle = SVF(); crackle.tune(2500, q: 1)
        let g = pan(0.15)
        for i in 0..<n {
            let t = Double(i) / sr
            var v = 0.5 * sin(2 * .pi * 50 * t) + 0.7 * sin(2 * .pi * 100 * t) + 0.5 * sin(2 * .pi * 150 * t) + 0.35 * sin(2 * .pi * 200 * t) + 0.15 * sin(2 * .pi * 250 * t)
            if dip > 0 { dip -= 1; v = v * 0.35 + crackle.run(white()).bp * 3 }
            else if rand() < flicker / sr { dip = Int(rand(0.03, 0.12) * sr) }
            m.add(i, v * gain, g)
        }
    }

    func hiss(_ m: StereoMix, length: Double, gain: Double) {
        let n = min(m.count, Int(length * sr))
        var fl = SVF(), fr = SVF(); fl.tune(5000, q: 0.5); fr.tune(5000, q: 0.5)
        for i in 0..<n { m.l[i] += Float(fl.run(white()).bp * gain); m.r[i] += Float(fr.run(white()).bp * gain) }
    }

    func pingPong(_ input: StereoMix, into out: StereoMix, delay: Double, feedback: Double) {
        let d = Int(delay * sr)
        var bl = [Double](repeating: 0, count: d), br = bl, index = 0, lpL = 0.0, lpR = 0.0
        for i in 0..<out.count {
            let x = Double(input.l[i] + input.r[i]) * 0.5
            let yl = bl[index], yr = br[index]
            lpL += (yl - lpL) * 0.3; lpR += (yr - lpR) * 0.3
            bl[index] = x + lpR * feedback; br[index] = lpL * feedback
            index += 1; if index == d { index = 0 }
            out.l[i] += Float(yl); out.r[i] += Float(yr)
        }
    }

    /// Freeverb, stereo, with a short pre-delay.
    func reverb(_ input: StereoMix, into out: StereoMix, size: Double, damp: Double, wet: Double) {
        let combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617], passes = [556, 441, 341, 225]
        var cl = combs.map { Comb($0) }, cr = combs.map { Comb($0 + 23) }
        var al = passes.map { AllPass($0) }, ar = passes.map { AllPass($0 + 23) }
        let fb = Float(0.7 + 0.28 * size), dm = Float(damp), w = Float(wet * 3), pre = Int(0.03 * sr)
        for i in 0..<out.count {
            let j = i - pre
            let x: Float = j >= 0 ? (input.l[j] + input.r[j]) * 0.015 : 0
            var yl: Float = 0, yr: Float = 0
            for k in 0..<8 { yl += cl[k].run(x, fb, dm); yr += cr[k].run(x, fb, dm) }
            for k in 0..<4 { yl = al[k].run(yl); yr = ar[k].run(yr) }
            out.l[i] += yl * w; out.r[i] += yr * w
        }
    }

    /// Tape wow: a slowly wavering delay, read around the loop so the seam stays clean.
    func wobble(_ m: StereoMix, depth: Double, cycles: Double) {
        let n = m.count, l = m.l, r = m.r
        for i in 0..<n {
            let d = (0.002 + depth * (0.5 + 0.5 * sin(2 * .pi * cycles * Double(i) / Double(n)))) * sr
            let pos = Double(i) - d
            let base = Int(pos.rounded(.down)), frac = Float(pos - Double(base))
            let a = ((base % n) + n) % n, b = (a + 1) % n
            m.l[i] = l[a] * (1 - frac) + l[b] * frac
            m.r[i] = r[a] * (1 - frac) + r[b] * frac
        }
    }

    /// Fewer samples and fewer bits: lo-fi.
    func crush(_ m: StereoMix, hold: Int, bits: Double) {
        var peak: Float = 1e-6
        for i in 0..<m.count { peak = max(peak, abs(m.l[i]), abs(m.r[i])) }
        let step = peak / Float(pow(2, bits - 1))
        var hl: Float = 0, hr: Float = 0
        for i in 0..<m.count {
            if i % hold == 0 { hl = (m.l[i] / step).rounded() * step; hr = (m.r[i] / step).rounded() * step }
            m.l[i] = hl; m.r[i] = hr
        }
    }
}

private struct Comb {
    var buf: [Float], i = 0, store: Float = 0
    init(_ n: Int) { buf = [Float](repeating: 0, count: n) }
    @inline(__always) mutating func run(_ x: Float, _ fb: Float, _ damp: Float) -> Float {
        let y = buf[i]; store = y * (1 - damp) + store * damp; buf[i] = x + store * fb
        i += 1; if i == buf.count { i = 0 }
        return y
    }
}

private struct AllPass {
    var buf: [Float], i = 0
    init(_ n: Int) { buf = [Float](repeating: 0, count: n) }
    @inline(__always) mutating func run(_ x: Float) -> Float {
        let b = buf[i]; buf[i] = x + b * 0.5
        i += 1; if i == buf.count { i = 0 }
        return b - x
    }
}
