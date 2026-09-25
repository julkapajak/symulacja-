import SpriteKit
import UIKit

/// Isometric projection and small geometry helpers shared by everything GameScene draws.
///
/// `Iso.project` deliberately keeps the web prototype's canvas convention (x right, y DOWN)
/// so the wall/floor math below can be transcribed from app.js almost verbatim. Call
/// `Iso.toScene` on a finished point right before handing it to SpriteKit, which is y-UP.
enum Iso {
    static let tileWidth: CGFloat = 52
    static let tileHeight: CGFloat = 26

    static func project(_ tx: CGFloat, _ ty: CGFloat) -> CGPoint {
        CGPoint(x: (tx - ty) * (tileWidth / 2), y: (tx + ty) * (tileHeight / 2))
    }

    static func project(_ tx: Int, _ ty: Int) -> CGPoint {
        project(CGFloat(tx), CGFloat(ty))
    }

    static func toScene(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: -p.y)
    }
}

func lerpPt(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

/// Bilinear point on the quad face spanned by (b0 -> b1) at the base and (t0 -> t1) at the top,
/// u across the face (0...1) and v from base (0) to top (1). Used to place windows/door jambs
/// and furniture detail precisely on a wall or box face regardless of its screen orientation.
func facePoint(_ b0: CGPoint, _ b1: CGPoint, _ t0: CGPoint, _ t1: CGPoint, _ u: CGFloat, _ v: CGFloat) -> CGPoint {
    let bx = b0.x + (b1.x - b0.x) * u, by = b0.y + (b1.y - b0.y) * u
    let tx = t0.x + (t1.x - t0.x) * u, ty = t0.y + (t1.y - t0.y) * u
    return CGPoint(x: bx + (tx - bx) * v, y: by + (ty - by) * v)
}

func bilerp(_ n: CGPoint, _ e: CGPoint, _ s: CGPoint, _ w: CGPoint, _ u: CGFloat, _ v: CGFloat) -> CGPoint {
    let x = n.x * (1 - u) * (1 - v) + e.x * u * (1 - v) + s.x * u * v + w.x * (1 - u) * v
    let y = n.y * (1 - u) * (1 - v) + e.y * u * (1 - v) + s.y * u * v + w.y * (1 - u) * v
    return CGPoint(x: x, y: y)
}

/// Deterministic tiny PRNG so decorative details (grass speckles) are stable across frames
/// without needing to cache state per tile.
struct SeededRNG {
    private var state: UInt32
    init(seed: UInt32) { state = seed == 0 ? 0xBADC0DE : seed }
    mutating func nextUnit() -> Double {
        state = 1664525 &* state &+ 1013904223
        return Double(state) / Double(UInt32.max)
    }
}

extension SKColor {
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

    func shaded(_ factor: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: min(1, r * factor), green: min(1, g * factor), blue: min(1, b * factor), alpha: a)
    }
}

/// Builds a closed CGPath from canvas-convention points, converting each to scene space.
func isoPath(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard let first = points.first else { return path }
    path.move(to: Iso.toScene(first))
    for p in points.dropFirst() {
        path.addLine(to: Iso.toScene(p))
    }
    path.closeSubpath()
    return path
}

func isoQuad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, fill: SKColor, stroke: SKColor = .clear, lineWidth: CGFloat = 1) -> SKShapeNode {
    let shape = SKShapeNode(path: isoPath([a, b, c, d]))
    shape.fillColor = fill
    shape.strokeColor = stroke
    shape.lineWidth = lineWidth
    return shape
}
