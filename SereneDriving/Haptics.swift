import CoreHaptics
import UIKit

/// Touch you can feel: a continuous texture under the wheels whose grain depends
/// on the surface and the speed, plus small taps when you bump something and a
/// soft swell when a new world arrives.
///
/// Everything degrades quietly — on a device without Core Haptics (or in the
/// simulator) the calls simply do nothing.
final class Haptics {

    private var engine: CHHapticEngine?
    private var texture: CHHapticAdvancedPatternPlayer?
    private var running = false

    private var lastIntensity: Float = -1
    private var lastSharpness: Float = -1

    var isEnabled: Bool = true {
        didSet { if !isEnabled { stopTexture() } }
    }

    func start() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, engine == nil else { return }
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak self] in
                self?.running = false
                try? self?.engine?.start()
                self?.startTexture()
            }
            e.stoppedHandler = { [weak self] _ in self?.running = false }
            try e.start()
            engine = e
            startTexture()
        } catch {
            engine = nil
        }
    }

    func stop() {
        stopTexture()
        engine?.stop()
        running = false
    }

    // MARK: - Continuous surface texture

    private func startTexture() {
        guard let engine, texture == nil else { return }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticContinuous,
                                  parameters: [intensity, sharpness],
                                  relativeTime: 0,
                                  duration: 60 * 60 * 8)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            try player.start(atTime: CHHapticTimeImmediate)
            texture = player
            running = true
        } catch {
            texture = nil
        }
    }

    private func stopTexture() {
        try? texture?.stop(atTime: CHHapticTimeImmediate)
        texture = nil
        running = false
    }

    /// - Parameters:
    ///   - intensity: 0...1, how much the surface is buzzing through the chassis
    ///   - sharpness: 0...1, gritty (high) versus soft (low)
    func setTexture(intensity: Float, sharpness: Float) {
        guard isEnabled, running, let texture else { return }
        let i = min(max(intensity, 0), 1)
        let s = min(max(sharpness, 0), 1)
        // Only talk to the engine when something actually changed.
        guard abs(i - lastIntensity) > 0.02 || abs(s - lastSharpness) > 0.03 else { return }
        lastIntensity = i
        lastSharpness = s

        let params = [
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: i, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: s, relativeTime: 0),
        ]
        try? texture.sendParameters(params, atTime: CHHapticTimeImmediate)
    }

    // MARK: - One-offs

    /// A bump against scenery. `strength` is 0...1.
    func impact(_ strength: Float) {
        guard isEnabled, let engine else { return }
        let s = min(max(strength, 0.05), 1)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: s),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35 + s * 0.4),
        ], relativeTime: 0)
        try? engine.makePlayer(with: try! CHHapticPattern(events: [event], parameters: []))
            .start(atTime: CHHapticTimeImmediate)
    }

    /// A slow swell for arriving somewhere new.
    func arrival() {
        guard isEnabled, let engine else { return }
        let swell = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.42),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12),
        ], relativeTime: 0, duration: 1.1)
        let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0),
            .init(relativeTime: 0.45, value: 1),
            .init(relativeTime: 1.1, value: 0),
        ], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [swell], parameterCurves: [curve]),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    /// A brighter double tap for reaching a landmark.
    func discovery() {
        guard isEnabled, let engine else { return }
        let events = [
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ], relativeTime: 0),
            CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.32),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
            ], relativeTime: 0.12, duration: 0.8),
        ]
        guard let pattern = try? CHHapticPattern(events: events, parameters: []),
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

/// How the ground feels under each kind of world.
extension Biome {
    /// (grain, sharpness) — grain scales the texture with speed.
    var surfaceFeel: (grain: Float, sharpness: Float) {
        switch kind {
        case .forest: return (0.55, 0.40)
        case .desert: return (0.72, 0.22)
        case .beach:  return (0.62, 0.20)
        case .ocean:  return (0.30, 0.08)
        case .snow:   return (0.38, 0.12)
        case .moon:   return (0.48, 0.30)
        case .space:  return (0.10, 0.05)
        case .autumn: return (0.52, 0.36)
        case .canyon: return (0.68, 0.45)
        case .saltflats: return (0.30, 0.55)
        case .volcano: return (0.80, 0.52)
        case .alien:  return (0.44, 0.24)
        }
    }
}
