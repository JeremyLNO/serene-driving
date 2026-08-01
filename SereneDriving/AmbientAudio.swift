import AVFoundation
import Foundation

/// Everything you hear is synthesised on the fly: a slow chord pad, a breath of
/// wind that follows your speed, and a soft engine hum. No loops, no repeats.
final class AmbientAudio {

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var running = false

    // Values read by the render thread.
    private var padPhase = [Double](repeating: 0, count: 5)
    private var padFreq: [Double] = [110, 164.81, 220, 277.18, 329.63]
    private var padTarget: [Double] = [110, 164.81, 220, 277.18, 329.63]
    private var enginePhase: Double = 0
    private var windState: Double = 0
    private var noiseSeed: UInt32 = 22222
    private var lfo: Double = 0

    private var speed = Float(0)
    private var drift = Float(0)
    private var speedSmoothed = Double(0)
    private var driftSmoothed = Double(0)
    private var shimmerPhase = [Double](repeating: 0, count: 3)
    private var slideState = Double(0)
    private var chimeEnv = Double(0)
    private var chimePhase = [Double](repeating: 0, count: 3)
    private var chimeRoot = Double(392)
    private var sparkleEnv = Double(0)
    private var sparklePhase = [Double](repeating: 0, count: 2)
    private var sparkleRoot = Double(1568)
    private var masterTarget = Double(0)
    private var master = Double(0)
    private var engineTimbre = Double(0)     // 0 = airy, 1 = motor
    private var modeDrive = Double(1)        // Speed mode leans on the engine

    var isEnabled: Bool = true {
        didSet { masterTarget = isEnabled ? 1 : 0 }
    }

    func start() {
        guard !running else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio is a nicety; the drive continues without it.
        }

        let format = engine.outputNode.inputFormat(forBus: 0)
        let sampleRate = format.sampleRate > 0 ? format.sampleRate : 44100

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            self.render(frames: Int(frameCount), sampleRate: sampleRate, into: abl)
            return noErr
        }

        let outFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: outFormat)
        engine.mainMixerNode.outputVolume = 0.55
        source = node

        do {
            try engine.start()
            running = true
            masterTarget = isEnabled ? 1 : 0
        } catch {
            running = false
        }
    }

    func stop() {
        engine.stop()
        running = false
    }

    // MARK: - Control

    func setSpeed(_ normalized: Float) { speed = max(0, min(1, normalized)) }

    /// 0 = gripping, 1 = fully sideways. Opens a low, breathy layer under the pad.
    func setDrift(_ amount: Float) { drift = max(0, min(1, amount)) }

    /// A bright, short ping for picking a gem up — two octaves above the pad.
    func sparkle() {
        sparkleRoot = (padTarget.first ?? 98) * 16
        sparkleEnv = 1
    }

    /// A soft bell when a new world settles in, tuned to that world's key.
    func chime() {
        chimeRoot = padTarget.first.map { $0 * 4 } ?? 392
        chimeEnv = 1
    }

    func setMode(_ mode: GameMode) { modeDrive = mode == .speed ? 2.1 : 1.0 }

    func setBiome(_ biome: Biome) {
        let root: Double
        var ratios: [Double] = [1.0, 1.5, 2.0, 2.5, 3.0]
        switch biome.kind {
        case .forest:  root = 98.0;  ratios = [1, 1.2, 1.5, 2.0, 3.0]
        case .desert:  root = 87.31; ratios = [1, 1.125, 1.5, 2.0, 2.25]
        case .beach:   root = 110.0; ratios = [1, 1.25, 1.5, 2.0, 2.5]
        case .ocean:   root = 82.41; ratios = [1, 1.2, 1.5, 1.8, 2.4]
        case .snow:    root = 130.81; ratios = [1, 1.2, 1.5, 2.0, 2.4]
        case .moon:    root = 65.41; ratios = [1, 1.5, 2.0, 3.0, 4.0]
        case .space:   root = 73.42; ratios = [1, 1.334, 1.5, 2.0, 2.667]
        case .autumn:  root = 92.50; ratios = [1, 1.2, 1.5, 1.8, 2.4]
        case .canyon:  root = 77.78; ratios = [1, 1.125, 1.5, 2.0, 2.5]
        case .saltflats: root = 116.54; ratios = [1, 1.5, 2.0, 3.0, 4.0]
        case .volcano: root = 61.74; ratios = [1, 1.2, 1.5, 1.6, 2.4]
        case .alien:   root = 103.83; ratios = [1, 1.414, 1.5, 2.0, 2.828]
        }
        padTarget = ratios.map { root * $0 }

        switch biome.vehicle {
        case .boat, .spaceship: engineTimbre = 0.15
        case .rover: engineTimbre = 0.55
        default: engineTimbre = 1.0
        }
    }

    // MARK: - Render

    private func render(frames: Int, sampleRate: Double, into abl: UnsafeMutableAudioBufferListPointer) {
        let dt = 1.0 / sampleRate

        for frame in 0..<frames {
            master += (masterTarget - master) * 0.00004
            speedSmoothed += (Double(speed) - speedSmoothed) * 0.00015

            // Slowly glide the pad to the new key when a world changes.
            for i in 0..<padFreq.count {
                padFreq[i] += (padTarget[i] - padFreq[i]) * 0.000012
            }

            driftSmoothed += (Double(drift) - driftSmoothed) * 0.0004
            lfo += dt * 0.055
            var pad = 0.0
            for i in 0..<padFreq.count {
                padPhase[i] += padFreq[i] * dt
                if padPhase[i] > 1 { padPhase[i] -= 1 }
                let swell = 0.6 + 0.4 * sin(lfo * (0.7 + Double(i) * 0.23) * 2 * .pi)
                let weight = [0.30, 0.22, 0.18, 0.13, 0.10][i]
                pad += sin(padPhase[i] * 2 * .pi) * weight * swell
            }
            pad *= 0.30

            // A high, airy voice that only opens up once you're really moving.
            var shimmer = 0.0
            let shimmerGain = speedSmoothed * speedSmoothed * 0.085
            if shimmerGain > 0.0005 {
                for i in 0..<shimmerPhase.count {
                    let f = padFreq[i] * 4 * (1 + Double(i) * 0.004)
                    shimmerPhase[i] += f * dt
                    if shimmerPhase[i] > 1 { shimmerPhase[i] -= 1 }
                    let sway = 0.55 + 0.45 * sin(lfo * (1.3 + Double(i) * 0.4) * 2 * .pi)
                    shimmer += sin(shimmerPhase[i] * 2 * .pi) * sway
                }
                shimmer *= shimmerGain / 3
            }

            // Sliding sideways adds a low breath that follows the slip angle.
            noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
            let driftNoise = Double(Int32(bitPattern: noiseSeed)) / Double(Int32.max)
            slideState += (driftNoise - slideState) * 0.06
            let slide = slideState * driftSmoothed * 0.10

            // Arrival bell.
            var bell = 0.0
            if chimeEnv > 0.0002 {
                chimeEnv *= 0.99997
                for i in 0..<chimePhase.count {
                    let f = chimeRoot * [1.0, 1.5, 2.005][i]
                    chimePhase[i] += f * dt
                    if chimePhase[i] > 1 { chimePhase[i] -= 1 }
                    bell += sin(chimePhase[i] * 2 * .pi) * [0.5, 0.3, 0.2][i]
                }
                bell *= chimeEnv * chimeEnv * 0.14
            } else {
                chimeEnv = 0
            }

            // Wind / rush of movement — filtered noise.
            noiseSeed = noiseSeed &* 1_664_525 &+ 1_013_904_223
            let white = Double(Int32(bitPattern: noiseSeed)) / Double(Int32.max)
            windState += (white - windState) * 0.02
            let wind = windState * (0.030 + speedSmoothed * 0.085)

            // Engine hum.
            let hz = 46.0 + speedSmoothed * 78.0 * modeDrive
            enginePhase += hz * dt
            if enginePhase > 1 { enginePhase -= 1 }
            let motor = (sin(enginePhase * 2 * .pi) * 0.7 + sin(enginePhase * 4 * .pi) * 0.3)
            let engineLevel = (0.012 + speedSmoothed * 0.075) * engineTimbre * modeDrive
            let hum = motor * engineLevel

            var ping = 0.0
            if sparkleEnv > 0.0002 {
                sparkleEnv *= 0.99988
                for i in 0..<sparklePhase.count {
                    let f = sparkleRoot * [1.0, 1.498][i]
                    sparklePhase[i] += f * dt
                    if sparklePhase[i] > 1 { sparklePhase[i] -= 1 }
                    ping += sin(sparklePhase[i] * 2 * .pi) * [0.6, 0.4][i]
                }
                ping *= sparkleEnv * sparkleEnv * 0.05
            } else {
                sparkleEnv = 0
            }

            let sample = Float((pad + shimmer + wind + slide + hum + bell + ping) * master * 0.9)
            let clipped = max(-0.98, min(0.98, sample))

            for buffer in abl {
                let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                ptr[frame] = clipped
            }
        }
    }
}
