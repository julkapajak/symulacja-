import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var hud = GameHUDModel()

    // A stored property (created exactly once), not computed — SwiftUI re-evaluates `body`
    // often once the HUD starts publishing every frame, and a computed `scene` would have
    // rebuilt (and re-animated-in) a brand new GameScene on every single one of those redraws.
    @State private var scene: GameScene = {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        return scene
    }()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                HUDView(model: hud)
            }
        }
        .onAppear { scene.hud = hud }
    }
}

#Preview {
    ContentView()
}
