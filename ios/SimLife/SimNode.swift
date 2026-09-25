import SpriteKit

/// A Sim that can walk a queued path of grid tiles. Its visual children are built once, relative
/// to its own local origin (0,0 in scene space); `updateScreenPosition()` then just moves the
/// whole node to match its current (possibly fractional, mid-step) grid position each frame —
/// mirrors app.js's moveSimAlongPath, but SpriteKit repositions the node instead of redrawing it.
final class SimNode: SKNode {
    var gridX: CGFloat
    var gridY: CGFloat
    var path: [(x: Int, y: Int)] = []
    // Named walkSpeed, not speed: SKNode already declares a `speed` property
    // (it scales the playback rate of actions run on this node).
    let walkSpeed: CGFloat = 4.2 // tiles per second, matches app.js sim.speed

    init(startX: Int, startY: Int, color: SKColor, name: String) {
        gridX = CGFloat(startX)
        gridY = CGFloat(startY)
        super.init()
        buildVisuals(color: color, name: name)
        updateScreenPosition()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildVisuals(color: SKColor, name: String) {
        let shadow = SKShapeNode(ellipseOf: CGSize(width: Iso.tileWidth * 0.5, height: Iso.tileHeight * 0.45))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        addChild(shadow)

        let bodyHeight: CGFloat = 46
        let body = SKShapeNode(rectOf: CGSize(width: 16, height: bodyHeight), cornerRadius: 7)
        body.fillColor = color
        body.strokeColor = SKColor.black.withAlphaComponent(0.25)
        body.position = CGPoint(x: 0, y: bodyHeight / 2 + 4)
        addChild(body)

        let head = SKShapeNode(circleOfRadius: 9)
        head.fillColor = SKColor(hex: "#f2c9a0")
        head.strokeColor = SKColor.black.withAlphaComponent(0.25)
        head.position = CGPoint(x: 0, y: bodyHeight + 13)
        addChild(head)

        let label = SKLabelNode(text: name)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 12
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: bodyHeight + 34)
        addChild(label)
    }

    func updateScreenPosition() {
        position = Iso.toScene(Iso.project(gridX, gridY))
        zPosition = 2000 + gridX + gridY + 0.5
    }

    /// Advances along the queued path by `dt` seconds, matching app.js's step-toward-target logic.
    func advance(dt: CGFloat) {
        guard let target = path.first else { return }
        let dx = CGFloat(target.x) - gridX
        let dy = CGFloat(target.y) - gridY
        let dist = (dx * dx + dy * dy).squareRoot()
        if dist == 0 {
            path.removeFirst()
            return
        }
        let step = walkSpeed * dt
        if step >= dist {
            gridX = CGFloat(target.x)
            gridY = CGFloat(target.y)
            path.removeFirst()
        } else {
            gridX += (dx / dist) * step
            gridY += (dy / dist) * step
        }
        updateScreenPosition()
    }
}
