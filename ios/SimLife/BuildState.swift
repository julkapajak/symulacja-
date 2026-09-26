import Foundation

/// One piece of furniture actually in the house. Unlike Phase 1-3's fixed STARTER_ITEMS list,
/// build mode can add, move and remove these at runtime, so each needs a stable id independent
/// of its type (there can be more than one of the same type once the player starts building).
struct PlacedItem: Codable, Equatable {
    let id: String
    let type: String
    var x: Int
    var y: Int
}

/// Owns the mutable list of furniture in the house — the model half of build mode. GameCoordinator
/// keeps the visual SCNNodes in sync with this; SimNode consults it for pathfinding/action
/// lookups instead of a static list. Mirrors app.js's state.items + itemAt/occupiedTiles, but
/// with real add/remove instead of just reading a fixed array.
final class BuildState {
    private(set) var items: [PlacedItem]
    private var nextID: Int

    init(items: [PlacedItem]) {
        self.items = items
        nextID = 1
    }

    func occupiedTiles() -> Set<String> {
        Set(items.map { "\($0.x),\($0.y)" })
    }

    func item(at x: Int, _ y: Int) -> PlacedItem? {
        items.first { $0.x == x && $0.y == y }
    }

    func item(withID id: String) -> PlacedItem? {
        items.first { $0.id == id }
    }

    @discardableResult
    func place(type: String, x: Int, y: Int) -> PlacedItem? {
        guard World.furnitureCatalog[type] != nil, item(at: x, y) == nil else { return nil }
        let id = "item_\(nextID)"
        nextID += 1
        let placed = PlacedItem(id: id, type: type, x: x, y: y)
        items.append(placed)
        return placed
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
    }
}
