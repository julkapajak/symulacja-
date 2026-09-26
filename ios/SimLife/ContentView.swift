import SwiftUI

struct ContentView: View {
    @StateObject private var hud = GameHUDModel()

    // A stored property (created exactly once), not computed — SwiftUI re-evaluates `body`
    // often once the HUD starts publishing every frame, and a computed coordinator would have
    // rebuilt (and re-animated-in) a brand new GameCoordinator/scene on every single redraw.
    @State private var coordinator = GameCoordinator()

    // The creator only ever runs once per install: if a save already exists, there's already a
    // Sim with a name/color/trait/aspiration to resume, so we skip straight to the game.
    @State private var needsCharacterCreation = SaveStore.load() == nil
    @State private var draftName = ""
    @State private var draftColorHex = CharacterCatalog.colors[0]
    @State private var draftTrait: String?
    @State private var draftAspiration = AspirationCatalog.all.keys.sorted().first ?? "chef"

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if !needsCharacterCreation {
                    SceneContainerView(coordinator: coordinator)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ignoresSafeArea()
                    HUDView(model: hud)
                }

                if needsCharacterCreation {
                    CharacterCreatorView(
                        name: $draftName, colorHex: $draftColorHex, trait: $draftTrait, aspiration: $draftAspiration
                    ) {
                        coordinator.configureNewCharacter(name: draftName, colorHex: draftColorHex, trait: draftTrait, aspiration: draftAspiration)
                        needsCharacterCreation = false
                    }
                }
            }
        }
        .onAppear { coordinator.hud = hud }
    }
}

#Preview {
    ContentView()
}
