import SwiftUI

struct ReviewPromptView: View {
    let onRate: () -> Void
    let onNotNow: () -> Void
    let onNoThanks: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 18) {
            VStack(spacing: 18) {
                appIconBadge

                VStack(spacing: 8) {
                    Text("Enjoying KRANK?")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text("If you're having fun, a quick App Store rating really helps.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    actionButton(title: "Rate it", style: .glassProminent, action: onRate)
                    actionButton(title: "Not now", style: .glass, action: onNotNow)
                    actionButton(title: "No thanks", style: .glass, action: onNoThanks)
                        .opacity(0.82)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: 340)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            }
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 14)
        }
        .padding(.horizontal, 24)
    }

    private var appIconBadge: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 84, height: 84)
                .glassEffect(.regular, in: .circle)

            Image("ReviewPromptAppIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
        .accessibilityHidden(true)
    }

    private func actionButton<Style: PrimitiveButtonStyle>(
        title: String,
        style: Style,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(style)
    }
}
