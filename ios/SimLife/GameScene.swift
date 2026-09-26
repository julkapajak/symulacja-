import SpriteKit
import UIKit

/// Faza 1 przeniosła świat domu (podłogi, ściany, drzwi, okna, meble) z prototypu przeglądarkowego.
/// Faza 2 dodała interakcję: dotknięcie pustego pola prowadzi Sima tam po prawdziwej ścieżce
/// (BFS omijający ściany, patrz Pathfinding.swift), a przeciąganie/uszczypnięcie steruje kamerą
/// SpriteKit (SKCameraNode) — odpowiednik JS-owej warstwy zoom/pan (state.camera / getTransform).
/// Faza 3 dodała samą rozgrywkę: potrzeby opadające w czasie, dotknięcie mebla żeby z niego
/// skorzystać, umiejętności, karierę i HUD (SwiftUI, patrz GameHUDModel.swift/HUDView.swift) —
/// odpowiednik JS-owego tickMinutes/gameLoop. Faza 4 dodała zapis stanu gry (SaveData.swift).
/// Faza 5 dodaje tryb budowania: przycisk 🔨 w HUD-zie, kupowanie mebli z paska (BuildState.swift
/// zastępuje statyczną listę World.starterItems mutowalnym stanem) i sprzedawanie ich dotknięciem.
final class GameScene: SKScene, UIGestureRecognizerDelegate {

    private let worldContainer = SKNode()
    private let cameraNode = SKCameraNode()
    private var simNode: SimNode!
    private var buildState: BuildState!
    private var furnitureNodes: [String: SKNode] = [:]

    /// Set by ContentView right after creating the scene. update(_:) pushes simulation state
    /// into it every frame; nil only for the handful of frames before that assignment lands.
    var hud: GameHUDModel?

    private var lastUpdateTime: TimeInterval = 0
    private var worldHalfWidth: CGFloat = 400
    private var worldHalfHeight: CGFloat = 300
    private var minCameraScale: CGFloat = 1
    private var maxCameraScale: CGFloat = 4

    // Simulation clock — mirrors app.js's state.minutes/state.day and the BASE_MIN_MS cadence.
    private var money: Double = 500
    private var day = 1
    private var minutesOfDay: Double = 8 * 60
    private var accumMs: Double = 0
    private let baseMinMs: Double = 150

    // Autosave — mirrors app.js's 30s localStorage interval, plus a save whenever the app
    // backgrounds (see the NotificationCenter observers below) so a swipe-away never loses time.
    private var saveAccumSec: Double = 0
    private let saveIntervalSec: Double = 30

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(hex: "#05070f")
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addChild(makeSkyBackground())
        addChild(makeSun())

        let savedData = SaveStore.load()
        buildState = BuildState(items: savedData?.items ?? World.starterItems)

        buildWorld()
        recenterWorld()
        addChild(worldContainer)
        simNode.buildState = buildState

        if let savedData {
            money = savedData.money
            day = savedData.day
            minutesOfDay = savedData.minutesOfDay
            simNode.applySaveData(savedData.sim)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(persistState), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(persistState), name: UIApplication.didEnterBackgroundNotification, object: nil)

        addChild(cameraNode)
        camera = cameraNode
        recalculateCameraBounds()
        cameraNode.setScale(maxCameraScale)
        cameraNode.position = .zero

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pan.delegate = self
        pinch.delegate = self
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        recalculateCameraBounds()
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard lastUpdateTime > 0 else { return }
        let dt = min(currentTime - lastUpdateTime, 0.1)

        simNode.advance(dt: CGFloat(dt))

        let hour = Int(minutesOfDay / 60) % 24
        if let message = simNode.beginPendingActionIfArrived(hour: hour) {
            hud?.postToast(message)
        }

        accumMs += dt * 1000
        while accumMs >= baseMinMs {
            accumMs -= baseMinMs
            tickMinute()
        }

        saveAccumSec += dt
        if saveAccumSec >= saveIntervalSec {
            saveAccumSec = 0
            persistState()
        }

        guard let hud else { return }
        hud.money = money
        hud.day = day
        hud.timeLabel = formattedTime()
        hud.jobTitle = CareerCatalog.jobTitles[simNode.jobLevel]
        hud.needs = simNode.needs
    }

    /// One simulated minute of game time: need decay, action progress, warnings and autonomy —
    /// mirrors app.js's tickMinutes(1) body (minus aspirations/partner, which aren't ported yet).
    private func tickMinute() {
        minutesOfDay += 1
        while minutesOfDay >= 1440 {
            minutesOfDay -= 1440
            day += 1
        }

        simNode.applyNeedDecay(minutes: 1)
        if let result = simNode.progressAction(minutes: 1) {
            money += result.moneyDelta
            hud?.postToast(result.message)
        }
        for message in simNode.checkWarnings() {
            hud?.postToast(message)
        }
        if let message = simNode.tryAutonomy() {
            hud?.postToast(message)
        }
    }

    private func formattedTime() -> String {
        let h = Int(minutesOfDay / 60) % 24
        let m = Int(minutesOfDay) % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Save/load

    @objc private func persistState() {
        let data = GameSaveData(money: money, day: day, minutesOfDay: minutesOfDay, sim: simNode.saveData, items: buildState.items)
        SaveStore.save(data)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    // MARK: - Camera

    private func recalculateCameraBounds() {
        guard let view else { return }
        let vw = max(view.bounds.width, 1)
        let vh = max(view.bounds.height, 1)

        let isoMinX = Iso.project(0, World.rows - 1).x
        let isoMaxX = Iso.project(World.cols - 1, 0).x
        let isoMaxY = Iso.project(World.cols - 1, World.rows - 1).y
        let worldW = isoMaxX - isoMinX + Iso.tileWidth + 60
        let worldH = isoMaxY + World.wallHeight + 140

        worldHalfWidth = worldW / 2
        worldHalfHeight = worldH / 2

        let fitScale = max(worldW / vw, worldH / vh)
        maxCameraScale = fitScale
        minCameraScale = fitScale / 4.5

        cameraNode.xScale = min(maxCameraScale, max(minCameraScale, cameraNode.xScale))
        cameraNode.yScale = cameraNode.xScale
        clampCameraPosition()
    }

    private func clampCameraPosition() {
        let limX = worldHalfWidth * 1.15
        let limY = worldHalfHeight * 1.15
        cameraNode.position.x = min(limX, max(-limX, cameraNode.position.x))
        cameraNode.position.y = min(limY, max(-limY, cameraNode.position.y))
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        let translation = gesture.translation(in: view)
        cameraNode.position.x -= translation.x * cameraNode.xScale
        cameraNode.position.y += translation.y * cameraNode.yScale
        gesture.setTranslation(.zero, in: view)
        clampCameraPosition()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let view else { return }
        let location = gesture.location(in: view)
        let before = convertPoint(fromView: location)

        let newScale = min(maxCameraScale, max(minCameraScale, cameraNode.xScale / gesture.scale))
        cameraNode.setScale(newScale)

        let after = convertPoint(fromView: location)
        cameraNode.position.x += before.x - after.x
        cameraNode.position.y += before.y - after.y

        gesture.scale = 1
        clampCameraPosition()
    }

    // MARK: - Tap to move

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view else { return }
        let scenePoint = convertPoint(fromView: gesture.location(in: view))
        let localPoint = worldContainer.convert(scenePoint, from: self)
        let canvasPoint = CGPoint(x: localPoint.x, y: -localPoint.y)
        let (tx, ty) = Iso.tileForCanvasPoint(canvasPoint)
        guard tx >= 0, ty >= 0, tx < World.cols, ty < World.rows else { return }

        if hud?.buildModeOn == true {
            handleBuildTap(tx: tx, ty: ty)
            return
        }

        if let placed = buildState.item(at: tx, ty) {
            guard World.furnitureCatalog[placed.type]?.action != nil else { return }
            simNode.startAction(towardItemID: placed.id)
            return
        }

        let occupied = buildState.occupiedTiles()
        guard Pathfinding.isWalkable(tx, ty, occupied: occupied) else { return }
        let start = simNode.tile
        guard let path = Pathfinding.findPath(from: start, to: (tx, ty), occupied: occupied) else { return }
        simNode.cancelCurrentActivity()
        simNode.path = path
    }

    // MARK: - Build mode

    /// Tapping furniture while in build mode sells it for half price; tapping empty ground
    /// places whatever's selected in the HUD's shopping strip (see HUDView.buildStrip). Mirrors
    /// app.js's build mode (place/move/sell), minus dragging an existing piece to relocate it.
    private func handleBuildTap(tx: Int, ty: Int) {
        guard let hud else { return }

        if let existing = buildState.item(at: tx, ty) {
            guard existing.type != "car", let cat = World.furnitureCatalog[existing.type] else {
                hud.postToast("Tego nie można sprzedać.")
                return
            }
            let refund = cat.cost / 2
            buildState.remove(id: existing.id)
            removeFurnitureNode(id: existing.id)
            money += Double(refund)
            hud.postToast("Sprzedano: \(cat.label) (+\(refund) zł)")
            return
        }

        guard let type = hud.selectedItemType, let cat = World.furnitureCatalog[type] else {
            hud.postToast("Wybierz przedmiot do postawienia.")
            return
        }
        guard money >= Double(cat.cost) else {
            hud.postToast("Za mało pieniędzy.")
            return
        }
        guard let placed = buildState.place(type: type, x: tx, y: ty) else { return }
        money -= Double(cat.cost)
        addFurnitureNode(for: placed)
        hud.postToast("Postawiono: \(cat.label)")
    }

    private func addFurnitureNode(for item: PlacedItem) {
        guard let node = makeFurniture(item) else { return }
        furnitureNodes[item.id] = node
        worldContainer.addChild(node)
    }

    private func removeFurnitureNode(id: String) {
        furnitureNodes[id]?.removeFromParent()
        furnitureNodes.removeValue(forKey: id)
    }

    // MARK: - World assembly

    private func buildWorld() {
        for ty in 0..<World.rows {
            for tx in 0..<World.cols {
                guard let zone = World.zone(atTx: tx, ty: ty) else { continue }
                worldContainer.addChild(makeFloorTile(tx: tx, ty: ty, zone: zone))
            }
        }

        for wall in World.walls {
            let node: SKNode
            switch wall.kind {
            case .door: node = makeDoorFrame(tx: wall.tx, ty: wall.ty, edge: wall.edge)
            case .window: node = makeWallWindow(tx: wall.tx, ty: wall.ty, edge: wall.edge)
            case .solid: node = makeWallSolid(tx: wall.tx, ty: wall.ty, edge: wall.edge)
            }
            node.zPosition = 1000 + CGFloat(wall.tx + wall.ty)
            worldContainer.addChild(node)
        }

        for item in buildState.items {
            addFurnitureNode(for: item)
        }

        simNode = SimNode(startX: 3, startY: 3, color: SKColor(hex: "#ff6f59"), name: "Sim")
        worldContainer.addChild(simNode)
    }

    private func recenterWorld() {
        let center = Iso.project(CGFloat(World.cols - 1) / 2, CGFloat(World.rows - 1) / 2)
        let centerScene = Iso.toScene(center)
        worldContainer.position = CGPoint(x: -centerScene.x, y: -centerScene.y)
    }

    // MARK: - Floor

    private func makeFloorTile(tx: Int, ty: Int, zone: Zone) -> SKNode {
        let c = Iso.project(tx, ty)
        let n = CGPoint(x: c.x, y: c.y - Iso.tileHeight / 2)
        let e = CGPoint(x: c.x + Iso.tileWidth / 2, y: c.y)
        let s = CGPoint(x: c.x, y: c.y + Iso.tileHeight / 2)
        let w = CGPoint(x: c.x - Iso.tileWidth / 2, y: c.y)

        let checker = (tx + ty) % 2 == 0
        let baseColor: SKColor
        switch zone.floorType {
        case "tile":
            baseColor = SKColor(hex: zone.color).shaded(checker ? 1.0 : 0.93)
        case "grass":
            baseColor = SKColor(hex: "#7ec46a")
        default:
            baseColor = SKColor(hex: zone.color)
        }

        let container = SKNode()
        container.addChild(isoQuad(n, e, s, w, fill: baseColor, stroke: SKColor.black.withAlphaComponent(0.10)))

        switch zone.floorType {
        case "wood":
            let path = CGMutablePath()
            for i in 1...2 {
                let t = CGFloat(i) / 3
                path.move(to: Iso.toScene(lerpPt(w, n, t)))
                path.addLine(to: Iso.toScene(lerpPt(s, e, t)))
            }
            let planks = SKShapeNode(path: path)
            planks.strokeColor = SKColor.black.withAlphaComponent(0.10)
            container.addChild(planks)
        case "tile":
            let path = CGMutablePath()
            path.move(to: Iso.toScene(n)); path.addLine(to: Iso.toScene(s))
            path.move(to: Iso.toScene(w)); path.addLine(to: Iso.toScene(e))
            let grid = SKShapeNode(path: path)
            grid.strokeColor = SKColor.black.withAlphaComponent(0.12)
            container.addChild(grid)
        case "grass":
            var rng = SeededRNG(seed: UInt32(truncatingIfNeeded: tx * 131 + ty * 977 + 7))
            for _ in 0..<3 {
                let u = CGFloat(rng.nextUnit() * 2 - 1)
                let v = CGFloat(rng.nextUnit() * 2 - 1)
                if abs(u) + abs(v) > 0.75 { continue }
                let dot = SKShapeNode(circleOfRadius: 1.3)
                dot.position = Iso.toScene(CGPoint(
                    x: c.x + u * (Iso.tileWidth / 2) * 0.85,
                    y: c.y + v * (Iso.tileHeight / 2) * 0.85
                ))
                dot.fillColor = SKColor.black.withAlphaComponent(0.22)
                dot.strokeColor = .clear
                container.addChild(dot)
            }
        default:
            break
        }

        container.zPosition = CGFloat(tx + ty)
        return container
    }

    // MARK: - Walls

    private func wallCorners(tx: Int, ty: Int, edge: WallEdge) -> (b0: CGPoint, b1: CGPoint, t0: CGPoint, t1: CGPoint) {
        let c = Iso.project(tx, ty)
        let n = CGPoint(x: c.x, y: c.y - Iso.tileHeight / 2)
        let e = CGPoint(x: c.x + Iso.tileWidth / 2, y: c.y)
        let w = CGPoint(x: c.x - Iso.tileWidth / 2, y: c.y)
        let topY = c.y - World.wallHeight
        let nt = CGPoint(x: n.x, y: topY - Iso.tileHeight / 2)

        if edge == .north {
            let et = CGPoint(x: e.x, y: topY)
            return (n, e, nt, et)
        }
        let wt = CGPoint(x: w.x, y: topY)
        return (w, n, wt, nt)
    }

    private func makeWallSolid(tx: Int, ty: Int, edge: WallEdge) -> SKNode {
        let p = wallCorners(tx: tx, ty: ty, edge: edge)
        let base = edge == .north ? SKColor(hex: "#f1e8d9") : SKColor(hex: "#e2d8c4")
        let container = SKNode()

        container.addChild(isoQuad(p.b0, p.b1, p.t1, p.t0, fill: base, stroke: SKColor.black.withAlphaComponent(0.15)))

        let bb0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0, 0.05)
        let bb1 = facePoint(p.b0, p.b1, p.t0, p.t1, 1, 0.05)
        container.addChild(isoQuad(p.b0, p.b1, bb1, bb0, fill: SKColor.black.withAlphaComponent(0.12)))

        let tt0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0, 0.94)
        let tt1 = facePoint(p.b0, p.b1, p.t0, p.t1, 1, 0.94)
        container.addChild(isoQuad(tt0, tt1, p.t1, p.t0, fill: SKColor.white.withAlphaComponent(0.22)))

        return container
    }

    private func makeWallWindow(tx: Int, ty: Int, edge: WallEdge) -> SKNode {
        let container = makeWallSolid(tx: tx, ty: ty, edge: edge)
        let p = wallCorners(tx: tx, ty: ty, edge: edge)

        let c00 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.26, 0.32)
        let c10 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.74, 0.32)
        let c11 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.74, 0.78)
        let c01 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.26, 0.78)
        container.addChild(isoQuad(c00, c10, c11, c01, fill: SKColor(hex: "#dff1ff"), stroke: SKColor(hex: "#6b4f34"), lineWidth: 2))

        let path = CGMutablePath()
        let m0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.5, 0.32)
        let m1 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.5, 0.78)
        let m2 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.26, 0.55)
        let m3 = facePoint(p.b0, p.b1, p.t0, p.t1, 0.74, 0.55)
        path.move(to: Iso.toScene(m0)); path.addLine(to: Iso.toScene(m1))
        path.move(to: Iso.toScene(m2)); path.addLine(to: Iso.toScene(m3))
        let mullion = SKShapeNode(path: path)
        mullion.strokeColor = SKColor(hex: "#6b4f34")
        mullion.lineWidth = 1.5
        container.addChild(mullion)

        return container
    }

    private func makeDoorFrame(tx: Int, ty: Int, edge: WallEdge) -> SKNode {
        let p = wallCorners(tx: tx, ty: ty, edge: edge)
        let container = SKNode()
        let jamb: CGFloat = 0.09
        for (u0, u1) in [(CGFloat(0), jamb), (1 - jamb, CGFloat(1))] {
            let a = facePoint(p.b0, p.b1, p.t0, p.t1, u0, 0)
            let b = facePoint(p.b0, p.b1, p.t0, p.t1, u1, 0)
            let c = facePoint(p.b0, p.b1, p.t0, p.t1, u1, 0.92)
            let d = facePoint(p.b0, p.b1, p.t0, p.t1, u0, 0.92)
            container.addChild(isoQuad(a, b, c, d, fill: SKColor(hex: "#8a6b45"), stroke: SKColor.black.withAlphaComponent(0.25)))
        }
        let h0 = facePoint(p.b0, p.b1, p.t0, p.t1, 0, 0.92)
        let h1 = facePoint(p.b0, p.b1, p.t0, p.t1, 1, 0.92)
        container.addChild(isoQuad(h0, h1, p.t1, p.t0, fill: SKColor(hex: "#8a6b45"), stroke: SKColor.black.withAlphaComponent(0.25)))
        return container
    }

    // MARK: - Furniture

    private func makeFurniture(_ placement: PlacedItem) -> SKNode? {
        guard let cat = World.furnitureCatalog[placement.type] else { return nil }
        let c = Iso.project(placement.x, placement.y)
        let topY = c.y - cat.height
        let w = CGPoint(x: c.x - Iso.tileWidth / 2, y: c.y)
        let e = CGPoint(x: c.x + Iso.tileWidth / 2, y: c.y)
        let s = CGPoint(x: c.x, y: c.y + Iso.tileHeight / 2)
        let n = CGPoint(x: c.x, y: c.y - Iso.tileHeight / 2)
        let wt = CGPoint(x: w.x, y: topY)
        let et = CGPoint(x: e.x, y: topY)
        let st = CGPoint(x: s.x, y: topY + Iso.tileHeight / 2)
        let nt = CGPoint(x: n.x, y: topY - Iso.tileHeight / 2)

        let color = SKColor(hex: cat.color)
        let container = SKNode()
        container.addChild(isoQuad(w, s, st, wt, fill: color.shaded(0.68), stroke: SKColor.black.withAlphaComponent(0.25)))
        container.addChild(isoQuad(s, e, et, st, fill: color.shaded(0.48), stroke: SKColor.black.withAlphaComponent(0.25)))
        container.addChild(isoQuad(nt, et, st, wt, fill: color, stroke: SKColor.black.withAlphaComponent(0.3)))

        let icon = SKLabelNode(text: cat.icon)
        icon.fontSize = 20
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = Iso.toScene(CGPoint(x: c.x, y: topY - 1))
        container.addChild(icon)

        container.zPosition = 2000 + CGFloat(placement.x + placement.y)
        return container
    }

    // MARK: - Sky

    private func makeSkyBackground() -> SKSpriteNode {
        let size = CGSize(width: 1400, height: 1000)
        let texture = SKTexture(image: Self.gradientImage(
            size: size,
            top: UIColor(red: 0.56, green: 0.79, blue: 0.94, alpha: 1),
            bottom: UIColor(red: 0.87, green: 0.95, blue: 1.0, alpha: 1)
        ))
        let node = SKSpriteNode(texture: texture, size: size)
        node.zPosition = -100
        return node
    }

    private func makeSun() -> SKNode {
        let container = SKNode()
        container.zPosition = -50
        container.position = CGPoint(x: -300, y: 260)

        let glow = SKShapeNode(circleOfRadius: 34)
        glow.fillColor = UIColor(red: 1, green: 0.94, blue: 0.71, alpha: 0.35)
        glow.strokeColor = .clear
        container.addChild(glow)

        let disc = SKShapeNode(circleOfRadius: 12)
        disc.fillColor = UIColor(red: 1, green: 0.95, blue: 0.77, alpha: 1)
        disc.strokeColor = .clear
        container.addChild(disc)

        return container
    }

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
