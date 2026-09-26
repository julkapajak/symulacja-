import Foundation
import Combine

struct Toast: Identifiable {
    let id = UUID()
    let text: String
}

/// The bridge between GameScene (SpriteKit, driving the simulation every frame) and HUDView
/// (SwiftUI). GameScene writes to these @Published properties from its update(_:) loop; SwiftUI
/// re-renders whenever they change. Toasts mirror app.js's toast() — auto-dismiss after 4s.
final class GameHUDModel: ObservableObject {
    @Published var money: Double = 500
    @Published var day: Int = 1
    @Published var timeLabel: String = "08:00"
    @Published var jobTitle: String = CareerCatalog.jobTitles[0]
    @Published var needs: [String: Double] = Dictionary(uniqueKeysWithValues: NeedKeys.all.map { ($0, 85.0) })
    @Published var toasts: [Toast] = []

    @Published var aspirationIcon = ""
    @Published var aspirationName = ""
    @Published var aspirationProgress: Double = 0
    @Published var aspirationDone = false

    // Build mode: toggled from the HUD's hammer button. `selectedItemType` is which catalog
    // item is "in hand" — GameScene reads both on each tap (see GameScene.handleTap).
    @Published var buildModeOn = false
    @Published var selectedItemType: String?

    func postToast(_ text: String) {
        let toast = Toast(text: text)
        toasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            self?.toasts.removeAll { $0.id == toast.id }
        }
    }
}
