import SwiftUI

/// The glass HUD overlaid on top of the SpriteKit scene: money/day/time/job up top, need bars
/// down below, toasts in between — a lightweight native stand-in for app.js's HTML HUD.
struct HUDView: View {
    @ObservedObject var model: GameHUDModel

    var body: some View {
        VStack {
            topBar
            Spacer()
            toastStack
            needsBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            hudChip(icon: "💰", text: "\(Int(model.money)) zł")
            hudChip(icon: "☀️", text: "Dzień \(model.day)")
            hudChip(icon: "🕒", text: model.timeLabel)
            Spacer()
            Text(model.jobTitle)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.4), in: Capsule())
        }
    }

    private func hudChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(icon)
            Text(text).font(.subheadline.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.4), in: Capsule())
    }

    private var toastStack: some View {
        VStack(spacing: 6) {
            ForEach(model.toasts) { toast in
                Text(toast.text)
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.65), in: Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toasts.map(\.id))
        .padding(.bottom, 12)
    }

    private var needsBar: some View {
        HStack(spacing: 10) {
            ForEach(NeedKeys.all, id: \.self) { key in
                if let meta = NeedCatalog.table[key] {
                    needPill(meta: meta, value: model.needs[key] ?? 100)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
    }

    private func needPill(meta: NeedMeta, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(meta.icon).font(.title3)
            ProgressView(value: max(0, min(100, value)) / 100)
                .tint(color(for: value))
                .frame(width: 42)
        }
    }

    private func color(for value: Double) -> Color {
        if value <= 20 { return .red }
        if value <= 45 { return .orange }
        return .green
    }
}
