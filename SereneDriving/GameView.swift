import SwiftUI
import SceneKit

final class SceneHost: ObservableObject {
    let world = WorldScene()
}

struct SceneKitView: UIViewRepresentable {
    let world: WorldScene

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        world.build()
        view.scene = world.scene
        view.delegate = world
        view.isPlaying = true
        view.rendersContinuously = true
        view.antialiasingMode = .multisampling2X
        view.preferredFramesPerSecond = 60
        view.isUserInteractionEnabled = false
        view.backgroundColor = .black
        view.autoenablesDefaultLighting = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

struct GameView: View {
    @StateObject private var host = SceneHost()
    @StateObject private var model = GameModel()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("gameMode") private var storedMode: String = GameMode.serene.rawValue

    @State private var stickOrigin: CGPoint?
    @State private var stickPoint: CGPoint = .zero
    @State private var modeBadge: Double = 0

    private var mode: GameMode { GameMode(rawValue: storedMode) ?? .serene }

    private let stickRadius: CGFloat = 78

    var body: some View {
        ZStack {
            SceneKitView(world: host.world)
                .ignoresSafeArea()

            // Soft edge darkening — keeps the eye in the middle of the frame.
            RadialGradient(colors: [.clear, .black.opacity(0.28)],
                           center: .center, startRadius: 220, endRadius: 640)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            controlLayer

            worldTitle
                .allowsHitTesting(false)

            VStack(spacing: 6) {
                Text(model.landmarkName)
                    .font(.system(size: 24, weight: .thin, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(.white)
                Rectangle()
                    .fill(.white.opacity(0.45))
                    .frame(width: 46, height: 1)
            }
            .shadow(color: .black.opacity(0.5), radius: 14, y: 2)
            .opacity(model.landmarkOpacity)
            .offset(y: -120)
            .allowsHitTesting(false)

            Text(mode.title.uppercased())
                .font(.system(size: 12, weight: .light, design: .rounded))
                .tracking(5)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                .opacity(modeBadge)
                .offset(y: 92)
                .allowsHitTesting(false)

            chrome

            model.veilColor
                .opacity(model.veilOpacity)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            host.world.model = model
            host.world.mode = mode
            model.dismissHintSoon()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                host.world.audio.isEnabled = model.soundOn
                host.world.haptics.isEnabled = true
                host.world.haptics.start()
            } else {
                host.world.audio.isEnabled = false
                host.world.haptics.isEnabled = false
            }
        }
    }

    // MARK: - Driving control

    private var controlLayer: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if stickOrigin == nil {
                                stickOrigin = value.startLocation
                                withAnimation(.easeOut(duration: 0.8)) { model.showControlsHint = false }
                            }
                            stickPoint = value.location
                            apply(from: stickOrigin ?? value.startLocation, to: value.location)
                        }
                        .onEnded { _ in
                            stickOrigin = nil
                            host.world.controls.steer = 0
                            host.world.controls.throttle = 0
                        }
                )
                // Double tap near the top of the screen moves on to the next
                // place. Simultaneous and location-aware, so the whole screen
                // stays available for driving.
                .simultaneousGesture(
                    SpatialTapGesture(count: 2)
                        .onEnded { value in
                            guard value.location.y < geo.size.height * 0.22 else { return }
                            host.world.skipToNextWorld()
                        }
                )
                .overlay(alignment: .topLeading) {
                    if let origin = stickOrigin {
                        stickView(origin: origin)
                    }
                }
                .overlay(alignment: .bottom) {
                    if model.showControlsHint {
                        Text("drag anywhere to drive")
                            .font(.system(size: 15, weight: .light, design: .rounded))
                            .tracking(2.4)
                            .foregroundStyle(.white.opacity(0.7))
                            .shadow(color: .black.opacity(0.35), radius: 8)
                            .padding(.bottom, 46)
                            .transition(.opacity)
                    }
                }
                .ignoresSafeArea()
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func stickView(origin: CGPoint) -> some View {
        let delta = clampedDelta(from: origin, to: stickPoint)
        return ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1.4)
                .frame(width: stickRadius * 2, height: stickRadius * 2)
            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 54, height: 54)
                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .offset(x: delta.width, y: delta.height)
        }
        .position(x: origin.x, y: origin.y)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func clampedDelta(from origin: CGPoint, to point: CGPoint) -> CGSize {
        var dx = point.x - origin.x
        var dy = point.y - origin.y
        let len = sqrt(dx * dx + dy * dy)
        if len > stickRadius {
            dx = dx / len * stickRadius
            dy = dy / len * stickRadius
        }
        return CGSize(width: dx, height: dy)
    }

    private func apply(from origin: CGPoint, to point: CGPoint) {
        let d = clampedDelta(from: origin, to: point)
        let sx = Float(d.width / stickRadius)
        let sy = Float(-d.height / stickRadius)
        host.world.controls.steer = curve(sx)
        host.world.controls.throttle = curve(sy)
    }

    /// Gentle response near the centre, full authority at the edge.
    private func curve(_ v: Float) -> Float {
        let dead: Float = 0.08
        let a = abs(v)
        guard a > dead else { return 0 }
        let n = (a - dead) / (1 - dead)
        return (v < 0 ? -1 : 1) * n * n * (3 - 2 * n)
    }

    // MARK: - Overlays

    private var worldTitle: some View {
        VStack(spacing: 10) {
            Text(model.worldName)
                .font(.system(size: 34, weight: .thin, design: .rounded))
                .tracking(5)
                .foregroundStyle(.white)
            Text(model.worldSubtitle)
                .font(.system(size: 14, weight: .light, design: .rounded))
                .tracking(3.4)
                .foregroundStyle(.white.opacity(0.72))
        }
        .shadow(color: .black.opacity(0.45), radius: 16, y: 2)
        .opacity(model.titleOpacity)
        .offset(y: -40)
    }

    private var chrome: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    softButton(model.soundOn ? "speaker.wave.2" : "speaker.slash") {
                        model.soundOn.toggle()
                        host.world.audio.isEnabled = model.soundOn
                    }
                    softButton(mode.symbol) {
                        let next: GameMode = mode == .serene ? .speed : .serene
                        storedMode = next.rawValue
                        host.world.mode = next
                        withAnimation(.easeOut(duration: 0.5)) { modeBadge = 1 }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_600_000_000)
                            withAnimation(.easeInOut(duration: 1.0)) { modeBadge = 0 }
                        }
                    }
                    softButton("arrow.triangle.2.circlepath") {
                        host.world.skipToNextWorld()
                    }
                }
                .padding(.trailing, 22)
                .padding(.top, 14)
            }
            Spacer()
            HStack {
                Spacer()
                Text("\(Int(model.speedKmh))")
                    .font(.system(size: 26, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
                    + Text(" km/h")
                    .font(.system(size: 11, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.trailing, 28)
            .padding(.bottom, 18)
            .shadow(color: .black.opacity(0.3), radius: 6)
        }
        .allowsHitTesting(true)
    }

    private func softButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .light))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial.opacity(0.55), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }
}
