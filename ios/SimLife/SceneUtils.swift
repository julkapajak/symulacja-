import UIKit
import SceneKit

extension UIColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    func shaded(_ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r * factor), green: min(1, g * factor), blue: min(1, b * factor), alpha: a)
    }
}

/// Deterministic tiny PRNG so decorative details are stable across frames without needing to
/// cache state per tile.
struct SeededRNG {
    private var state: UInt32
    init(seed: UInt32) { state = seed == 0 ? 0xBADC0DE : seed }
    mutating func nextUnit() -> Double {
        state = 1664525 &* state &+ 1013904223
        return Double(state) / Double(UInt32.max)
    }
}

/// A flat emoji/text label that always faces the camera — used for furniture icons and the
/// Sim's name tag, since SceneKit has no built-in "2D sprite in 3D space" primitive.
func makeBillboardLabel(_ text: String, size: CGFloat = 0.3, color: UIColor = .white) -> SCNNode {
    let textGeometry = SCNText(string: text, extrusionDepth: 0.2)
    textGeometry.font = UIFont.systemFont(ofSize: 32)
    textGeometry.flatness = 0.1
    textGeometry.firstMaterial?.diffuse.contents = color
    textGeometry.firstMaterial?.isDoubleSided = true

    let (minBound, maxBound) = textGeometry.boundingBox
    let textHeight = maxBound.y - minBound.y
    let scale = textHeight > 0 ? Float(size) / Float(textHeight) : 1

    let node = SCNNode(geometry: textGeometry)
    node.scale = SCNVector3(scale, scale, scale)
    node.pivot = SCNMatrix4MakeTranslation((maxBound.x + minBound.x) / 2, (maxBound.y + minBound.y) / 2, 0)
    node.constraints = [SCNBillboardConstraint()]
    return node
}
