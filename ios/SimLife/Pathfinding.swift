import Foundation

/// Wall-aware BFS pathfinding, mirroring app.js's bfsFrom/findPathToTile/findPathToNeighbor/
/// edgeBlocked exactly: a 4-directional grid search that refuses to cross a solid wall edge or
/// step onto furniture.
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

    private static func key(_ x: Int, _ y: Int) -> String { "\(x),\(y)" }

    private static func bfsDistances(from start: (x: Int, y: Int)) -> (dist: [String: Int], prev: [String: (x: Int, y: Int)]) {
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
        return (dist, prev)
    }

    private static func reconstructPath(prev: [String: (x: Int, y: Int)], from start: (x: Int, y: Int), to goal: (x: Int, y: Int)) -> [(x: Int, y: Int)]? {
        var path: [(x: Int, y: Int)] = []
        var cur = goal
        while cur.x != start.x || cur.y != start.y {
            path.append(cur)
            guard let p = prev[key(cur.x, cur.y)] else { return nil }
            cur = p
        }
        return path.reversed()
    }

    static func findPath(from start: (x: Int, y: Int), to goal: (x: Int, y: Int)) -> [(x: Int, y: Int)]? {
        if start.x == goal.x && start.y == goal.y { return [] }
        guard isWalkable(goal.x, goal.y) else { return nil }
        let (dist, prev) = bfsDistances(from: start)
        guard dist[key(goal.x, goal.y)] != nil else { return nil }
        return reconstructPath(prev: prev, from: start, to: goal)
    }

    /// Paths to a tile *adjacent* to `target` (the nearest reachable one), for walking up to a
    /// piece of furniture to use it rather than standing on top of it.
    static func findPathToNeighbor(from start: (x: Int, y: Int), target: (x: Int, y: Int)) -> [(x: Int, y: Int)]? {
        let (dist, prev) = bfsDistances(from: start)
        let candidates = [
            (target.x + 1, target.y), (target.x - 1, target.y),
            (target.x, target.y + 1), (target.x, target.y - 1),
        ]
        var best: (x: Int, y: Int)?
        var bestD = Int.max
        for c in candidates {
            guard isWalkable(c.0, c.1), let d = dist[key(c.0, c.1)], d < bestD else { continue }
            bestD = d
            best = (c.0, c.1)
        }
        guard let goal = best else { return nil }
        if goal.x == start.x && goal.y == start.y { return [] }
        return reconstructPath(prev: prev, from: start, to: goal)
    }
}
