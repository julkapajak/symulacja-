import SwiftUI
import SceneKit

/// A thin UIViewRepresentable around SCNView — SwiftUI's own SceneView doesn't expose the
/// underlying UIView, and gesture recognizers (orbit/zoom/tap) need to be attached directly to it,
/// the same way the SpriteKit version attached them to the SKView in GameScene.didMove(to:).
struct SceneContainerView: UIViewRepresentable {
    let coordinator: GameCoordinator

    func makeUIView(context: Context) -> SCNView {
        coordinator.start()

        let view = SCNView()
        view.scene = coordinator.scene
        view.pointOfView = coordinator.cameraNode
        view.delegate = coordinator
        view.backgroundColor = .black
        view.isPlaying = true
        view.rendersContinuously = true

        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(GameCoordinator.handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(GameCoordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: coordinator, action: #selector(GameCoordinator.handlePinch(_:)))
        pan.delegate = coordinator
        pinch.delegate = coordinator
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)

        coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
