import SwiftUI

/// Shown once, before the very first game session (ContentView skips it when a save already
/// exists). Mirrors app.js's #charCreator modal, extended with real appearance choices (natural
/// skin tones, hair, clothing color, body type) instead of a single arbitrary body color.
struct CharacterCreatorView: View {
    @Binding var name: String
    @Binding var appearance: CharacterAppearance
    @Binding var trait: String?
    @Binding var aspiration: String
    let onStart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    Text("Stwórz swojego Sima")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    section(title: "Imię") {
                        TextField("np. Ala", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 320)
                    }

                    section(title: "Odcień skóry") {
                        swatchRow(CharacterCatalog.skinTones, selected: appearance.skinTone) { appearance.skinTone = $0 }
                    }

                    section(title: "Kolor włosów") {
                        swatchRow(CharacterCatalog.hairColors, selected: appearance.hairColor) { appearance.hairColor = $0 }
                    }

                    section(title: "Fryzura") {
                        VStack(spacing: 8) {
                            ForEach(CharacterCatalog.hairStyles, id: \.self) { key in
                                pickRow(title: CharacterCatalog.hairStyleLabels[key] ?? key, subtitle: nil, isSelected: appearance.hairStyle == key) {
                                    appearance.hairStyle = key
                                }
                            }
                        }
                    }

                    section(title: "Kolor ubrań") {
                        swatchRow(CharacterCatalog.clothingColors, selected: appearance.clothingColor) { appearance.clothingColor = $0 }
                    }

                    section(title: "Sylwetka") {
                        VStack(spacing: 8) {
                            ForEach(CharacterCatalog.bodyTypeOrder, id: \.self) { key in
                                pickRow(title: CharacterCatalog.bodyTypeLabels[key] ?? key, subtitle: nil, isSelected: appearance.bodyType == key) {
                                    appearance.bodyType = key
                                }
                            }
                        }
                    }

                    section(title: "Cecha charakteru") {
                        VStack(spacing: 8) {
                            ForEach(TraitCatalog.all.keys.sorted(), id: \.self) { key in
                                if let meta = TraitCatalog.all[key] {
                                    pickRow(title: meta.name, subtitle: meta.desc, isSelected: trait == key) {
                                        trait = (trait == key) ? nil : key
                                    }
                                }
                            }
                        }
                    }

                    section(title: "Aspiracja życiowa") {
                        VStack(spacing: 8) {
                            ForEach(AspirationCatalog.all.keys.sorted(), id: \.self) { key in
                                if let asp = AspirationCatalog.all[key] {
                                    pickRow(icon: asp.icon, title: asp.name, subtitle: asp.desc, isSelected: aspiration == key) {
                                        aspiration = key
                                    }
                                }
                            }
                        }
                    }

                    Button(action: onStart) {
                        Text("Zacznij grę")
                            .font(.headline.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color.orange, in: Capsule())
                    }
                    .padding(.top, 10)
                }
                .padding(24)
                .frame(maxWidth: 520)
            }
        }
    }

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(.white)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatchRow(_ hexColors: [String], selected: String, onPick: @escaping (String) -> Void) -> some View {
        HStack(spacing: 14) {
            ForEach(hexColors, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(.white, lineWidth: selected == hex ? 3 : 0.5))
                    .onTapGesture { onPick(hex) }
            }
        }
    }

    private func pickRow(icon: String? = nil, title: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Text(icon)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.bold())
                    if let subtitle {
                        Text(subtitle).font(.caption)
                    }
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(isSelected ? Color.orange.opacity(0.35) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
