import Foundation

/// Wall-aware BFS pathfinding, mirroring app.js's bfsFrom/findPathToTile/edgeBlocked exactly:
/// a 4-directional grid search that refuses to cross a solid wall edge or step onto furniture.
enum Pathfinding {
    static let occupiedTiles: Set<String> = Set(World.starterItems.map { "\($0.x),\($0.y)" })

    static func isWalkable(_ x: Int, _ y: Int) -> Bool {
        guard x >= 0, y >= 0, x < World.cols, y < World.rows else { return false }
        return !occupiedTiles.contains("\(x),\(y)")
    }

    static func edgeBlocked(_ ax: Int, _ ay: Int, _ bx: Int, _ by: Int) -> Bool {
        if bx == ax && by == ay - 1 { return World.blockedEdges.contains("\(ax),\(ay),N") }
        if bx == ax - 1 && by == ay { return World.blockedEdges.contains("\(ax),\(ay),W") }
        if bx == ax && by == ay + 1 { return World.blockedEdges.contains("\(bx),\(by),N") }
        if bx == ax + 1 && by == ay { return World.blockedEdges.contains("\(bx),\(by),W") }
        return false
    }

    static func findPath(from start: (x: Int, y: Int), to goal: (x: Int, y: Int)) -> [(x: Int, y: Int)]? {
        if start.x == goal.x && start.y == goal.y { return [] }
        guard isWalkable(goal.x, goal.y) else { return nil }

        func key(_ x: Int, _ y: Int) -> String { "\(x),\(y)" }

        var dist: [String: Int] = [key(start.x, start.y): 0]
        var prev: [String: (x: Int, y: Int)] = [:]
        var queue: [(x: Int, y: Int)] = [start]
        var qi = 0

        while qi < queue.count {
            let cur = queue[qi]; qi += 1
            let d = dist[key(cur.x, cur.y)]!
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = cur.x + dx, ny = cur.y + dy
                let k = key(nx, ny)
                if !isWalkable(nx, ny) || dist[k] != nil { continue }
                if edgeBlocked(cur.x, cur.y, nx, ny) { continue }
                dist[k] = d + 1
                prev[k] = cur
                queue.append((nx, ny))
            }
        }

        guard dist[key(goal.x, goal.y)] != nil else { return nil }

        var path: [(x: Int, y: Int)] = []
        var cur = goal
        while cur.x != start.x || cur.y != start.y {
            path.append(cur)
            guard let p = prev[key(cur.x, cur.y)] else { return nil }
            cur = p
        }
        return path.reversed()
    }
}
