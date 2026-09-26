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

/// A personality trait picked at character creation — ported from app.js's TRAITS. `needMods`
/// multiplies a specific need's decay rate; `salaryMod` multiplies wages; `funGainMod` multiplies
/// how much any action's need-gain restores (app.js's generic traitMod(trait, "funGain", 1),
/// despite the name it applies to every action, not just fun ones).
struct TraitMeta {
    let name: String
    let desc: String
    let needMods: [String: Double]
    let salaryMod: Double
    let funGainMod: Double
}

enum TraitCatalog {
    static let all: [String: TraitMeta] = [
        "towarzyski": TraitMeta(name: "Towarzyski", desc: "Kontakty spadają wolniej.", needMods: ["social": 0.5], salaryMod: 1, funGainMod: 1),
        "pracowity": TraitMeta(name: "Pracowity", desc: "Zarabia więcej w pracy.", needMods: [:], salaryMod: 1.35, funGainMod: 1),
        "leniwy": TraitMeta(name: "Leniwy", desc: "Energia spada wolniej.", needMods: ["energy": 0.6], salaryMod: 1, funGainMod: 1),
        "imprezowicz": TraitMeta(name: "Imprezowicz", desc: "Zabawa spada szybciej, ale rośnie mocniej.", needMods: ["fun": 1.5], salaryMod: 1, funGainMod: 1.3),
    ]
}

// Character appearance (skin/hair/clothing/body type) lives in CharacterAppearance.swift.

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

/// A life goal with a one-time cash reward on completion — ported from app.js's ASPIRATIONS.
/// `check`/`progress` take the SimNode itself so they can read whatever stat they need (a skill
/// level, job level, ...) without this file needing to know SimNode's internals.
struct Aspiration {
    let name: String
    let icon: String
    let desc: String
    let reward: Double
    let check: (SimNode) -> Bool
    let progress: (SimNode) -> (current: Double, total: Double)
}

enum AspirationCatalog {
    // "soulmate" (build a full relationship with a housemate) isn't ported yet — there's no
    // second Sim to have a relationship with.
    static let all: [String: Aspiration] = [
        "chef": Aspiration(
            name: "Mistrz Kuchni", icon: "🍳", desc: "Osiągnij najwyższy poziom gotowania.", reward: 400,
            check: { ($0.skills["cooking"] ?? 0) >= SkillCatalog.maxLevel },
            progress: { (min($0.skills["cooking"] ?? 0, SkillCatalog.maxLevel), SkillCatalog.maxLevel) }
        ),
        "tycoon": Aspiration(
            name: "Rekin Biznesu", icon: "💼", desc: "Zostań Prezesem w pracy.", reward: 600,
            check: { $0.jobLevel >= CareerCatalog.jobTitles.count - 1 },
            progress: { (Double($0.jobLevel + 1), Double(CareerCatalog.jobTitles.count)) }
        ),
        "social": Aspiration(
            name: "Dusza Towarzystwa", icon: "🗣️", desc: "Osiągnij najwyższy poziom charyzmy.", reward: 400,
            check: { ($0.skills["charisma"] ?? 0) >= SkillCatalog.maxLevel },
            progress: { (min($0.skills["charisma"] ?? 0, SkillCatalog.maxLevel), SkillCatalog.maxLevel) }
        ),
        "athlete": Aspiration(
            name: "Żelazna Kondycja", icon: "💪", desc: "Osiągnij najwyższy poziom kondycji.", reward: 400,
            check: { ($0.skills["fitness"] ?? 0) >= SkillCatalog.maxLevel },
            progress: { (min($0.skills["fitness"] ?? 0, SkillCatalog.maxLevel), SkillCatalog.maxLevel) }
        ),
    ]
}
