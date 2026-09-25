import Foundation

/// Needs, skills and career constants — ported from app.js's NEED_META / SKILL_META /
/// JOB_TITLES / JOB_BASE_SALARY. Kept separate from WorldData.swift (which is about the house
/// itself) since this is about the Sim's simulation, not the building.
struct NeedMeta {
    let icon: String
    let label: String
    let decay: Double // per simulated minute
}

enum NeedKeys {
    static let all = ["hunger", "energy", "hygiene", "fun", "social", "bladder"]
}

enum NeedCatalog {
    static let table: [String: NeedMeta] = [
        "hunger": NeedMeta(icon: "🍗", label: "Głód", decay: 0.055),
        "energy": NeedMeta(icon: "⚡", label: "Energia", decay: 0.04),
        "hygiene": NeedMeta(icon: "🧼", label: "Higiena", decay: 0.03),
        "fun": NeedMeta(icon: "🎉", label: "Zabawa", decay: 0.05),
        "social": NeedMeta(icon: "💬", label: "Kontakty", decay: 0.03),
        "bladder": NeedMeta(icon: "🚻", label: "Pęcherz", decay: 0.065),
    ]
}

struct SkillMeta {
    let icon: String
    let label: String
}

enum SkillCatalog {
    static let table: [String: SkillMeta] = [
        "cooking": SkillMeta(icon: "🍳", label: "Gotowanie"),
        "fitness": SkillMeta(icon: "💪", label: "Kondycja"),
        "charisma": SkillMeta(icon: "🗣️", label: "Charyzma"),
    ]
    static let maxLevel: Double = 10
}

enum CareerCatalog {
    static let jobTitles = ["Stażysta", "Pracownik", "Specjalista", "Kierownik", "Dyrektor", "Prezes"]
    static let baseSalary = [80, 120, 170, 230, 300, 400]
    static let shiftsPerPromotion = 3
}

/// What tapping a piece of furniture does. `need` + `gain` restore a need over `durationMinutes`;
/// `side` are secondary effects (e.g. a shower costs a little energy); `isWork` is the job action.
struct FurnitureAction {
    let label: String
    let need: String?
    let gain: Double
    let durationMinutes: Double
    let side: [String: Double]
    let isWork: Bool
    let skill: String?
    let skillGain: Double
}
