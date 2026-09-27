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
    private let cameraTargetNode = SCNNode()
    private let worldNode = SCNNode()
    private var simNode: SimNode!
    private var partnerNode: SimNode?
    private var buildState: BuildState!
    private var furnitureNodes: [String: SCNNode] = [:]

    // Day/night sky + weather (Faza 12) — the lights are stored properties (rather than locals in
    // setUpLighting()) so updateSkyAndLighting(hour:) can retune their intensity/color every
    // simulated minute; grassMaterials lets the seasonal yard color be repainted in place instead
    // of rebuilding the floor geometry whenever the day or weather changes.
    private let ambientLightNode = SCNNode()
    private let sunLightNode = SCNNode()
    private let fillLightNode = SCNNode()
    private var grassMaterials: [SCNMaterial] = []
    private let weatherEmitterNode = SCNNode()
    private lazy var rainParticleSystem = WeatherParticles.makeRain()
    private lazy var snowParticleSystem = WeatherParticles.makeSnow()
    private var weather: Weather = .clear

    weak var view: SCNView?

    /// Set by ContentView right after creating the coordinator. renderer(_:updateAtTime:) pushes
    /// simulation state into it every frame; nil only for the handful of frames before that
    /// assignment lands.
    var hud: GameHUDModel? {
        didSet {
            hud?.onInteraction = { [weak self] kind in self?.performInteraction(kind) }
        }
    }

    // Housemate relationship (shared, not per-sim — mirrors app.js's state.relationship).
    private var relationship: Double = 30
    /// Set from GameCoordinator.renderer(_:updateAtTime:) when the player's walk-to-housemate
    /// finishes, so the interaction menu can be shown (from the main-thread dispatch, since it
    /// touches @Published HUD state) once they're actually adjacent.
    private var awaitingPartnerMenu = false

    // Camera orbit state (spherical coordinates around the house's center). Pitch is a fixed
    // constant, not user-controllable — like the classic Sims camera, dragging only spins the
    // view around the house (yaw); the ground's tilt on screen never changes, only zoom and
    // which side you're looking from do.
    // Starting yaw of 0 looks straight at the house's long side (it's 16x9 tiles) rather than at
    // its corner — a 45° diagonal view of such an elongated rectangle reads as a thin tilted
    // sliver rather than a house. radius is generous enough to fit the ~17-unit diagonal at any
    // yaw once the player starts orbiting.
    private var yaw: Float = 0
    private let pitch: Float = 0.62
    private var radius: Float = 20
    private let minRadius: Float = 6
    private let maxRadius: Float = 32

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
    private var characterAppearance = CharacterAppearance.default
    private var characterTrait: String?
    private var characterAspiration: String?

    // Housemate choice from the character creator's optional last step. Also set (before
    // buildWorld() runs) from a save's partner data — see start().
    private var wantsPartner = false
    private var partnerName = "Współlokator"
    private var partnerAppearance = CharacterAppearance.default

    private var hasStarted = false

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func configureNewCharacter(name: String, appearance: CharacterAppearance, trait: String?, aspiration: String) {
        characterName = name.isEmpty ? "Sim" : name
        characterAppearance = appearance
        characterTrait = trait
        characterAspiration = aspiration
    }

    func configureNewPartner(name: String, appearance: CharacterAppearance) {
        wantsPartner = true
        partnerName = name.isEmpty ? "Współlokator" : name
        partnerAppearance = appearance
    }

    // MARK: - Setup

    /// Called once, from SceneContainerView.makeUIView — deliberately *not* from init(). The
    /// character creator (ContentView) calls configureNewCharacter() only once the player
    /// finishes it, and SceneContainerView (hence this) isn't created until after that, so
    /// buildWorld() below always sees whatever the player actually chose.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        setUpLighting()
        setUpCamera()
        setUpWeatherEmitter()

        let savedData = SaveStore.load()
        buildState = BuildState(items: savedData?.items ?? World.starterItems)

        // A save carries the weather it was written with (mirrors app.js's loadGame()); a brand
        // new game rolls fresh weather for day 1, same as app.js's boot()-time rollWeather().
        if let savedWeather = savedData?.weather, let parsed = Weather(rawValue: savedWeather) {
            weather = parsed
        } else {
            weather = WeatherSystem.rollWeather(forDay: day)
        }

        // Read before buildWorld() so it knows whether to construct a partner node at all —
        // applySaveData(_:) below only updates an *existing* node's stats/appearance, it can't
        // retroactively create one.
        if let partnerSave = savedData?.partner {
            wantsPartner = true
            partnerName = partnerSave.name
            partnerAppearance = partnerSave.appearance
        }

        buildWorld()
        scene.rootNode.addChildNode(worldNode)
        simNode.buildState = buildState
        partnerNode?.buildState = buildState

        if let savedData {
            money = savedData.money
            day = savedData.day
            minutesOfDay = savedData.minutesOfDay
            relationship = savedData.relationship
            simNode.applySaveData(savedData.sim)
            if let partnerSave = savedData.partner {
                partnerNode?.applySaveData(partnerSave)
            }
        }

        updateSkyAndLighting(hour: minutesOfDay / 60)
        updateWeatherVisuals()

        NotificationCenter.default.addObserver(self, selector: #selector(persistState), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(persistState), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    private func setUpLighting() {
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor(white: 0.55, alpha: 1)
        scene.rootNode.addChildNode(ambientLightNode)

        sunLightNode.light = SCNLight()
        sunLightNode.light!.type = .directional
        sunLightNode.light!.color = UIColor(white: 1.0, alpha: 1)
        sunLightNode.light!.castsShadow = true
        sunLightNode.light!.shadowMode = .deferred
        sunLightNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sunLightNode)

        // A dimmer, opposite-facing fill light softens the shadow side of walls/furniture instead
        // of leaving it flat black, without the cost of a second shadow-casting light. At night it
        // doubles as faint moonlight (see updateSkyAndLighting).
        fillLightNode.light = SCNLight()
        fillLightNode.light!.type = .directional
        fillLightNode.light!.color = UIColor(white: 0.35, alpha: 1)
        fillLightNode.light!.castsShadow = false
        fillLightNode.eulerAngles = SCNVector3(-Float.pi / 5, -Float.pi * 3 / 4, 0)
        scene.rootNode.addChildNode(fillLightNode)
    }

    /// Faza 12: retunes the sky color and the three lights for the given hour-of-day (0..<24) —
    /// called once per simulated minute (see tickMinute), mirroring app.js's skyColors/nightAmount/
    /// warmAmount, which it drove straight into the 2D canvas render every frame. A SceneKit scene
    /// only needs the underlying color/intensity values updated, not a redraw.
    private func updateSkyAndLighting(hour: Double) {
        scene.background.contents = WeatherSystem.skyColor(atHour: hour)

        let night = WeatherSystem.nightAmount(atHour: hour)
        let warm = WeatherSystem.warmAmount(atHour: hour)
        let nightFactor = CGFloat(night)

        let moonBlue = UIColor(red: 0.55, green: 0.62, blue: 0.85, alpha: 1)
        let sunWarm = UIColor(red: 1, green: 0.75, blue: 0.45, alpha: 1)

        ambientLightNode.light!.color = UIColor(white: 0.55, alpha: 1).lerp(to: UIColor(white: 0.18, alpha: 1), t: nightFactor)
        ambientLightNode.light!.intensity = 1000 - 650 * nightFactor

        sunLightNode.light!.color = UIColor(white: 1, alpha: 1).lerp(to: sunWarm, t: CGFloat(warm))
        sunLightNode.light!.intensity = 1000 * (1 - nightFactor)

        fillLightNode.light!.color = UIColor(white: 0.35, alpha: 1).lerp(to: moonBlue, t: nightFactor)
        fillLightNode.light!.intensity = 350 + 250 * nightFactor
    }

    private func setUpWeatherEmitter() {
        weatherEmitterNode.position = SCNVector3(Float(World.cols) / 2, 6, Float(World.rows) / 2)
        worldNode.addChildNode(weatherEmitterNode)
    }

    /// Repaints the yard for the current season/weather and switches the rain/snow particle
    /// system — called once at startup and again whenever a new day rolls fresh weather.
    private func updateWeatherVisuals() {
        let grassColor = WeatherSystem.grassColor(forDay: day, weather: weather)
        for material in grassMaterials {
            material.diffuse.contents = grassColor
        }

        weatherEmitterNode.removeAllParticleSystems()
        switch weather {
        case .clear: break
        case .rain: weatherEmitterNode.addParticleSystem(rainParticleSystem)
        case .snow: weatherEmitterNode.addParticleSystem(snowParticleSystem)
        }
    }

    private func setUpCamera() {
        let camera = SCNCamera()
        camera.zFar = 100
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        // A dedicated, always-at-the-house-center target node, tracked via SCNLookAtConstraint
        // with gimbal lock on — SceneKit's own, officially documented way to keep a camera level
        // (no roll) while it's constrained to face a point, rather than computing the orientation
        // by hand.
        cameraTargetNode.position = SCNVector3(0, 0.8, 0)
        scene.rootNode.addChildNode(cameraTargetNode)
        let lookAt = SCNLookAtConstraint(target: cameraTargetNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        updateCameraTransform()
    }

    /// Positions the camera on a sphere around the house; the SCNLookAtConstraint set up in
    /// setUpCamera() handles keeping it pointed at the center and level.
    private func updateCameraTransform() {
        let x = radius * cos(pitch) * sin(yaw)
        let z = radius * cos(pitch) * cos(yaw)
        let y = radius * sin(pitch)
        cameraNode.position = SCNVector3(x, y, z)
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

        if name == "partner" {
            handlePartnerTap()
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

    // MARK: - Housemate interactions

    /// Tapping the housemate either opens the interaction menu right away (already adjacent) or
    /// walks the player Sim there first — mirrors app.js's "click roommate when close to interact".
    private func handlePartnerTap() {
        guard let partner = partnerNode else { return }
        if tileDistance(simNode.tile, partner.tile) <= 1 {
            if let hud { presentPartnerMenu(to: hud) }
            return
        }
        let occupied = buildState.occupiedTiles()
        guard let route = Pathfinding.findPathToNeighbor(from: simNode.tile, target: partner.tile, occupied: occupied) else { return }
        simNode.cancelCurrentActivity()
        simNode.path = route
        awaitingPartnerMenu = true
    }

    private func tileDistance(_ a: (x: Int, y: Int), _ b: (x: Int, y: Int)) -> Int {
        abs(a.x - b.x) + abs(a.y - b.y)
    }

    /// Called from the main-thread dispatch in renderer(_:updateAtTime:) once a walk-to-housemate
    /// finishes — only actually opens the menu if they ended up adjacent (a housemate can wander
    /// off mid-walk, in which case this quietly does nothing).
    private func presentPartnerMenuIfClose() {
        guard let hud, let partner = partnerNode, tileDistance(simNode.tile, partner.tile) <= 1 else { return }
        presentPartnerMenu(to: hud)
    }

    private func presentPartnerMenu(to hud: GameHUDModel) {
        var options: [PartnerInteractionKind] = [.talk]
        if relationship >= PartnerInteractionKind.hug.requiredRelationship { options.append(.hug) }
        if relationship >= PartnerInteractionKind.kiss.requiredRelationship { options.append(.kiss) }
        hud.partnerInteractionOptions = options
    }

    /// Applies an interaction picked from the HUD's menu (see HUDView.partnerInteractionMenu) —
    /// always runs on the main thread, since it's a direct SwiftUI Button action.
    private func performInteraction(_ kind: PartnerInteractionKind) {
        guard let partner = partnerNode else { return }
        relationship = min(100, relationship + kind.relationshipGain)
        simNode.needs["social"] = min(100, (simNode.needs["social"] ?? 0) + 10)
        partner.needs["social"] = min(100, (partner.needs["social"] ?? 0) + 10)
        if kind != .talk {
            simNode.needs["fun"] = min(100, (simNode.needs["fun"] ?? 0) + 8)
            partner.needs["fun"] = min(100, (partner.needs["fun"] ?? 0) + 8)
        }
        hud?.postToast("\(simNode.simName) i \(partner.simName): \(kind.label.lowercased())! (+\(Int(kind.relationshipGain)) bliskości)")
        hud?.partnerInteractionOptions = []
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
        partnerNode?.advance(dt: Float(dt))

        var toastMessages: [String] = []

        let hour = Int(minutesOfDay / 60) % 24
        if let message = simNode.beginPendingActionIfArrived(hour: hour) {
            toastMessages.append(message)
        }
        if let message = partnerNode?.beginPendingActionIfArrived(hour: hour) {
            toastMessages.append(message)
        }

        var shouldShowPartnerMenu = false
        if awaitingPartnerMenu, simNode.path.isEmpty {
            awaitingPartnerMenu = false
            shouldShowPartnerMenu = true
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
            if shouldShowPartnerMenu { self.presentPartnerMenuIfClose() }
        }
    }

    private func pushHUD(to hud: GameHUDModel) {
        hud.money = money
        hud.day = day
        hud.season = WeatherSystem.seasonName(forDay: day)
        hud.weatherIcon = weather.hudIcon
        hud.timeLabel = formattedTime()
        hud.jobTitle = CareerCatalog.jobTitles[simNode.jobLevel]
        hud.needs = simNode.needs
        hud.hasPartner = partnerNode != nil
        hud.relationship = relationship

        if simNode.aspiration == "soulmate" {
            // Needs the shared relationship value, which SimNode doesn't have — see
            // checkSoulmateAspiration.
            hud.aspirationIcon = "💗"
            hud.aspirationName = "Miłość Na Całe Życie"
            hud.aspirationProgress = partnerNode != nil ? min(1, relationship / 100) : 0
            hud.aspirationDone = simNode.aspirationDone
        } else if let info = simNode.aspirationInfo {
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
            weather = WeatherSystem.rollWeather(forDay: day)
            updateWeatherVisuals()
        }
        updateSkyAndLighting(hour: minutesOfDay / 60)

        simNode.applyNeedDecay(minutes: 1)
        if let result = simNode.progressAction(minutes: 1) {
            money += result.moneyDelta
            toastMessages.append(result.message)
        }
        toastMessages.append(contentsOf: simNode.checkWarnings())
        if let message = simNode.tryAutonomy(proactive: false) {
            toastMessages.append(message)
        }
        if let result = simNode.checkAspiration() {
            money += result.moneyDelta
            toastMessages.append(result.message)
        }
        if let result = simNode.checkSoulmateAspiration(hasPartner: partnerNode != nil, relationship: relationship) {
            money += result.moneyDelta
            toastMessages.append(result.message)
        }

        if let partner = partnerNode {
            partner.applyNeedDecay(minutes: 1)
            if let result = partner.progressAction(minutes: 1) {
                money += result.moneyDelta
                toastMessages.append(result.message)
            }
            toastMessages.append(contentsOf: partner.checkWarnings())
            // proactive=true: a housemate wanders off for fun/social on its own, not just when
            // something is critical — mirrors app.js's autonomyTick(sim, true) for the partner.
            if let message = partner.tryAutonomy(proactive: true) {
                toastMessages.append(message)
            }
        }
    }

    private func formattedTime() -> String {
        let h = Int(minutesOfDay / 60) % 24
        let m = Int(minutesOfDay) % 60
        return String(format: "%02d:%02d", h, m)
    }

    // MARK: - Save/load

    @objc private func persistState() {
        let data = GameSaveData(
            money: money, day: day, minutesOfDay: minutesOfDay, sim: simNode.saveData, items: buildState.items,
            relationship: relationship, partner: partnerNode?.saveData, weather: weather.rawValue
        )
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

        simNode = SimNode(startX: 3, startY: 3, appearance: characterAppearance, name: characterName, nodeTag: "sim")
        simNode.trait = characterTrait
        if let aspiration = characterAspiration {
            simNode.aspiration = aspiration
        }
        worldNode.addChildNode(simNode)

        if wantsPartner {
            let partner = SimNode(startX: 4, startY: 3, appearance: partnerAppearance, name: partnerName, nodeTag: "partner")
            worldNode.addChildNode(partner)
            partnerNode = partner
        }

        worldNode.position = SCNVector3(-Float(World.cols - 1) / 2, 0, -Float(World.rows - 1) / 2)
    }

    private func makeFloorTile(tx: Int, ty: Int, zone: Zone) -> SCNNode {
        let checker = (tx + ty) % 2 == 0
        let color: UIColor
        switch zone.floorType {
        case "tile":
            color = UIColor(hex: zone.color).shaded(checker ? 1.0 : 0.9)
        case "grass":
            color = WeatherSystem.grassColor(forDay: day, weather: weather)
        default:
            color = UIColor(hex: zone.color)
        }

        let geometry = SCNBox(width: 0.96, height: 0.06, length: 0.96, chamferRadius: 0)
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = zone.floorType == "tile" ? 0.25 : (zone.floorType == "grass" ? 0.95 : 0.6)
        material.metalness.contents = 0.0
        geometry.materials = [material]
        if zone.floorType == "grass" { grassMaterials.append(material) }
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
        let isWindow = wall.kind == .window
        let wallMaterial = SCNMaterial()
        wallMaterial.lightingModel = .physicallyBased
        wallMaterial.diffuse.contents = isWindow ? UIColor(hex: "#dff1ff") : UIColor(hex: "#f1e8d9")
        wallMaterial.roughness.contents = isWindow ? 0.05 : 0.85
        wallMaterial.metalness.contents = isWindow ? 0.2 : 0.0
        wallMaterial.transparency = isWindow ? 0.55 : 1.0
        box.materials = [wallMaterial]

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

        let node = FurnitureModelBuilder.build(type: item.type, color: UIColor(hex: cat.color))
        node.position = SCNVector3(Float(item.x), 0, Float(item.y))
        node.name = "item:\(item.id)"

        let iconY = FurnitureModelBuilder.iconHeight(for: item.type)
        let icon = makeBillboardLabel(cat.icon, size: 0.28)
        icon.position = SCNVector3(0, iconY, 0)
        node.addChildNode(icon)

        return node
    }
}
