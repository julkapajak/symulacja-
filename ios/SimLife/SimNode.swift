import SpriteKit

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

/// What finishing a tick of simulation produced, so GameScene can apply the money change and
/// show the toast without SimNode needing to know about the HUD.
struct ActionResult {
    let message: String
    let moneyDelta: Double
}

/// A Sim that can walk a queued path of grid tiles and use furniture along the way. Its visual
/// children are built once, relative to its own local origin (0,0 in scene space);
/// `updateScreenPosition()` then just moves the whole node to match its current (possibly
/// fractional, mid-step) grid position each frame — mirrors app.js's moveSimAlongPath, but
/// SpriteKit repositions the node instead of redrawing it. The needs/skills/career/action
/// methods below mirror app.js's applyNeedDecay/progressAction/checkWarnings/autonomyTick/
/// startAction/finishAction.
final class SimNode: SKNode {
    let simName: String
    var gridX: CGFloat
    var gridY: CGFloat
    var path: [(x: Int, y: Int)] = []

    // Named walkSpeed, not speed: SKNode already declares a `speed` property
    // (it scales the playback rate of actions run on this node).
    let walkSpeed: CGFloat = 4.2 // tiles per second, matches app.js sim.speed

    var needs: [String: Double]
    var skills: [String: Double] = ["cooking": 0, "fitness": 0, "charisma": 0]
    var jobLevel = 0
    var shiftsWorked = 0
    var currentAction: ActiveAction?
    var pendingActionID: String?
    private var warned: Set<String> = []

    init(startX: Int, startY: Int, color: SKColor, name: String) {
        gridX = CGFloat(startX)
        gridY = CGFloat(startY)
        simName = name
        needs = Dictionary(uniqueKeysWithValues: NeedKeys.all.map { ($0, 85.0) })
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

    var tile: (x: Int, y: Int) {
        (Int(gridX.rounded()), Int(gridY.rounded()))
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

    // MARK: - Actions

    /// Walks toward the given furniture type (by catalog id) to use it once in range. Cancels
    /// whatever the Sim was doing before.
    @discardableResult
    func startAction(towardItemType type: String) -> Bool {
        guard let placement = World.starterItems.first(where: { $0.type == type }) else { return false }
        guard let route = Pathfinding.findPathToNeighbor(from: tile, target: (placement.x, placement.y)) else { return false }
        currentAction = nil
        path = route
        pendingActionID = type
        return true
    }

    func cancelCurrentActivity() {
        currentAction = nil
        pendingActionID = nil
        path = []
    }

    /// Called once per frame after movement: if the Sim just arrived at a pending target, begin
    /// using it. Returns a toast message if something happened.
    func beginPendingActionIfArrived(hour: Int) -> String? {
        guard let itemID = pendingActionID, path.isEmpty else { return nil }
        pendingActionID = nil
        guard let action = World.furnitureCatalog[itemID]?.action else { return nil }
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

    func applyNeedDecay(minutes: Double) {
        for k in NeedKeys.all {
            let rate = (NeedCatalog.table[k]?.decay ?? 0) * minutes
            needs[k] = max(0, min(100, (needs[k] ?? 100) - rate))
        }
    }

    func progressAction(minutes: Double) -> ActionResult? {
        guard var action = currentAction else { return nil }
        action.elapsed += minutes
        let frac = min(1, minutes / action.durationMinutes)

        if let need = action.need {
            let skillMult = action.skill.map { 1 + (skills[$0] ?? 0) * 0.05 } ?? 1
            needs[need] = max(0, min(100, (needs[need] ?? 0) + action.gain * frac * skillMult))
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
            let pay = (base * charismaBonus).rounded()
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
        guard currentAction == nil, pendingActionID == nil, path.isEmpty else { return nil }
        let threshold = 15.0
        let needy = NeedKeys.all
            .filter { (needs[$0] ?? 100) <= threshold }
            .sorted { (needs[$0] ?? 100) < (needs[$1] ?? 100) }
        guard let need = needy.first else { return nil }

        let candidates = World.starterItems.filter { placement in
            guard let action = World.furnitureCatalog[placement.type]?.action else { return false }
            return !action.isWork && action.need == need
        }
        guard !candidates.isEmpty else { return nil }

        let here = tile
        let target = candidates.min {
            (abs($0.x - here.x) + abs($0.y - here.y)) < (abs($1.x - here.x) + abs($1.y - here.y))
        }!
        guard let route = Pathfinding.findPathToNeighbor(from: here, target: (target.x, target.y)) else { return nil }
        path = route
        pendingActionID = target.type
        if let meta = NeedCatalog.table[need] {
            return "\(simName) sam idzie zaspokoić potrzebę: \(meta.label)"
        }
        return nil
    }
}
