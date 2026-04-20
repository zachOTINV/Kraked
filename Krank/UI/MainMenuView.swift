import SwiftUI
import StoreKit
import UIKit

private enum MainMenuRoute: Hashable {
    case levelSelect
}

struct MainMenuView: View {
    @Environment(\.openURL) private var openURL
    let automationConfig: AutomationConfig
    @StateObject private var purchaseManager = InAppPurchaseManager.shared
    private let feedback = FeedbackManager.shared
    @State private var path = NavigationPath()
    @State private var showRemoveAdsModal = false
    @State private var showUnlockLevelsModal = false
    @State private var showSettingsModal = false
    @State private var showHowToPlayModal = false
    @State private var showShareSheet = false
    @State private var purchaseMessage: String?
    @AppStorage("krank.setting.sound") private var soundEnabled = true
    @AppStorage("krank.setting.haptics") private var hapticsEnabled = true
    @AppStorage("krank.setting.music") private var musicEnabled = true
    @AppStorage("krank.setting.darkmode") private var darkModeEnabled = false
    @AppStorage("krank.iap.bonuspacks.unlocked") private var hasUnlockedBonusPacks = false
    @AppStorage("krank.iap.removeads.unlocked") private var hasRemovedAds = false

    private var pageBackgroundStart: Color {
        darkModeEnabled ? Color(red: 0.07, green: 0.08, blue: 0.10) : BrandColors.pageBackgroundA
    }

    private var pageBackgroundEnd: Color {
        darkModeEnabled ? Color(red: 0.11, green: 0.13, blue: 0.17) : BrandColors.pageBackgroundB
    }

    private var primaryTextColor: Color {
        darkModeEnabled ? Color(red: 0.93, green: 0.95, blue: 0.98) : BrandColors.navy
    }

    private var secondaryTextColor: Color {
        darkModeEnabled ? Color(red: 0.63, green: 0.69, blue: 0.79) : BrandColors.navyMuted
    }

    private var rowBackground: Color {
        darkModeEnabled ? Color(red: 0.17, green: 0.19, blue: 0.24) : Color.white.opacity(0.72)
    }

    private var modalBackground: Color {
        darkModeEnabled ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.99)
    }

    private var dividerColor: Color {
        darkModeEnabled ? Color.white.opacity(0.08) : Color(red: 0.88, green: 0.90, blue: 0.94)
    }

    private var overlayColor: Color {
        Color.black.opacity(darkModeEnabled ? 0.5 : 0.34)
    }

    private var unlockLevelsIcon: String {
        hasUnlockedBonusPacks ? "checkmark.seal.fill" : "square.stack.3d.up.fill"
    }

    private var unlockLevelsColor: Color {
        hasUnlockedBonusPacks
            ? Color(red: 0.16, green: 0.76, blue: 0.40)
            : Color(red: 0.96, green: 0.63, blue: 0.18)
    }

    private var unlockLevelsTitle: String {
        hasUnlockedBonusPacks ? "More Levels Unlocked" : "Unlock More Levels"
    }

    // Set this once your App Store product page exists to enable direct "Write a Review" deep-linking.
    private let appStoreNumericID = "6759940511"

    private var appStoreURL: URL? {
        guard !appStoreNumericID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appStoreNumericID)")
    }

    private var reviewURL: URL? {
        guard !appStoreNumericID.isEmpty else { return nil }
        return URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreNumericID)?action=write-review")
    }

    private var shareItems: [Any] {
        let baseText = "I'm playing Krank: Logic & Color. Try this rule-based puzzle game."
        if let appStoreURL {
            return [baseText, appStoreURL]
        }
        return [baseText]
    }

    init(automationConfig: AutomationConfig = .disabled) {
        self.automationConfig = automationConfig
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [pageBackgroundStart, pageBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 44)

                    VStack(spacing: 8) {
                        Text("KRANK")
                            .font(.system(size: 42, weight: .black, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(primaryTextColor)

                        Text("LOGIC & COLOR")
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(secondaryTextColor.opacity(0.75))
                    }

                    Button {
                        feedback.playTap()
                        openLevelSelect()
                    } label: {
                        HStack(spacing: 12) {
                            Text("PLAY")
                                .font(.system(size: 20, weight: .heavy))

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(BrandColors.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                    }

                    VStack(spacing: 14) {
                        Button {
                            feedback.playTap()
                            showUnlockLevelsModal = true
                        } label: {
                            menuRow(icon: unlockLevelsIcon, color: unlockLevelsColor, title: unlockLevelsTitle)
                        }
                        .buttonStyle(.plain)
                        Button {
                            feedback.playTap()
                            showHowToPlayModal = true
                        } label: {
                            menuRow(icon: "book.fill", color: Color.green, title: "How to Play")
                        }
                        .buttonStyle(.plain)
                        Button {
                            feedback.playTap()
                            showSettingsModal = true
                        } label: {
                            menuRow(icon: "gearshape.fill", color: Color.gray, title: "Settings")
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        if !hasRemovedAds {
                            feedback.playTap()
                            showRemoveAdsModal = true
                        }
                    } label: {
                        Label(
                            hasRemovedAds ? "ADS REMOVED" : "REMOVE ADS",
                            systemImage: hasRemovedAds ? "checkmark.seal.fill" : "nosign"
                        )
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(hasRemovedAds ? Color(red: 0.18, green: 0.56, blue: 0.32) : secondaryTextColor.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(hasRemovedAds ? Color(red: 0.87, green: 0.95, blue: 0.90) : rowBackground)
                        .clipShape(Capsule())
                    }
                    .disabled(hasRemovedAds)

                    HStack(spacing: 32) {
                        bottomIconButton(
                            icon: "square.and.arrow.up",
                            accessibilityLabel: "Share Krank",
                            action: { showShareSheet = true }
                        )

                        bottomIconButton(
                            icon: "medal",
                            accessibilityLabel: "Rate Krank",
                            action: { rateApp() }
                        )

                        bottomIconButton(
                            icon: "questionmark.circle",
                            accessibilityLabel: "How to Play",
                            action: { showHowToPlayModal = true }
                        )
                    }
                    .padding(.bottom, 12)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)

                if showHowToPlayModal {
                    overlayColor
                        .ignoresSafeArea()
                        .onTapGesture {
                            feedback.playTap()
                            showHowToPlayModal = false
                        }

                    HowToPlayExplainerModal(
                        isDarkMode: darkModeEnabled,
                        onClose: { showHowToPlayModal = false }
                    )
                    .padding(.horizontal, 22)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                if showSettingsModal {
                    overlayColor
                        .ignoresSafeArea()
                        .onTapGesture {
                            feedback.playTap()
                            closeSettingsOverlay()
                        }

                    settingsModal
                        .padding(.horizontal, 22)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                if showUnlockLevelsModal {
                    overlayColor
                        .ignoresSafeArea()
                        .onTapGesture {
                            feedback.playTap()
                            showUnlockLevelsModal = false
                        }

                    UnlockLevelsOfferModal(
                        hasUnlockedBonusPacks: hasUnlockedBonusPacks,
                        purchaseButtonLabel: "Unlock More Levels - \(purchaseManager.displayPrice(for: .bonusPacks, fallback: "$4.99"))",
                        isProcessingPurchase: purchaseManager.isProcessing,
                        onClose: {
                            feedback.playTap()
                            showUnlockLevelsModal = false
                        },
                        onPurchase: {
                            purchaseBonusPacks()
                        },
                        onRestore: {
                            restoreBonusPacks()
                        },
                        onNoThanks: {
                            feedback.playTap()
                            showUnlockLevelsModal = false
                        }
                    )
                    .padding(.horizontal, 22)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }

                if showRemoveAdsModal {
                    overlayColor
                        .ignoresSafeArea()
                        .onTapGesture {
                            feedback.playTap()
                            showRemoveAdsModal = false
                        }

                    RemoveAdsOfferModal(
                        purchaseButtonLabel: "Remove Ads - \(purchaseManager.displayPrice(for: .removeAds, fallback: "$2.99"))",
                        isProcessingPurchase: purchaseManager.isProcessing,
                        onClose: {
                            feedback.playTap()
                            showRemoveAdsModal = false
                        },
                        onPurchase: {
                            purchaseRemoveAds()
                        },
                        onRestore: {
                            restoreRemoveAds()
                        },
                        onNoThanks: {
                            feedback.playTap()
                            showRemoveAdsModal = false
                        }
                    )
                    .padding(.horizontal, 22)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
            .navigationDestination(for: MainMenuRoute.self) { route in
                switch route {
                case .levelSelect:
                    LevelSelectView(automationConfig: automationConfig)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showUnlockLevelsModal)
            .animation(.easeInOut(duration: 0.18), value: showRemoveAdsModal)
            .animation(.easeInOut(duration: 0.18), value: showSettingsModal)
            .animation(.easeInOut(duration: 0.18), value: showHowToPlayModal)
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
            .alert("Store", isPresented: purchaseMessageBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseMessage ?? "")
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
            .onAppear {
                MonetizationManager.shared.configureIfNeeded()
                purchaseManager.configureIfNeeded()
                feedback.setScene(.mainMenu)
                feedback.refreshSettings()
                if automationConfig.autoPlay {
                    openLevelSelect()
                }
            }
        }
    }

    private var purchaseMessageBinding: Binding<Bool> {
        Binding(
            get: { purchaseMessage != nil },
            set: { newValue in
                if !newValue {
                    purchaseMessage = nil
                }
            }
        )
    }

    private func openLevelSelect() {
        guard path.isEmpty else { return }
        path.append(MainMenuRoute.levelSelect)
    }

    private func rateApp() {
        // iOS does not return the selected star value from the system rating flow.
        // Log the rate intent with a canonical 5-point scale when user opens review flow.
        MetaAppEventsManager.logRated(ratingValue: 5, maxRatingValue: 5, contentType: "game")

        if let reviewURL {
            openURL(reviewURL)
            return
        }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        AppStore.requestReview(in: scene)
    }

    private func purchaseBonusPacks() {
        Task {
            let result = await purchaseManager.purchase(.bonusPacks)
            switch result {
            case .success:
                feedback.playSuccess()
                showUnlockLevelsModal = false
            case .cancelled:
                break
            case .pending:
                feedback.playWarning()
                purchaseMessage = "Purchase is pending approval."
            case .failed(let message):
                feedback.playFailure()
                purchaseMessage = message
            }
        }
    }

    private func restoreBonusPacks() {
        Task {
            let result = await purchaseManager.restore(.bonusPacks)
            switch result {
            case .restored:
                feedback.playSuccess()
                showUnlockLevelsModal = false
            case .nothingToRestore:
                feedback.playWarning()
                purchaseMessage = "No previous bonus levels purchase was found for this Apple ID."
            case .failed(let message):
                feedback.playFailure()
                purchaseMessage = message
            }
        }
    }

    private func purchaseRemoveAds() {
        Task {
            let result = await purchaseManager.purchase(.removeAds)
            switch result {
            case .success:
                feedback.playSuccess()
                showRemoveAdsModal = false
            case .cancelled:
                break
            case .pending:
                feedback.playWarning()
                purchaseMessage = "Purchase is pending approval."
            case .failed(let message):
                feedback.playFailure()
                purchaseMessage = message
            }
        }
    }

    private func restoreRemoveAds() {
        Task {
            let result = await purchaseManager.restore(.removeAds)
            switch result {
            case .restored:
                feedback.playSuccess()
                showRemoveAdsModal = false
            case .nothingToRestore:
                feedback.playWarning()
                purchaseMessage = "No previous Remove Ads purchase was found for this Apple ID."
            case .failed(let message):
                feedback.playFailure()
                purchaseMessage = message
            }
        }
    }

    private var settingsModal: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsToggleRow(iconName: "moon.fill", title: "Dark Mode", isOn: $darkModeEnabled)
                Divider().overlay(dividerColor)
                settingsToggleRow(iconName: "iphone.radiowaves.left.and.right", title: "Haptic Feedback", isOn: $hapticsEnabled)
                Divider().overlay(dividerColor)
                settingsToggleRow(iconName: "speaker.wave.2.fill", title: "Sound Effects", isOn: $soundEnabled)
                Divider().overlay(dividerColor)
                settingsToggleRow(iconName: "music.note", title: "Music", isOn: $musicEnabled)
            }
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            settingsActionRow(iconName: "book.fill", title: "How to Play") {
                showSettingsModal = false
                showHowToPlayModal = true
            }

            Button {
                feedback.playTap()
                closeSettingsOverlay()
            } label: {
                Text("Close")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(BrandColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .background(modalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }

    private func closeSettingsOverlay() {
        showHowToPlayModal = false
        showSettingsModal = false
    }

    private func settingsToggleRow(iconName: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 32)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color(red: 0.15, green: 0.77, blue: 0.40))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .onChange(of: isOn.wrappedValue) { _, _ in
            feedback.refreshSettings()
            feedback.playSelection()
        }
    }

    private func settingsActionRow(iconName: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.playTap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 32)

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(secondaryTextColor.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func bottomIconButton(icon: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.playTap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(secondaryTextColor.opacity(0.76))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private func menuRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34)

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(primaryTextColor)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondaryTextColor.opacity(0.7))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct UnlockLevelsOfferModal: View {
    let hasUnlockedBonusPacks: Bool
    let purchaseButtonLabel: String
    let isProcessingPurchase: Bool
    let onClose: () -> Void
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onNoThanks: () -> Void

    @AppStorage("krank.setting.darkmode") private var darkModeEnabled = false

    private var primaryTextColor: Color {
        darkModeEnabled ? Color(red: 0.93, green: 0.95, blue: 0.98) : BrandColors.navy
    }

    private var secondaryTextColor: Color {
        darkModeEnabled ? Color(red: 0.63, green: 0.69, blue: 0.79) : BrandColors.navyMuted
    }

    private var modalBackground: Color {
        darkModeEnabled ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.99)
    }

    private var rowBackground: Color {
        darkModeEnabled ? Color(red: 0.17, green: 0.19, blue: 0.24) : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 40, height: 40)
                        .background(darkModeEnabled ? Color.white.opacity(0.10) : Color(red: 0.94, green: 0.95, blue: 0.97))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(rowBackground)
                    .frame(width: 110, height: 110)
                    .overlay(
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(secondaryTextColor)
                    )

                Circle()
                    .fill(Color(red: 0.95, green: 0.74, blue: 0.05))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .padding(.top, 6)

            Text("Unlock More Levels")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)

            Text("Get 2x more levels with bonus packs across every difficulty.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(secondaryTextColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 8)

            VStack(spacing: 8) {
                bundleBreakdownRow(text: "+50 Easy levels")
                bundleBreakdownRow(text: "+50 Medium levels")
                bundleBreakdownRow(text: "+50 Hard levels")
                bundleBreakdownRow(text: "+50 Extreme levels")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Button(action: onPurchase) {
                Text(hasUnlockedBonusPacks ? "Bonus Levels Unlocked" : purchaseButtonLabel)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(hasUnlockedBonusPacks ? Color(red: 0.16, green: 0.76, blue: 0.40) : BrandColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(hasUnlockedBonusPacks || isProcessingPurchase)
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Button(action: onRestore) {
                Text("RESTORE PURCHASES")
                    .font(.system(size: 14, weight: .black))
                    .tracking(1.4)
                    .foregroundStyle(secondaryTextColor)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(isProcessingPurchase)
            .padding(.horizontal, 24)
            .padding(.top, 6)

            Button(action: onNoThanks) {
                Text("No Thanks")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(secondaryTextColor.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(isProcessingPurchase)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Capsule()
                .fill(darkModeEnabled ? Color.white.opacity(0.14) : Color(red: 0.91, green: 0.93, blue: 0.95))
                .frame(width: 108, height: 6)
                .padding(.bottom, 14)
        }
        .background(modalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 26, x: 0, y: 16)
    }

    private func bundleBreakdownRow(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.16, green: 0.76, blue: 0.40))

            Text(text)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(primaryTextColor)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
