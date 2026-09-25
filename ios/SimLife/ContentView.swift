import SwiftUI
import SpriteKit

struct ContentView: View {
    var scene: SKScene {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .frame(width: proxy.size.width, height: proxy.size.height)
                .ignoresSafeArea()
        }
    }
}

#Preview {
    ContentView()
}
