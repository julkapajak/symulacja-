import Foundation

/// A Sim's visual appearance, chosen once in the character creator (or restored from a save) —
/// replaces the single arbitrary "body color" from earlier phases with something closer to real
/// character creation: a natural skin tone, hair (color + style), a clothing color (which, unlike
/// skin, can be anything), and a body type that actually changes the model's proportions.
struct CharacterAppearance: Codable, Equatable {
    var skinTone: String
    var hairColor: String
    var hairStyle: String
    var clothingColor: String
    var bodyType: String

    static let `default` = CharacterAppearance(
        skinTone: CharacterCatalog.skinTones[1],
        hairColor: CharacterCatalog.hairColors[0],
        hairStyle: CharacterCatalog.hairStyles[1],
        clothingColor: CharacterCatalog.clothingColors[0],
        bodyType: CharacterCatalog.bodyTypeOrder[1]
    )
}

enum CharacterCatalog {
    /// A spread of real skin tones — not the old arbitrary bright-color palette, which was
    /// standing in for "whatever color the whole Sim is" rather than skin specifically.
    static let skinTones = ["#ffe0bd", "#f1c27d", "#e0ac69", "#c68642", "#8d5524", "#5c3a21"]

    static let hairColors = ["#1b1210", "#3b2314", "#6b4423", "#b5651d", "#d9b26f", "#e8e8e8", "#8a1c1c"]

    static let hairStyles = ["bald", "short", "bun", "long"]
    static let hairStyleLabels: [String: String] = [
        "bald": "Łysy", "short": "Krótkie", "bun": "Kok", "long": "Długie",
    ]

    /// Clothes, unlike skin, can be any color — this is the old bright palette (plus two
    /// neutrals), now scoped correctly to clothing rather than the whole body.
    static let clothingColors = ["#ff6f59", "#3fa796", "#f6c445", "#7b6cf6", "#e85ea0", "#4fb0e8", "#2b2b2b", "#f2f2f2"]

    static let bodyTypeOrder = ["thin", "average", "heavy"]
    static let bodyTypeLabels: [String: String] = [
        "thin": "Szczupła", "average": "Przeciętna", "heavy": "Postawna",
    ]
    /// Uniform scale applied to the body capsule for each type.
    static let bodyTypeScale: [String: Float] = ["thin": 0.82, "average": 1.0, "heavy": 1.3]
}
