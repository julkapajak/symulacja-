import CoreGraphics
import Foundation

/// Static description of the house: rooms, walls, and starter furniture.
/// Mirrors app.js's ZONES / buildWalls() / ITEM_CATALOG / STARTER_ITEMS exactly,
/// so the native house layout matches the web prototype tile-for-tile.
struct Zone {
    let x0: Int, y0: Int, x1: Int, y1: Int
    let color: String
    let name: String
    let floorType: String

    func contains(_ tx: Int, _ ty: Int) -> Bool {
        tx >= x0 && tx <= x1 && ty >= y0 && ty <= y1
    }
}

enum WallEdge {
    case north, west
}

enum WallKind {
    case solid, door, window
}

struct WallSpec {
    let tx: Int
    let ty: Int
    let edge: WallEdge
    let kind: WallKind
}

struct FurniturePlacement {
    let type: String
    let x: Int
    let y: Int
}

struct FurnitureCatalogEntry {
    let label: String
    let icon: String
    let color: String
    let height: CGFloat
}

enum World {
    static let cols = 16
    static let rows = 9
    static let wallHeight: CGFloat = 88

    static let zones: [Zone] = [
        Zone(x0: 0, y0: 0, x1: 3, y1: 3, color: "#e8d2a8", name: "kuchnia", floorType: "tile"),
        Zone(x0: 0, y0: 4, x1: 3, y1: 8, color: "#bfe0ea", name: "łazienka", floorType: "tile"),
        Zone(x0: 4, y0: 0, x1: 7, y1: 8, color: "#c9a06e", name: "sypialnia", floorType: "wood"),
        Zone(x0: 8, y0: 0, x1: 11, y1: 8, color: "#caa070", name: "salon", floorType: "wood"),
        Zone(x0: 12, y0: 0, x1: 15, y1: 8, color: "#7ec46a", name: "ogród", floorType: "grass"),
    ]

    static func zone(atTx tx: Int, ty: Int) -> Zone? {
        zones.first { $0.contains(tx, ty) }
    }

    static func isIndoor(_ zone: Zone?) -> Bool {
        guard let zone else { return false }
        return zone.name != "ogród"
    }

    // Edge keys are "tx,ty,N" / "tx,ty,W", matching the JS key format exactly.
    static let doorEdges: Set<String> = ["4,2,W", "4,6,W", "2,4,N", "8,4,W"]
    static let windowEdges: Set<String> = ["1,0,N", "5,0,N", "9,0,N", "0,1,W", "0,6,W"]

    static let walls: [WallSpec] = buildWalls()

    /// Edge keys ("tx,ty,N" / "tx,ty,W") that block movement across them — every solid wall,
    /// mirroring app.js's BLOCKED_EDGES. Doors and windows never block.
    static let blockedEdges: Set<String> = {
        var set = Set<String>()
        for wall in walls where wall.kind == .solid {
            let edgeChar = wall.edge == .north ? "N" : "W"
            set.insert("\(wall.tx),\(wall.ty),\(edgeChar)")
        }
        return set
    }()

    private static func buildWalls() -> [WallSpec] {
        var result: [WallSpec] = []
        for ty in 0..<rows {
            for tx in 0..<cols {
                guard let z = zone(atTx: tx, ty: ty), isIndoor(z) else { continue }

                let zoneNorth = ty > 0 ? zone(atTx: tx, ty: ty - 1) : nil
                if ty == 0 || zoneNorth?.name != z.name {
                    let key = "\(tx),\(ty),N"
                    let kind: WallKind = doorEdges.contains(key) ? .door : (windowEdges.contains(key) ? .window : .solid)
                    result.append(WallSpec(tx: tx, ty: ty, edge: .north, kind: kind))
                }

                let zoneWest = tx > 0 ? zone(atTx: tx - 1, ty: ty) : nil
                if tx == 0 || zoneWest?.name != z.name {
                    let key = "\(tx),\(ty),W"
                    let kind: WallKind = doorEdges.contains(key) ? .door : (windowEdges.contains(key) ? .window : .solid)
                    result.append(WallSpec(tx: tx, ty: ty, edge: .west, kind: kind))
                }
            }
        }
        return result
    }

    static let furnitureCatalog: [String: FurnitureCatalogEntry] = [
        "fridge": FurnitureCatalogEntry(label: "Lodówka", icon: "🍽️", color: "#f2f4f4", height: 40),
        "sink": FurnitureCatalogEntry(label: "Umywalka", icon: "🚰", color: "#dceff5", height: 20),
        "toilet": FurnitureCatalogEntry(label: "Toaleta", icon: "🚽", color: "#ffffff", height: 22),
        "shower": FurnitureCatalogEntry(label: "Prysznic", icon: "🚿", color: "#cdeaf7", height: 34),
        "bed": FurnitureCatalogEntry(label: "Łóżko", icon: "🛏️", color: "#e3d3f5", height: 16),
        "bookshelf": FurnitureCatalogEntry(label: "Regał", icon: "📚", color: "#b3814f", height: 42),
        "sofa": FurnitureCatalogEntry(label: "Sofa", icon: "🛋️", color: "#efa08a", height: 22),
        "tv": FurnitureCatalogEntry(label: "Telewizor", icon: "📺", color: "#33393f", height: 30),
        "computer": FurnitureCatalogEntry(label: "Komputer", icon: "💻", color: "#7a828c", height: 26),
        "car": FurnitureCatalogEntry(label: "Praca (Samochód)", icon: "🚗", color: "#e35b52", height: 26),
        "tree": FurnitureCatalogEntry(label: "Drzewo", icon: "🌳", color: "#5fae5f", height: 36),
    ]

    static let starterItems: [FurniturePlacement] = [
        FurniturePlacement(type: "fridge", x: 1, y: 1),
        FurniturePlacement(type: "sink", x: 2, y: 1),
        FurniturePlacement(type: "toilet", x: 1, y: 5),
        FurniturePlacement(type: "shower", x: 1, y: 7),
        FurniturePlacement(type: "bed", x: 5, y: 2),
        FurniturePlacement(type: "bookshelf", x: 7, y: 1),
        FurniturePlacement(type: "sofa", x: 9, y: 3),
        FurniturePlacement(type: "tv", x: 10, y: 3),
        FurniturePlacement(type: "computer", x: 9, y: 6),
        FurniturePlacement(type: "car", x: 13, y: 3),
        FurniturePlacement(type: "tree", x: 14, y: 1),
    ]
}
