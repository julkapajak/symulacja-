import Foundation

/// Persisted state, mirroring app.js's localStorage save (SAVE_KEY = "simlife_save_v2"):
/// enough to resume where the player left off without needing a full replay of the day.
struct SimSaveData: Codable {
    var name: String
    var gridX: Double
    var gridY: Double
    var needs: [String: Double]
    var skills: [String: Double]
    var jobLevel: Int
    var shiftsWorked: Int
    var aspiration: String?
    var aspirationDone: Bool
    var trait: String?
}

struct GameSaveData: Codable {
    var money: Double
    var day: Int
    var minutesOfDay: Double
    var sim: SimSaveData
    var items: [PlacedItem]
}

enum SaveStore {
    private static let key = "simlife_save_v1"

    static func save(_ data: GameSaveData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        UserDefaults.standard.set(encoded, forKey: key)
    }

    static func load() -> GameSaveData? {
        guard let raw = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GameSaveData.self, from: raw)
    }
}
