import SpriteKit
import UIKit

/// Phase 0 goal: prove the SwiftUI + SpriteKit + XcodeGen + CI pipeline works end to end.
/// The isometric math here mirrors the proven web prototype (app.js: isoX/isoY/project)
/// so later phases can extend this file directly instead of re-deriving the projection.
final class GameScene: SKScene {

    private let tileWidth: CGFloat = 64
    private let tileHeight: CGFloat = 32
    private let cols = 6
    private let rows = 4

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addChild(makeSkyBackground())
        addChild(makeIsoGrid())
        addChild(makeTitleLabel())
    }

    // MARK: - Isometric projection helpers

    private func isoX(_ tx: Int, _ ty: Int) -> CGFloat {
        CGFloat(tx - ty) * (tileWidth / 2)
    }

    private func isoY(_ tx: Int, _ ty: Int) -> CGFloat {
        CGFloat(tx + ty) * (tileHeight / 2)
    }

    // MARK: - Scene contents

    private func makeSkyBackground() -> SKSpriteNode {
        let size = CGSize(width: 1200, height: 1200)
        let texture = SKTexture(image: Self.gradientImage(
            size: size,
            top: UIColor(red: 0.56, green: 0.79, blue: 0.94, alpha: 1),
            bottom: UIColor(red: 0.87, green: 0.95, blue: 1.0, alpha: 1)
        ))
        let node = SKSpriteNode(texture: texture, size: size)
        node.zPosition = -100
        return node
    }

    private func makeIsoGrid() -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: -isoX(cols - 1, 0) / 2 + isoX(0, rows - 1) / 2, y: 40)

        for ty in 0..<rows {
            for tx in 0..<cols {
                let diamond = diamondPath()
                let shape = SKShapeNode(path: diamond)
                let isGrass = (tx + ty) % 2 == 0
                shape.fillColor = isGrass
                    ? UIColor(red: 0.49, green: 0.77, blue: 0.42, alpha: 1)
                    : UIColor(red: 0.55, green: 0.83, blue: 0.48, alpha: 1)
                shape.strokeColor = UIColor.black.withAlphaComponent(0.12)
                shape.lineWidth = 1
                shape.position = CGPoint(x: isoX(tx, ty), y: -isoY(tx, ty))
                shape.zPosition = CGFloat(tx + ty)
                container.addChild(shape)
            }
        }
        return container
    }

    private func diamondPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: tileHeight / 2))
        path.addLine(to: CGPoint(x: tileWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -tileHeight / 2))
        path.addLine(to: CGPoint(x: -tileWidth / 2, y: 0))
        path.closeSubpath()
        return path
    }

    private func makeTitleLabel() -> SKLabelNode {
        let label = SKLabelNode(text: "SimLife — pipeline dziala")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 22
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 160)
        label.zPosition = 100
        return label
    }

    // MARK: - Utility

    private static func gradientImage(size: CGSize, top: UIColor, bottom: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: 0),
                end: CGPoint(x: size.width / 2, y: size.height),
                options: []
            )
        }
    }
}
