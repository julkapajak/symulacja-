import SceneKit
import UIKit

/// The SceneKit equivalent of the old SpriteKit GameScene: owns the 3D world, the orbiting
/// camera, gesture handling, and the per-frame simulation tick. Everything about *what* the
/// game simulates (needs, actions, pathfinding, build mode, save/load) is unchanged from the
/// 2D version — only *how it's drawn and viewed* changed, from a fixed isometric SpriteKit scene
/// to a real 3D SceneKit scene with a free-orbiting camera (drag to orbit around the house,
/// pinch to zoom — full 360°, unlike the old fixed iso angle).
final class GameCoordinator: NSObject, SCNSceneRendererDelegate, UIGestureRecognizerDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let worldNode = SCNNode()
    private var simNode: SimNode!
    private var buildState: BuildState!
    private var furnitureNodes: [String: SCNNode] = [:]

    weak var view: SCNView?

    /// Set by ContentView right after creating the coordinator. renderer(_:updateAtTime:) pushes
    /// simulation state into it every frame; nil only for the handful of frames before that
    /// assignment lands.
    var hud: GameHUDModel?

    // Camera orbit state (spherical coordinates around the house's center). Pitch is a fixed
    // constant, not user-controllable — like the classic Sims camera, dragging only spins the
    // view around the house (yaw); the ground's tilt on screen never changes, only zoom and
    // which side you're looking from do.
    private var yaw: Float = .pi / 4
    private let pitch: Float = 0.62
    private var radius: Float = 16
    private let minRadius: Float = 5
    private let maxRadius: Float = 26

    private var lastUpdateTime: TimeInterval = 0

    // Simulation clock — mirrors app.js's state.minutes/state.day and the BASE_MIN_MS cadence.
    private var money: Double = 500
    private var day = 1
    private var minutesOfDay: Double = 8 * 60
    private var accumMs: Double = 0
    private let baseMinMs: Double = 150

    // Autosave — mirrors app.js's 30s localStorage interval, plus a save whenever the app
    // backgrounds, so a swipe-away never loses more than a few seconds of progress.
    private var saveAccumSec: Double = 0
    private let saveIntervalSec: Double = 30

    // Character creator choices, applied when building a brand new Sim (see buildWorld()).
    private var characterName = "Sim"
    private var characterColorHex = "#ff6f59"
    private var characterTrait: String?
    private var characterAspiration: String?

    private var hasStarted = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configureNewCharacter(name: String, colorHex: String, trait: String?, aspiration: String) {
        characterName = name.isEmpty ? "Sim" : name
        characterColorHex = colorHex
        characterTrait = trait
        characterAspiration = aspiration
    }

    // MARK: - Setup

    /// Called once, from SceneContainerView.makeUIView — deliberately *not* from init(). The
    /// character creator (ContentView) calls configureNewCharacter() only once the player
    /// finishes it, and SceneContainerView (hence this) isn't created until after that, so
    /// buildWorld() below always sees whatever the player actually chose.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        scene.background.contents = UIColor(hex: "#8ec9f0")
        setUpLighting()
        setUpCamera()

        let savedData = SaveStore.load()
        buildState = BuildState(items: savedData?.items ?? World.starterItems)

        buildWorld()
        scene.rootNode.addChildNode(worldNode)
        simNode.buildState = buildState

        if let savedData {
            money = savedData.money
            day = savedData.day
            minutesOfDay = savedData.minutesOfDay
            simNode.applySaveData(savedData.sim)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(persistState), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(persistState), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func setUpLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.color = UIColor(white: 0.55, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.color = UIColor(white: 1.0, alpha: 1)
        sun.light!.castsShadow = true
        sun.light!.shadowMode = .deferred
        sun.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sun)
    }

    private func setUpCamera() {
        let camera = SCNCamera()
        camera.zFar = 100
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        updateCameraTransform()
    }

    /// Positions the camera on a sphere around the house and points it at the house's center —
    /// built by hand (rather than SCNNode.look(at:)) so the "up" direction is always derived
    /// from world-up via cross products, guaranteeing a level, roll-free horizon at every yaw.
    private func updateCameraTransform() {
        let x = radius * cos(pitch) * sin(yaw)
        let z = radius * cos(pitch) * cos(yaw)
        let y = radius * sin(pitch)
        let position = SCNVector3(x, y, z)

        let target = SCNVector3(0, 0.8, 0)
        let forward = normalized(SCNVector3(target.x - position.x, target.y - position.y, target.z - position.z))
        let worldUp = SCNVector3(0, 1, 0)
        let right = normalized(cross(forward, worldUp))
        let up = cross(right, forward)

        // SceneKit cameras look down their local -Z axis, with local +X = right, +Y = up.
        cameraNode.transform = SCNMatrix4(
            m11: right.x, m12: right.y, m13: right.z, m14: 0,
            m21: up.x, m22: up.y, m23: up.z, m24: 0,
            m31: -forward.x, m32: -forward.y, m33: -forward.z, m34: 0,
            m41: position.x, m42: position.y, m43: position.z, m44: 1
        )
    }

    // MARK: - Gestures

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view else { return }
        let t = gesture.translation(in: view)
        yaw -= Float(t.x) * 0.006
        gesture.setTranslation(.zero, in: view)
        updateCameraTransform()
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        radius = min(maxRadius, max(minRadius, radius / Float(gesture.scale)))
        gesture.scale = 1
        updateCameraTransform()
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view else { return }
        let point = gesture.location(in: view)
        let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
        guard let hit = hits.first, let name = nodeName(for: hit.node) else { return }
        handleTapOnNode(named: name)
    }

    private func nodeName(for node: SCNNode) -> String? {
        var current: SCNNode? = node
        while let n = current {
            if let name = n.name { return name }
            current = n.parent
        }
        return nil
    }

    private func handleTapOnNode(named name: String) {
        if hud?.buildModeOn == true {
            handleBuildTap(named: name)
            return
        }

        if name.hasPrefix("item:") {
            let id = String(name.dropFirst("item:".count))
            guard let item = buildState.item(withID: id), World.furnitureCatalog[item.type]?.action != nil else { return }
            simNode.startAction(towardItemID: id)
            return
        }

        guard let (tx, ty) = parseFloorName(name) else { return }
        let occupied = buildState.occupiedTiles()
        guard Pathfinding.isWalkable(tx, ty, occupied: occupied) else { return }
        let start = simNode.tile
        guard let path = Pathfinding.findPath(from: start, to: (tx, ty), occupied: occupied) else { return }
        simNode.cancelCurrentActivity()
        simNode.path = path
    }

    private func parseFloorName(_ name: String) -> (Int, Int)? {
        guard name.hasPrefix("floor:") else { return nil }
        let parts = name.dropFirst("floor:".count).split(separator: ":")
        guard parts.count == 2, let tx = Int(parts[0]), let ty = Int(parts[1]) else { return nil }
        return (tx, ty)
    }

    // MARK: - Build mode

    /// Tapping furniture while in build mode sells it for half price; tapping empty ground
    /// places whatever's selected in the HUD's shopping strip (see HUDView.buildStrip).
    private func handleBuildTap(named name: String) {
        guard let hud else { return }

        if name.hasPrefix("item:") {
            let id = String(name.dropFirst("item:".count))
            guard let existing = buildState.item(withID: id), existing.type != "car", let cat = World.furnitureCatalog[existing.type] else {
                hud.postToast("Tego nie można sprzedać.")
                return
            }
            let refund = cat.cost / 2
            buildState.remove(id: id)
            removeFurnitureNode(id: id)
            money += Double(refund)
            hud.postToast("Sprzedano: \(cat.label) (+\(refund) zł)")
            return
        }

        guard let (tx, ty) = parseFloorName(name) else { return }
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
        worldNode.addChildNode(node)
    }

    private func removeFurnitureNode(id: String) {
        furnitureNodes[id]?.removeFromParentNode()
        furnitureNodes.removeValue(forKey: id)
    }

    // MARK: - Per-frame update

    /// SceneKit calls this on its own rendering thread, not the main thread — so game-state
    /// mutations (SCNNode positions, plain ivars) happen here directly, but everything destined
    /// for the @Published GameHUDModel (SwiftUI) is collected locally and only ever written from
    /// the main.async block at the end.
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        defer { lastUpdateTime = time }
        guard lastUpdateTime > 0 else { return }
        let dt = min(time - lastUpdateTime, 0.1)

        simNode.advance(dt: Float(dt))

        var toastMessages: [String] = []

        let hour = Int(minutesOfDay / 60) % 24
        if let message = simNode.beginPendingActionIfArrived(hour: hour) {
            toastMessages.append(message)
        }

        accumMs += dt * 1000
        while accumMs >= baseMinMs {
            accumMs -= baseMinMs
            tickMinute(into: &toastMessages)
        }

        saveAccumSec += dt
        if saveAccumSec >= saveIntervalSec {
            saveAccumSec = 0
            persistState()
        }

        guard hud != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let hud = self.hud else { return }
            for message in toastMessages { hud.postToast(message) }
            self.pushHUD(to: hud)
        }
    }

    private func pushHUD(to hud: GameHUDModel) {
        hud.money = money
        hud.day = day
        hud.timeLabel = formattedTime()
        hud.jobTitle = CareerCatalog.jobTitles[simNode.jobLevel]
        hud.needs = simNode.needs
        if let info = simNode.aspirationInfo {
            hud.aspirationIcon = info.icon
            hud.aspirationName = info.name
            hud.aspirationProgress = info.progress
            hud.aspirationDone = info.done
        }
    }

    /// One simulated minute of game time: need decay, action progress, warnings, autonomy and
    /// the aspiration check — mirrors app.js's tickMinutes(1) body. Toast text is appended to
    /// `toastMessages` rather than posted directly, since this runs off the main thread.
    private func tickMinute(into toastMessages: inout [String]) {
        minutesOfDay += 1
        while minutesOfDay >= 1440 {
            minutesOfDay -= 1440
            day += 1
        }

        simNode.applyNeedDecay(minutes: 1)
        if let result = simNode.progressAction(minutes: 1) {
            money += result.moneyDelta
            toastMessages.append(result.message)
        }
        toastMessages.append(contentsOf: simNode.checkWarnings())
        if let message = simNode.tryAutonomy() {
            toastMessages.append(message)
        }
        if let result = simNode.checkAspiration() {
            money += result.moneyDelta
            toastMessages.append(result.message)
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

    // MARK: - World assembly

    private func buildWorld() {
        for ty in 0..<World.rows {
            for tx in 0..<World.cols {
                guard let zone = World.zone(atTx: tx, ty: ty) else { continue }
                worldNode.addChildNode(makeFloorTile(tx: tx, ty: ty, zone: zone))
            }
        }

        for wall in World.walls {
            if let node = makeWall(wall) {
                worldNode.addChildNode(node)
            }
        }

        for item in buildState.items {
            addFurnitureNode(for: item)
        }

        simNode = SimNode(startX: 3, startY: 3, color: UIColor(hex: characterColorHex), name: characterName)
        simNode.trait = characterTrait
        if let aspiration = characterAspiration {
            simNode.aspiration = aspiration
        }
        worldNode.addChildNode(simNode)

        worldNode.position = SCNVector3(-Float(World.cols - 1) / 2, 0, -Float(World.rows - 1) / 2)
    }

    private func makeFloorTile(tx: Int, ty: Int, zone: Zone) -> SCNNode {
        let checker = (tx + ty) % 2 == 0
        let color: UIColor
        switch zone.floorType {
        case "tile":
            color = UIColor(hex: zone.color).shaded(checker ? 1.0 : 0.9)
        case "grass":
            color = UIColor(hex: "#7ec46a")
        default:
            color = UIColor(hex: zone.color)
        }

        let geometry = SCNBox(width: 0.96, height: 0.06, length: 0.96, chamferRadius: 0)
        geometry.firstMaterial?.diffuse.contents = color
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(Float(tx), -0.03, Float(ty))
        node.name = "floor:\(tx):\(ty)"
        return node
    }

    private func makeWall(_ wall: WallSpec) -> SCNNode? {
        if wall.kind == .door { return nil } // an open gap you walk through, matching pathfinding

        let thickness: CGFloat = 0.08
        let wallLength: CGFloat = 1.0
        let height: CGFloat = 1.6
        let box = wall.edge == .north
            ? SCNBox(width: wallLength, height: height, length: thickness, chamferRadius: 0)
            : SCNBox(width: thickness, height: height, length: wallLength, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = wall.kind == .window ? UIColor(hex: "#dff1ff") : UIColor(hex: "#f1e8d9")

        let node = SCNNode(geometry: box)
        let cx = Float(wall.tx), cz = Float(wall.ty)
        switch wall.edge {
        case .north: node.position = SCNVector3(cx, Float(height / 2), cz - 0.5)
        case .west: node.position = SCNVector3(cx - 0.5, Float(height / 2), cz)
        }
        return node
    }

    private func makeFurniture(_ item: PlacedItem) -> SCNNode? {
        guard let cat = World.furnitureCatalog[item.type] else { return nil }
        let boxHeight = max(0.15, Float(cat.height) / 55)

        let box = SCNBox(width: 0.7, height: CGFloat(boxHeight), length: 0.7, chamferRadius: 0.02)
        box.firstMaterial?.diffuse.contents = UIColor(hex: cat.color)
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(Float(item.x), boxHeight / 2, Float(item.y))
        node.name = "item:\(item.id)"

        let icon = makeBillboardLabel(cat.icon, size: 0.28)
        icon.position = SCNVector3(0, boxHeight / 2 + 0.24, 0)
        node.addChildNode(icon)

        return node
    }
}
