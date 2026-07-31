import SwiftUI

enum GameMode: String {
    case serene, speed

    var title: String { self == .serene ? "Serene" : "Speed" }
    var symbol: String { self == .serene ? "leaf" : "bolt.fill" }
}

@MainActor
final class GameModel: ObservableObject {
    @Published var worldName: String = ""
    @Published var worldSubtitle: String = ""
    @Published var titleOpacity: Double = 0
    @Published var veilOpacity: Double = 1
    @Published var veilColor: Color = Color(rgb(0xCFE4E4))
    @Published var speedKmh: Float = 0
    @Published var showControlsHint: Bool = true
    @Published var soundOn: Bool = true

    @Published var landmarkName: String = ""
    @Published var landmarkOpacity: Double = 0

    private var hintTask: Task<Void, Never>?

    func announce(name: String, subtitle: String, veil: UIColor) {
        worldName = name
        worldSubtitle = subtitle
        veilColor = Color(veil)

        withAnimation(.easeOut(duration: 1.2)) { titleOpacity = 1 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_600_000_000)
            withAnimation(.easeInOut(duration: 1.8)) { titleOpacity = 0 }
        }
    }

    /// You drove all the way out to it. It gets to say its name.
    func reveal(landmark: String) {
        landmarkName = landmark
        withAnimation(.easeOut(duration: 1.4)) { landmarkOpacity = 1 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_200_000_000)
            withAnimation(.easeInOut(duration: 2.0)) { landmarkOpacity = 0 }
        }
    }

    func dismissHintSoon() {
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 1.0)) { showControlsHint = false }
        }
    }
}
