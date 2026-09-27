import SceneKit
import UIKit

/// Builds a detailed, multi-part 3D model for each furniture type — replaces the earlier single
/// colored box with shapes that actually read as the real object (a bed with a mattress and
/// headboard, a fridge with a door and handle, a car with a cabin, windshield and wheels, ...),
/// still built entirely from SceneKit primitives (no imported 3D assets). Each builder returns a
/// node rooted at the tile's floor position (origin = base center, y = 0 upward).
enum FurnitureModelBuilder {
    static func build(type: String, color: UIColor) -> SCNNode {
        switch type {
        case "fridge": return fridge(color: color)
        case "sink": return sink(color: color)
        case "toilet": return toilet(color: color)
        case "shower": return shower(color: color)
        case "bed": return bed(color: color)
        case "bookshelf": return bookshelf(color: color)
        case "sofa": return sofa(color: color)
        case "tv": return tv(color: color)
        case "computer": return computerDesk(color: color)
        case "car": return car(color: color)
        case "tree": return tree(color: color)
        default: return SCNNode(childNode: box(0.6, 0.4, 0.6, color: color))
        }
    }

    /// The approximate top of each model, in meters — used by GameCoordinator to float the
    /// catalog icon above it. Kept here, next to the shapes it describes, rather than guessed
    /// generically from a single "height" number the way the old uniform box did.
    static func iconHeight(for type: String) -> Float {
        switch type {
        case "fridge": return 1.15
        case "sink": return 0.95
        case "toilet": return 1.0
        case "shower": return 1.15
        case "bed": return 0.7
        case "bookshelf": return 1.3
        case "sofa": return 0.75
        case "tv": return 1.05
        case "computer": return 1.0
        case "car": return 0.95
        case "tree": return 1.3
        default: return 0.6
        }
    }

    // MARK: - Shared helpers

    private static func material(color: UIColor, roughness: CGFloat, metalness: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = roughness
        material.metalness.contents = metalness
        return material
    }

    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, color: UIColor, roughness: CGFloat = 0.7, metalness: CGFloat = 0, chamfer: CGFloat = 0.01) -> SCNNode {
        let geometry = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
        geometry.materials = [material(color: color, roughness: roughness, metalness: metalness)]
        return SCNNode(geometry: geometry)
    }

    private static func cylinder(_ r: CGFloat, _ h: CGFloat, color: UIColor, roughness: CGFloat = 0.7, metalness: CGFloat = 0) -> SCNNode {
        let geometry = SCNCylinder(radius: r, height: h)
        geometry.materials = [material(color: color, roughness: roughness, metalness: metalness)]
        return SCNNode(geometry: geometry)
    }

    private static func sphere(_ r: CGFloat, color: UIColor, roughness: CGFloat = 0.7, metalness: CGFloat = 0) -> SCNNode {
        let geometry = SCNSphere(radius: r)
        geometry.materials = [material(color: color, roughness: roughness, metalness: metalness)]
        return SCNNode(geometry: geometry)
    }

    private static func torus(ring: CGFloat, pipe: CGFloat, color: UIColor, roughness: CGFloat = 0.7, metalness: CGFloat = 0) -> SCNNode {
        let geometry = SCNTorus(ringRadius: ring, pipeRadius: pipe)
        geometry.materials = [material(color: color, roughness: roughness, metalness: metalness)]
        return SCNNode(geometry: geometry)
    }

    // MARK: - Furniture

    private static func fridge(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let body = box(0.55, 0.95, 0.5, color: color, roughness: 0.35, metalness: 0.2)
        body.position = SCNVector3(0, 0.475, 0)
        root.addChildNode(body)

        let door = box(0.5, 0.9, 0.04, color: color.shaded(0.94), roughness: 0.3, metalness: 0.25)
        door.position = SCNVector3(0, 0.475, 0.27)
        root.addChildNode(door)

        let seam = box(0.5, 0.015, 0.045, color: UIColor(white: 0.3, alpha: 1), roughness: 0.4, metalness: 0.3)
        seam.position = SCNVector3(0, 0.62, 0.27)
        root.addChildNode(seam)

        let handle = cylinder(0.015, 0.35, color: UIColor(white: 0.25, alpha: 1), roughness: 0.4, metalness: 0.6)
        handle.eulerAngles.x = .pi / 2
        handle.position = SCNVector3(0.18, 0.55, 0.3)
        root.addChildNode(handle)

        return root
    }

    private static func sink(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let cabinet = box(0.5, 0.6, 0.4, color: UIColor(hex: "#c9a06e"), roughness: 0.75)
        cabinet.position = SCNVector3(0, 0.3, 0)
        root.addChildNode(cabinet)

        let basin = box(0.46, 0.08, 0.36, color: color, roughness: 0.2, metalness: 0.1, chamfer: 0.04)
        basin.position = SCNVector3(0, 0.64, 0)
        root.addChildNode(basin)

        let faucet = cylinder(0.015, 0.22, color: UIColor(white: 0.7, alpha: 1), roughness: 0.2, metalness: 0.85)
        faucet.position = SCNVector3(0, 0.78, -0.14)
        root.addChildNode(faucet)

        return root
    }

    private static func toilet(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let bowl = cylinder(0.2, 0.38, color: color, roughness: 0.15)
        bowl.position = SCNVector3(0, 0.19, 0.05)
        root.addChildNode(bowl)

        let seat = torus(ring: 0.16, pipe: 0.03, color: color, roughness: 0.15)
        seat.position = SCNVector3(0, 0.39, 0.05)
        root.addChildNode(seat)

        let tank = box(0.34, 0.4, 0.16, color: color, roughness: 0.15)
        tank.position = SCNVector3(0, 0.55, -0.17)
        root.addChildNode(tank)

        return root
    }

    private static func shower(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let tray = box(0.66, 0.05, 0.66, color: UIColor(white: 0.85, alpha: 1), roughness: 0.3)
        tray.position = SCNVector3(0, 0.025, 0)
        root.addChildNode(tray)

        let glass = color.withAlphaComponent(0.35)
        let panelBack = box(0.66, 0.9, 0.02, color: glass, roughness: 0.05, metalness: 0.1)
        panelBack.position = SCNVector3(0, 0.5, -0.32)
        root.addChildNode(panelBack)
        let panelSide = box(0.02, 0.9, 0.66, color: glass, roughness: 0.05, metalness: 0.1)
        panelSide.position = SCNVector3(-0.32, 0.5, 0)
        root.addChildNode(panelSide)

        let head = sphere(0.05, color: UIColor(white: 0.7, alpha: 1), roughness: 0.2, metalness: 0.7)
        head.position = SCNVector3(0.2, 0.95, -0.2)
        root.addChildNode(head)

        return root
    }

    private static func bed(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let frame = box(0.85, 0.14, 0.9, color: UIColor(hex: "#6b4a2f"), roughness: 0.7)
        frame.position = SCNVector3(0, 0.07, 0)
        root.addChildNode(frame)

        let mattress = box(0.8, 0.16, 0.85, color: color, roughness: 0.9)
        mattress.position = SCNVector3(0, 0.22, 0)
        root.addChildNode(mattress)

        let headboard = box(0.85, 0.45, 0.06, color: UIColor(hex: "#6b4a2f"), roughness: 0.6)
        headboard.position = SCNVector3(0, 0.35, -0.42)
        root.addChildNode(headboard)

        let pillow = box(0.3, 0.08, 0.2, color: UIColor(white: 0.97, alpha: 1), roughness: 0.95, chamfer: 0.03)
        pillow.position = SCNVector3(0, 0.34, -0.28)
        root.addChildNode(pillow)

        return root
    }

    private static func bookshelf(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let frame = box(0.6, 1.1, 0.3, color: color, roughness: 0.65)
        frame.position = SCNVector3(0, 0.55, 0)
        root.addChildNode(frame)

        let bookColors = ["#c0392b", "#2980b9", "#27ae60", "#f39c12", "#8e44ad"]
        for shelfIndex in 0..<3 {
            let y = Float(0.28 + Double(shelfIndex) * 0.32)
            var x: Float = -0.22
            for i in 0..<5 {
                let book = box(0.06, 0.22, 0.18, color: UIColor(hex: bookColors[i % bookColors.count]), roughness: 0.85)
                book.position = SCNVector3(x, y, 0.02)
                root.addChildNode(book)
                x += 0.1
            }
        }

        return root
    }

    private static func sofa(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let seat = box(0.85, 0.28, 0.6, color: color, roughness: 0.9)
        seat.position = SCNVector3(0, 0.14, 0)
        root.addChildNode(seat)

        let back = box(0.85, 0.45, 0.16, color: color.shaded(0.9), roughness: 0.9)
        back.position = SCNVector3(0, 0.35, -0.22)
        root.addChildNode(back)

        for side: Float in [-1, 1] {
            let arm = box(0.14, 0.4, 0.6, color: color.shaded(0.85), roughness: 0.9)
            arm.position = SCNVector3(side * 0.42, 0.28, 0)
            root.addChildNode(arm)
        }

        return root
    }

    private static func tv(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let stand = box(0.7, 0.35, 0.28, color: UIColor(hex: "#2b2b2b"), roughness: 0.5)
        stand.position = SCNVector3(0, 0.175, 0)
        root.addChildNode(stand)

        let bezel = box(0.9, 0.55, 0.02, color: UIColor(white: 0.05, alpha: 1), roughness: 0.4)
        bezel.position = SCNVector3(0, 0.6, -0.1)
        root.addChildNode(bezel)

        let screen = box(0.85, 0.5, 0.02, color: color, roughness: 0.15, metalness: 0.3)
        screen.position = SCNVector3(0, 0.6, -0.08)
        root.addChildNode(screen)

        return root
    }

    private static func computerDesk(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let desktop = box(0.8, 0.05, 0.5, color: UIColor(hex: "#a9744f"), roughness: 0.6)
        desktop.position = SCNVector3(0, 0.5, 0)
        root.addChildNode(desktop)

        for (sx, sz): (Float, Float) in [(-0.35, -0.2), (0.35, -0.2), (-0.35, 0.2), (0.35, 0.2)] {
            let leg = box(0.04, 0.5, 0.04, color: UIColor(hex: "#5a3d28"), roughness: 0.6)
            leg.position = SCNVector3(sx, 0.25, sz)
            root.addChildNode(leg)
        }

        let monitorStand = box(0.06, 0.1, 0.06, color: UIColor(white: 0.2, alpha: 1), roughness: 0.5)
        monitorStand.position = SCNVector3(0, 0.55, -0.12)
        root.addChildNode(monitorStand)

        let monitor = box(0.4, 0.28, 0.03, color: color, roughness: 0.2, metalness: 0.3)
        monitor.position = SCNVector3(0, 0.72, -0.12)
        root.addChildNode(monitor)

        let keyboard = box(0.28, 0.02, 0.1, color: UIColor(white: 0.85, alpha: 1), roughness: 0.6)
        keyboard.position = SCNVector3(0, 0.53, 0.1)
        root.addChildNode(keyboard)

        return root
    }

    private static func car(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let body = box(0.9, 0.32, 1.8, color: color, roughness: 0.25, metalness: 0.4, chamfer: 0.08)
        body.position = SCNVector3(0, 0.32, 0)
        root.addChildNode(body)

        let cabin = box(0.8, 0.28, 0.9, color: color.shaded(0.92), roughness: 0.2, metalness: 0.3, chamfer: 0.06)
        cabin.position = SCNVector3(0, 0.6, -0.1)
        root.addChildNode(cabin)

        let windshield = box(0.76, 0.2, 0.03, color: UIColor(white: 0.75, alpha: 0.55), roughness: 0.05, metalness: 0.1)
        windshield.position = SCNVector3(0, 0.62, 0.32)
        root.addChildNode(windshield)

        for (sx, sz): (Float, Float) in [(-0.42, -0.6), (0.42, -0.6), (-0.42, 0.6), (0.42, 0.6)] {
            let wheel = cylinder(0.16, 0.14, color: UIColor(white: 0.08, alpha: 1), roughness: 0.7)
            wheel.eulerAngles.z = .pi / 2
            wheel.position = SCNVector3(sx, 0.16, sz)
            root.addChildNode(wheel)
        }

        return root
    }

    private static func tree(color: UIColor) -> SCNNode {
        let root = SCNNode()

        let trunk = cylinder(0.08, 0.5, color: UIColor(hex: "#6b4a2f"), roughness: 0.9)
        trunk.position = SCNVector3(0, 0.25, 0)
        root.addChildNode(trunk)

        let foliage1 = sphere(0.32, color: color, roughness: 0.95)
        foliage1.position = SCNVector3(0, 0.75, 0)
        root.addChildNode(foliage1)
        let foliage2 = sphere(0.24, color: color.shaded(1.1), roughness: 0.95)
        foliage2.position = SCNVector3(0.15, 0.95, 0.1)
        root.addChildNode(foliage2)
        let foliage3 = sphere(0.22, color: color.shaded(0.9), roughness: 0.95)
        foliage3.position = SCNVector3(-0.15, 0.9, -0.1)
        root.addChildNode(foliage3)

        return root
    }
}

private extension SCNNode {
    convenience init(childNode: SCNNode) {
        self.init()
        addChildNode(childNode)
    }
}
