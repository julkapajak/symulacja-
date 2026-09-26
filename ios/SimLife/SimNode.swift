import SceneKit

/// An action currently in progress (using a piece of furniture, or working). Mirrors app.js's
/// sim.action.
struct ActiveAction {
    let itemID: String
    let label: String
    let need: String?
    let gain: Double
    let durationMinutes: Double
    let side: [String: Double]
    let isWork: Bool
    let skill: String?
    let skillGain: Double
    var elapsed: Double = 0
}

/// What finishing a tick of simulation produced, so the coordinator can apply the money change
/// and show the toast without SimNode needing to know about the HUD.
struct ActionResult {
    let message: String
    let moneyDelta: Double
}

/// A Sim that can walk a queued path of grid tiles and use furniture along the way, rendered as a
/// real 3D figure (capsule body + sphere head) in the SceneKit world. `updateWorldPosition()`
/// moves the whole node to match its current (possibly fractional, mid-step) grid position each
/// frame — mirrors app.js's moveSimAlongPath. The needs/skills/career/action methods below mirror
/// app.js's applyNeedDecay/progressAction/checkWarnings/autonomyTick/startAction/finishAction —
/// none of them touch rendering at all, which is why this class survived the SpriteKit → SceneKit
/// rewrite almost unchanged below the visuals.
final class SimNode: SCNNode {
    let simName: String
    var gridX: Float
    var gridY: Float
    var path: [(x: Int, y: Int)] = []

    // Named walkSpeed, not speed: SCNNode already declares a `speed` property
    // (it scales the playback rate of actions run on this node).
    let walkSpeed: Float = 4.2 // tiles per second, matches app.js sim.speed

    var needs: [String: Double]
    var skills: [String: Double] = ["cooking": 0, "fitness": 0, "charisma": 0]
    var jobLevel = 0
    var shiftsWorked = 0
    var currentAction: ActiveAction?
    var pendingItemID: String?
    private var warned: Set<String> = []

    // Auto-assigned by default; the character creator (ContentView/GameCoordinator.
    // configureNewCharacter) overwrites these before the first frame if the player made an
    // explicit choice.
    var aspiration: String?
    var aspirationDone = false
    var trait: String?

    /// Set by GameCoordinator right after construction. Actions/pathfinding look up furniture
    /// through it (rather than a static list) so build mode's add/move/remove is reflected
    /// immediately.
    var buildState: BuildState!

    var appearance: CharacterAppearance
    private let visualsRoot = SCNNode()

    init(startX: Int, startY: Int, appearance: CharacterAppearance, name: String) {
        gridX = Float(startX)
        gridY = Float(startY)
        simName = name
        needs = Dictionary(uniqueKeysWithValues: NeedKeys.all.map { ($0, 85.0) })
        aspiration = AspirationCatalog.all.keys.randomElement()
        self.appearance = appearance
        super.init()

        addChildNode(visualsRoot)
        rebuildVisuals()

        let label = makeBillboardLabel(name, size: 0.22)
        label.position = SCNVector3(0, 1.2, 0)
        addChildNode(label)

        updateWorldPosition()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Replaces the whole body with fresh geometry for the current `appearance` — called on
    /// creation and again when a save is loaded (a save's appearance can differ from whatever the
    /// node was built with by default).
    func rebuildVisuals() {
        visualsRoot.childNodes.forEach { $0.removeFromParentNode() }

        let scale = CGFloat(CharacterCatalog.bodyTypeScale[appearance.bodyType] ?? 1.0)
        let bodyHeight: CGFloat = 0.7
        let capRadius: CGFloat = 0.16 * scale
        let headRadius: CGFloat = 0.15

        let body = SCNCapsule(capRadius: capRadius, height: bodyHeight)
        body.firstMaterial?.diffuse.contents = UIColor(hex: appearance.clothingColor)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, Float(bodyHeight / 2) + 0.05, 0)
        visualsRoot.addChildNode(bodyNode)

        let head = SCNSphere(radius: headRadius)
        head.firstMaterial?.diffuse.contents = UIColor(hex: appearance.skinTone)
        let headNode = SCNNode(geometry: head)
        let headY = Float(bodyHeight) + 0.05 + Float(headRadius)
        headNode.position = SCNVector3(0, headY, 0)
        visualsRoot.addChildNode(headNode)

        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.02)
            eye.firstMaterial?.diffuse.contents = UIColor(hex: "#2b2b2b")
            eye.firstMaterial?.lightingModel = .constant // stays visibly dark regardless of light angle
            let eyeNode = SCNNode(geometry: eye)
            eyeNode.position = SCNVector3(0.06 * side, headY + 0.01, Float(headRadius) - 0.02)
            visualsRoot.addChildNode(eyeNode)
        }

        if let hair = makeHair(style: appearance.hairStyle, colorHex: appearance.hairColor, headRadius: headRadius, headY: headY) {
            visualsRoot.addChildNode(hair)
        }
    }

    private func makeHair(style: String, colorHex: String, headRadius: CGFloat, headY: Float) -> SCNNode? {
        let color = UIColor(hex: colorHex)

        func capNode() -> SCNNode {
            let cap = SCNSphere(radius: headRadius * 1.05)
            cap.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: cap)
            node.position = SCNVector3(0, headY + Float(headRadius) * 0.15, 0)
            node.scale = SCNVector3(1, 0.55, 1)
            return node
        }

        switch style {
        case "short":
            return capNode()

        case "bun":
            let container = SCNNode()
            container.addChildNode(capNode())
            let bun = SCNSphere(radius: headRadius * 0.35)
            bun.firstMaterial?.diffuse.contents = color
            let bunNode = SCNNode(geometry: bun)
            bunNode.position = SCNVector3(0, headY + Float(headRadius) * 0.5, -Float(headRadius) * 0.7)
            container.addChildNode(bunNode)
            return container

        case "long":
            let container = SCNNode()
            container.addChildNode(capNode())
            let strand = SCNCapsule(capRadius: headRadius * 0.35, height: headRadius * 1.6)
            strand.firstMaterial?.diffuse.contents = color
            let strandNode = SCNNode(geometry: strand)
            strandNode.position = SCNVector3(0, headY - Float(headRadius) * 0.5, -Float(headRadius) * 0.6)
            container.addChildNode(strandNode)
            return container

        default: // "bald"
            return nil
        }
    }

    func updateWorldPosition() {
        position = SCNVector3(gridX, 0, gridY)
        name = "sim"
    }

    var tile: (x: Int, y: Int) {
        (Int(gridX.rounded()), Int(gridY.rounded()))
    }

    /// Advances along the queued path by `dt` seconds, matching app.js's step-toward-target logic,
    /// and turns to face the direction of travel.
    func advance(dt: Float) {
        guard let target = path.first else { return }
        let dx = Float(target.x) - gridX
        let dy = Float(target.y) - gridY
        let dist = (dx * dx + dy * dy).squareRoot()
        if dist == 0 {
            path.removeFirst()
            return
        }
        let step = walkSpeed * dt
        if step >= dist {
            gridX = Float(target.x)
            gridY = Float(target.y)
            path.removeFirst()
        } else {
            gridX += (dx / dist) * step
            gridY += (dy / dist) * step
        }
        eulerAngles.y = atan2(dx, dy)
        updateWorldPosition()
    }

    // MARK: - Actions

    /// Walks toward the given placed item (by its unique id, not type — build mode can have
    /// several of the same type) to use it once in range. Cancels whatever the Sim was doing.
    @discardableResult
    func startAction(towardItemID id: String) -> Bool {
        guard let item = buildState.item(withID: id) else { return false }
        guard let route = Pathfinding.findPathToNeighbor(from: tile, target: (item.x, item.y), occupied: buildState.occupiedTiles()) else { return false }
        currentAction = nil
        path = route
        pendingItemID = id
        return true
    }

    func cancelCurrentActivity() {
        currentAction = nil
        pendingItemID = nil
        path = []
    }

    /// Called once per frame after movement: if the Sim just arrived at a pending target, begin
    /// using it. Returns a toast message if something happened. If the target was sold out from
    /// under it mid-walk (build mode), this just quietly does nothing.
    func beginPendingActionIfArrived(hour: Int) -> String? {
        guard let itemID = pendingItemID, path.isEmpty else { return nil }
        pendingItemID = nil
        guard let item = buildState.item(withID: itemID), let action = World.furnitureCatalog[item.type]?.action else { return nil }
        if action.isWork && (hour < 8 || hour >= 18) {
            return "Praca dostępna tylko w godzinach 8:00–18:00."
        }
        currentAction = ActiveAction(
            itemID: itemID, label: action.label, need: action.need, gain: action.gain,
            durationMinutes: action.durationMinutes, side: action.side, isWork: action.isWork,
            skill: action.skill, skillGain: action.skillGain
        )
        return "\(simName): \(action.label)..."
    }

    // MARK: - Simulation ticks (called once per simulated minute)

    private var traitMeta: TraitMeta? {
        trait.flatMap { TraitCatalog.all[$0] }
    }

    func applyNeedDecay(minutes: Double) {
        let needMods = traitMeta?.needMods ?? [:]
        for k in NeedKeys.all {
            var mod = needMods[k] ?? 1
            if k == "energy" { mod *= 1 - (skills["fitness"] ?? 0) * 0.02 }
            let rate = (NeedCatalog.table[k]?.decay ?? 0) * mod * minutes
            needs[k] = max(0, min(100, (needs[k] ?? 100) - rate))
        }
    }

    func progressAction(minutes: Double) -> ActionResult? {
        guard var action = currentAction else { return nil }
        action.elapsed += minutes
        let frac = min(1, minutes / action.durationMinutes)

        if let need = action.need {
            let skillMult = action.skill.map { 1 + (skills[$0] ?? 0) * 0.05 } ?? 1
            let funGainMod = traitMeta?.funGainMod ?? 1
            needs[need] = max(0, min(100, (needs[need] ?? 0) + action.gain * frac * funGainMod * skillMult))
        }
        for (k, delta) in action.side {
            needs[k] = max(0, min(100, (needs[k] ?? 0) + delta * frac))
        }

        if action.elapsed >= action.durationMinutes {
            currentAction = nil
            return finishAction(action)
        }
        currentAction = action
        return nil
    }

    private func finishAction(_ action: ActiveAction) -> ActionResult {
        var message: String
        var moneyDelta: Double = 0

        if action.isWork {
            let base = Double(CareerCatalog.baseSalary[jobLevel])
            let charismaBonus = 1 + (skills["charisma"] ?? 0) * 0.03
            let salaryMod = traitMeta?.salaryMod ?? 1
            let pay = (base * salaryMod * charismaBonus).rounded()
            moneyDelta = pay
            shiftsWorked += 1
            message = "\(simName) zarobił \(Int(pay)) zł jako \(CareerCatalog.jobTitles[jobLevel])!"
            if jobLevel < CareerCatalog.jobTitles.count - 1 && shiftsWorked % CareerCatalog.shiftsPerPromotion == 0 {
                jobLevel += 1
                message += " 🎉 Awans! Teraz: \(CareerCatalog.jobTitles[jobLevel])"
            }
        } else {
            message = "\(simName) ukończył: \(action.label)"
        }

        if let skill = action.skill, action.skillGain > 0 {
            let before = skills[skill] ?? 0
            let after = min(SkillCatalog.maxLevel, before + action.skillGain)
            skills[skill] = after
            if Int(after) > Int(before), let meta = SkillCatalog.table[skill] {
                message += " 📈 \(meta.label) → poziom \(Int(after))!"
            }
        }

        return ActionResult(message: message, moneyDelta: moneyDelta)
    }

    /// Returns newly-crossed critical-need warnings this tick (mirrors app.js's checkWarnings,
    /// including the "no longer critical" reset so the same need can warn again later).
    func checkWarnings() -> [String] {
        var messages: [String] = []
        for k in NeedKeys.all {
            let value = needs[k] ?? 100
            if value <= 12 && !warned.contains(k) {
                warned.insert(k)
                if let meta = NeedCatalog.table[k] {
                    messages.append("⚠️ \(meta.label) (\(simName)) jest krytycznie niska!")
                }
            } else if value > 25 && warned.contains(k) {
                warned.remove(k)
            }
        }
        return messages
    }

    /// If idle and something is critically low, walk over and take care of it (mirrors app.js's
    /// autonomyTick with proactive=false, since there's no housemate yet to justify wandering).
    func tryAutonomy() -> String? {
        guard currentAction == nil, pendingItemID == nil, path.isEmpty else { return nil }
        let threshold = 15.0
        let needy = NeedKeys.all
            .filter { (needs[$0] ?? 100) <= threshold }
            .sorted { (needs[$0] ?? 100) < (needs[$1] ?? 100) }
        guard let need = needy.first else { return nil }

        let candidates = buildState.items.filter { item in
            guard let action = World.furnitureCatalog[item.type]?.action else { return false }
            return !action.isWork && action.need == need
        }
        guard !candidates.isEmpty else { return nil }

        let here = tile
        let target = candidates.min {
            (abs($0.x - here.x) + abs($0.y - here.y)) < (abs($1.x - here.x) + abs($1.y - here.y))
        }!
        guard let route = Pathfinding.findPathToNeighbor(from: here, target: (target.x, target.y), occupied: buildState.occupiedTiles()) else { return nil }
        path = route
        pendingItemID = target.id
        if let meta = NeedCatalog.table[need] {
            return "\(simName) sam idzie zaspokoić potrzebę: \(meta.label)"
        }
        return nil
    }

    // MARK: - Aspiration

    /// Call once per simulated minute (mirrors app.js's checkAspiration). Returns a reward toast
    /// the first time the goal is met; nil every other time, including forever after.
    func checkAspiration() -> ActionResult? {
        guard let key = aspiration, !aspirationDone, let asp = AspirationCatalog.all[key] else { return nil }
        guard asp.check(self) else { return nil }
        aspirationDone = true
        let message = "🏆 \(simName) spełnił(a) aspirację „\(asp.name)”! (+\(Int(asp.reward)) zł)"
        return ActionResult(message: message, moneyDelta: asp.reward)
    }

    var aspirationInfo: (icon: String, name: String, progress: Double, done: Bool)? {
        guard let key = aspiration, let asp = AspirationCatalog.all[key] else { return nil }
        let (current, total) = asp.progress(self)
        let fraction = total > 0 ? min(1, current / total) : 0
        return (asp.icon, asp.name, fraction, aspirationDone)
    }

    // MARK: - Save/load

    var saveData: SimSaveData {
        SimSaveData(
            name: simName, gridX: Double(gridX), gridY: Double(gridY),
            needs: needs, skills: skills, jobLevel: jobLevel, shiftsWorked: shiftsWorked,
            aspiration: aspiration, aspirationDone: aspirationDone, trait: trait, appearance: appearance
        )
    }

    /// Restores a save onto this node, teleporting it (no walk animation) to the saved tile and
    /// clearing any in-progress path/action, since the path/action referred to the old session.
    /// Also rebuilds the visuals for the saved appearance — without this, a returning player
    /// would always see whatever default look the Sim happened to be constructed with that
    /// session, not the one they actually chose.
    func applySaveData(_ data: SimSaveData) {
        gridX = Float(data.gridX)
        gridY = Float(data.gridY)
        needs = data.needs
        skills = data.skills
        jobLevel = data.jobLevel
        shiftsWorked = data.shiftsWorked
        aspiration = data.aspiration
        aspirationDone = data.aspirationDone
        trait = data.trait
        appearance = data.appearance
        rebuildVisuals()
        cancelCurrentActivity()
        updateWorldPosition()
    }
}
