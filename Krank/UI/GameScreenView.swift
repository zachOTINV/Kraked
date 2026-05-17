import SwiftUI

struct GameScreenView: View {
    let initialLevelIndex: Int?
    let packName: String?
    let packRange: Range<Int>?
    let automationConfig: AutomationConfig
    let onReturnToMainMenu: (() -> Void)?

    init(
        initialLevelIndex: Int? = nil,
        packName: String? = nil,
        packRange: Range<Int>? = nil,
        automationConfig: AutomationConfig = .disabled,
        onReturnToMainMenu: (() -> Void)? = nil
    ) {
        self.initialLevelIndex = initialLevelIndex
        self.packName = packName
        self.packRange = packRange
        self.automationConfig = automationConfig
        self.onReturnToMainMenu = onReturnToMainMenu
    }

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GameViewModel()
    @StateObject private var purchaseManager = InAppPurchaseManager.shared
    private let feedback = FeedbackManager.shared
    @State private var didRunAutomation = false
    @State private var didApplyInitialLevel = false
    @State private var crossedOutRuleIDs: Set<String> = []
    @State private var showSettingsModal = false
    @State private var pendingConfirmation: PendingConfirmationAction?
    @State private var validationFeedback: ValidationFeedback?
    @State private var showRemoveAdsModal = false
    @State private var showHowToPlayModal = false
    @State private var showHintAdPrompt = false
    @State private var isRequestingHintReward = false
    @State private var hintMessage: String?
    @State private var hintedSwitchID: String?
    @State private var hintPulseActive = false
    @State private var pendingWinInterstitial = false
    @State private var purchaseMessage: String?

    @AppStorage("krank.setting.sound") private var soundEnabled = true
    @AppStorage("krank.setting.haptics") private var hapticsEnabled = true
    @AppStorage("krank.setting.music") private var musicEnabled = true
    @AppStorage("krank.setting.darkmode") private var darkModeEnabled = false
    @AppStorage("krank.iap.removeads.unlocked") private var hasRemovedAds = false

    private let visibleRuleRows = 4
    private let ruleRowHeight: CGFloat = 72
    private let switchGridSpacing: CGFloat = 8

    private let switchColumns = [
        GridItem(.flexible(minimum: 140), spacing: 8),
        GridItem(.flexible(minimum: 140), spacing: 8)
    ]
    private static let ruleColorRegex = try! NSRegularExpression(
        pattern: "\\b(red|green|blue|gray|grey)\\b",
        options: [.caseInsensitive]
    )

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

    private var dividerColor: Color {
        darkModeEnabled ? Color.white.opacity(0.08) : Color(red: 0.87, green: 0.89, blue: 0.93)
    }

    private var cardBackground: Color {
        darkModeEnabled ? Color(red: 0.14, green: 0.16, blue: 0.20) : Color.white.opacity(0.74)
    }

    private var cardBackgroundStrong: Color {
        darkModeEnabled ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.99)
    }

    private var adsRemovedTextColor: Color {
        darkModeEnabled
            ? Color(red: 0.56, green: 0.82, blue: 0.66)
            : Color(red: 0.18, green: 0.56, blue: 0.32)
    }

    private var adsRemovedBackground: Color {
        darkModeEnabled
            ? Color(red: 0.18, green: 0.23, blue: 0.21)
            : Color(red: 0.89, green: 0.95, blue: 0.90)
    }

    private var adsRemovedStroke: Color {
        darkModeEnabled
            ? Color(red: 0.29, green: 0.42, blue: 0.35)
            : Color(red: 0.72, green: 0.85, blue: 0.76)
    }

    private var rowBackground: Color {
        darkModeEnabled ? Color(red: 0.17, green: 0.19, blue: 0.24) : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    private var subtlePillBackground: Color {
        darkModeEnabled ? Color.white.opacity(0.08) : Color.white.opacity(0.35)
    }

    private var circleButtonBackground: Color {
        darkModeEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.7)
    }

    private var settingsOverlayColor: Color {
        Color.black.opacity(darkModeEnabled ? 0.5 : 0.26)
    }

    private var switchLetterBackground: Color {
        darkModeEnabled ? Color(red: 0.21, green: 0.23, blue: 0.28) : Color.white.opacity(0.75)
    }

    private var switchStrokeColor: Color {
        darkModeEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.42)
    }

    private var isBlockingOverlayPresented: Bool {
        showSettingsModal || pendingConfirmation != nil || validationFeedback != nil || showRemoveAdsModal || showHowToPlayModal || showHintAdPrompt || isRequestingHintReward
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [pageBackgroundStart, pageBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    header
                    sectionLabel("RULES (\(currentRuleCount))")
                    rulesCard
                    sectionLabel("SWITCHES")
                    switchesArea
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }

            if let hintMessage {
                VStack {
                    Text(hintMessage)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.66))
                        .clipShape(Capsule())
                        .padding(.top, 58)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isRequestingHintReward {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)

                    Text("Opening hint ad...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if showHintAdPrompt {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .onTapGesture {
                        feedback.playTap()
                        showHintAdPrompt = false
                    }

                hintAdPromptModal
                    .padding(.horizontal, 20)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if showSettingsModal {
                settingsOverlayColor
                    .ignoresSafeArea()
                    .onTapGesture {
                        feedback.playTap()
                        closeSettingsOverlay()
                    }

                Group {
                    if showHowToPlayModal {
                        HowToPlayExplainerModal(
                            isDarkMode: darkModeEnabled,
                            onClose: { showHowToPlayModal = false }
                        )
                    } else if let action = pendingConfirmation {
                        confirmationModal(for: action)
                    } else {
                        settingsModal
                    }
                }
                .padding(.horizontal, 20)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if let feedback = validationFeedback {
                Group {
                    if feedback == .success {
                        Color(red: 0.48, green: 0.63, blue: 0.56).opacity(0.56)
                    } else {
                        Color.black.opacity(0.20)
                    }
                }
                    .ignoresSafeArea()

                Group {
                    if feedback == .success {
                        winModal
                    } else {
                        validationModal(for: feedback)
                    }
                }
                    .padding(.horizontal, 20)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if showRemoveAdsModal {
                Color.black.opacity(0.34)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            validateButton
                .opacity(isBlockingOverlayPresented ? 0.42 : 1)
                .saturation(isBlockingOverlayPresented ? 0.2 : 1)
                .overlay {
                    if isBlockingOverlayPresented {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(darkModeEnabled ? Color.black.opacity(0.30) : Color.white.opacity(0.22))
                    }
                }
                .allowsHitTesting(!isBlockingOverlayPresented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .onAppear {
            MonetizationManager.shared.configureIfNeeded()
            purchaseManager.configureIfNeeded()
            feedback.setScene(.gameplay)
            feedback.refreshSettings()
            if viewModel.levels.isEmpty {
                viewModel.loadLevels()
            }
            applyInitialLevelIfNeeded()
            runAutomationIfNeeded()
        }
        .onChange(of: soundEnabled) { _, _ in
            feedback.refreshSettings()
        }
        .onChange(of: hapticsEnabled) { _, _ in
            feedback.refreshSettings()
        }
        .onChange(of: musicEnabled) { _, _ in
            feedback.refreshSettings()
        }
        .onChange(of: viewModel.currentLevel?.id) { _, _ in
            crossedOutRuleIDs.removeAll()
            validationFeedback = nil
            hintMessage = nil
            hintedSwitchID = nil
            hintPulseActive = false
            pendingWinInterstitial = false
        }
        .animation(.easeInOut(duration: 0.18), value: pendingConfirmation)
        .animation(.easeInOut(duration: 0.18), value: validationFeedback)
        .animation(.easeInOut(duration: 0.18), value: showHintAdPrompt)
        .animation(.easeInOut(duration: 0.18), value: showRemoveAdsModal)
        .animation(.easeInOut(duration: 0.18), value: hintMessage)
        .animation(.easeInOut(duration: 0.18), value: isRequestingHintReward)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .navigationBarBackButtonHidden(true)
        .alert("Store", isPresented: purchaseMessageBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseMessage ?? "")
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

    private func applyInitialLevelIfNeeded() {
        guard !didApplyInitialLevel else { return }
        didApplyInitialLevel = true

        guard let initialLevelIndex else { return }
        guard viewModel.levels.indices.contains(initialLevelIndex) else { return }
        viewModel.startLevel(at: initialLevelIndex)
    }

    private func runAutomationIfNeeded() {
        guard automationConfig.isEnabled, !didRunAutomation else { return }
        didRunAutomation = true

        Task { @MainActor in
            await pause(seconds: automationConfig.settleDelay)

            if let levelIndex = automationConfig.levelIndex {
                viewModel.startLevel(at: levelIndex)
                await pause(seconds: automationConfig.actionDelay)
            }

            if automationConfig.autoReset {
                viewModel.restartLevel()
                await pause(seconds: automationConfig.actionDelay)
            }

            for switchID in automationConfig.toggleSequence {
                viewModel.toggleSwitch(switchID)
                await pause(seconds: automationConfig.actionDelay)
            }

            if automationConfig.autoOpenSettings {
                showSettingsModal = true
            }

            if automationConfig.autoNext {
                viewModel.goToNextLevel()
            }
        }
    }

    private func pause(seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                feedback.playTap()
                showHintAdPrompt = true
            } label: {
                Image(systemName: "lightbulb.max.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 40, height: 40)
                    .background(circleButtonBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isBlockingOverlayPresented || validationFeedback == .success)
            .opacity((isBlockingOverlayPresented || validationFeedback == .success) ? 0.45 : 1)

            Spacer()

            VStack(spacing: 6) {
                Text(displayLevelTitle)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Text("GUESSES: \(viewModel.guessesCount)")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(secondaryTextColor.opacity(0.8))
            }

            Spacer()

            Button {
                feedback.playTap()
                showSettingsModal = true
                pendingConfirmation = nil
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 40, height: 40)
                    .background(circleButtonBackground)
                    .clipShape(Circle())
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
                settingsToggleRow(
                    iconName: "moon.fill",
                    title: "Dark Mode",
                    isOn: $darkModeEnabled
                )

                Divider()
                    .overlay(dividerColor)

                settingsToggleRow(
                    iconName: "iphone.radiowaves.left.and.right",
                    title: "Haptic Feedback",
                    isOn: $hapticsEnabled
                )

                Divider()
                    .overlay(dividerColor)

                settingsToggleRow(
                    iconName: "speaker.wave.2.fill",
                    title: "Sound Effects",
                    isOn: $soundEnabled
                )

                Divider()
                    .overlay(dividerColor)

                settingsToggleRow(
                    iconName: "music.note",
                    title: "Music",
                    isOn: $musicEnabled
                )
            }
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 10) {
                settingsActionRow(iconName: "book.fill", title: "How to Play") {
                    showHowToPlayModal = true
                }

                settingsActionRow(iconName: "arrow.counterclockwise", title: "Restart Level") {
                    pendingConfirmation = .restart
                }

                settingsActionRow(iconName: "rectangle.portrait.and.arrow.right", title: "Quit to Menu") {
                    pendingConfirmation = .quit
                }
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
        .background(cardBackgroundStrong)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 12)
    }

    private func confirmationModal(for action: PendingConfirmationAction) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Are you sure?")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    feedback.playTap()
                    pendingConfirmation = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 28, height: 28)
                        .background(circleButtonBackground)
                        .clipShape(Circle())
                }
            }

            Text(action.message)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    feedback.playTap()
                    pendingConfirmation = nil
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(rowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    feedback.playTap()
                    performConfirmedAction(action)
                } label: {
                    Text(action.confirmLabel)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.84, green: 0.20, blue: 0.24))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackgroundStrong)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
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

    private func performConfirmedAction(_ action: PendingConfirmationAction) {
        switch action {
        case .restart:
            viewModel.restartLevel()
            crossedOutRuleIDs.removeAll()
            closeSettingsOverlay()

        case .quit:
            closeSettingsOverlay()
            dismiss()
        }
    }

    private func closeSettingsOverlay() {
        pendingConfirmation = nil
        showHowToPlayModal = false
        showSettingsModal = false
    }

    private var hintAdPromptModal: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Need a Hint?")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Spacer()

                Button {
                    feedback.playTap()
                    showHintAdPrompt = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 28, height: 28)
                        .background(circleButtonBackground)
                        .clipShape(Circle())
                }
            }

            Text("Watch an ad to reveal one correct switch color for this level.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    feedback.playTap()
                    showHintAdPrompt = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(rowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    feedback.playTap()
                    showHintAdPrompt = false
                    Task { @MainActor in
                        await pause(seconds: 0.06)
                        requestHint()
                    }
                } label: {
                    Text("Watch Ad")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(BrandColors.navy)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackgroundStrong)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black))
            .tracking(2.1)
            .foregroundStyle(secondaryTextColor)
            .padding(.leading, 3)
    }

    private var currentRuleCount: Int {
        viewModel.currentLevel?.rules.count ?? 0
    }

    private var rulesCard: some View {
        let fixedHeight = (ruleRowHeight * CGFloat(visibleRuleRows)) + CGFloat(max(0, visibleRuleRows - 1))

        return Group {
            if let error = viewModel.loadError {
                Text(error)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else if let level = viewModel.currentLevel {
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 0) {
                        ForEach(Array(level.rules.enumerated()), id: \.element.id) { index, rule in
                            Button {
                                toggleRuleCrossOut(ruleID: rule.id)
                            } label: {
                                ruleRow(
                                    rule: rule,
                                    isCrossedOut: crossedOutRuleIDs.contains(rule.id)
                                )
                            }
                            .buttonStyle(.plain)

                            if index < level.rules.count - 1 {
                                Divider()
                                    .overlay(dividerColor)
                            }
                        }
                    }
                }
                .frame(height: fixedHeight)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            } else {
                Text("Loading level...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private func ruleRow(rule: LevelRule, isCrossedOut: Bool) -> some View {
        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: isCrossedOut ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isCrossedOut ? Color(red: 0.59, green: 0.86, blue: 0.70) : secondaryTextColor.opacity(0.55))

            Text(styledRuleDisplay(rule.display))
                .font(.system(size: 15, weight: .semibold))
                .strikethrough(isCrossedOut, color: secondaryTextColor.opacity(0.6))
                .opacity(isCrossedOut ? 0.55 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(rule.id.uppercased())
                .font(.system(size: 10, weight: .black))
                .tracking(0.8)
                .foregroundStyle(secondaryTextColor.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(subtlePillBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minHeight: ruleRowHeight, alignment: .center)
        .contentShape(Rectangle())
    }

    private func toggleRuleCrossOut(ruleID: String) {
        feedback.playSelection()
        if crossedOutRuleIDs.contains(ruleID) {
            crossedOutRuleIDs.remove(ruleID)
        } else {
            crossedOutRuleIDs.insert(ruleID)
        }
    }

    private func styledRuleDisplay(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = primaryTextColor

        let matches = Self.ruleColorRegex.matches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        )

        for match in matches {
            guard let swiftRange = Range(match.range, in: text),
                  let attributedRange = Range(swiftRange, in: attributed) else {
                continue
            }

            let token = String(text[swiftRange]).lowercased()
            attributed[attributedRange].foregroundColor = ruleColor(for: token)
        }

        return attributed
    }

    private func ruleColor(for token: String) -> Color {
        switch token {
        case "red":
            return Color(red: 0.94, green: 0.26, blue: 0.28)
        case "green":
            return Color(red: 0.16, green: 0.76, blue: 0.36)
        case "blue":
            return Color(red: 0.24, green: 0.49, blue: 0.89)
        case "gray", "grey":
            return Color(red: 0.48, green: 0.53, blue: 0.63)
        default:
            return primaryTextColor
        }
    }

    private var switchesArea: some View {
        GeometryReader { proxy in
            if let level = viewModel.currentLevel {
                let rows = max(1, Int(ceil(Double(level.switches.count) / 2.0)))
                let totalSpacing = switchGridSpacing * CGFloat(max(0, rows - 1))
                let rawHeight = (proxy.size.height - totalSpacing) / CGFloat(rows)
                let cellHeight = max(36, min(58, rawHeight))

                LazyVGrid(columns: switchColumns, spacing: switchGridSpacing) {
                    ForEach(level.switches, id: \.self) { switchID in
                        switchCard(switchID: switchID, height: cellHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func switchCard(switchID: String, height: CGFloat) -> some View {
        let color = viewModel.switchStates[switchID] ?? .gray
        let leftWidth = max(38, min(46, height * 0.82))
        let letterSize = max(16, min(22, height * 0.36))
        let textSize = max(12, min(15, height * 0.27))
        let iconSize = max(12, min(15, height * 0.27))
        let isHinted = hintedSwitchID == switchID

        return Button {
            feedback.playSwitchFlip()
            viewModel.toggleSwitch(switchID)
        } label: {
            HStack(spacing: 0) {
                Text(switchID)
                    .font(.system(size: letterSize, weight: .black))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: leftWidth, height: height)
                    .background(switchLetterBackground)

                HStack(spacing: 6) {
                    Text(color.displayName)
                        .font(.system(size: textSize, weight: .black))
                        .tracking(0.4)

                    Spacer(minLength: 2)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: iconSize, weight: .bold))
                }
                .padding(.horizontal, 12)
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .foregroundStyle(switchTextColor(for: color))
                .background(switchBackground(for: color))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isHinted ? Color(red: 0.98, green: 0.86, blue: 0.24) : switchStrokeColor, lineWidth: isHinted ? 2.2 : 1)
            )
            .shadow(
                color: isHinted ? Color(red: 0.98, green: 0.86, blue: 0.24).opacity(0.45) : .clear,
                radius: isHinted ? (hintPulseActive ? 12 : 7) : 0,
                x: 0,
                y: 0
            )
            .scaleEffect(isHinted ? (hintPulseActive ? 1.03 : 1.0) : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var validateButton: some View {
        Button {
            let solved = viewModel.validateCurrentState()
            if solved {
                feedback.playSuccess()
                LevelProgressStore.shared.markCompleted(levelIndex: viewModel.currentLevelIndex)
                pendingWinInterstitial = MonetizationManager.shared.registerLevelClearAndShouldShowInterstitial(
                    hasRemovedAds: hasRemovedAds
                )
                validationFeedback = .success
            } else {
                feedback.playFailure()
                validationFeedback = .failure
            }
        } label: {
            HStack(spacing: 10) {
                Text("Validate Solution")
                    .font(.system(size: 17, weight: .heavy))

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(BrandColors.navy)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func validationModal(for result: ValidationFeedback) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(result.title)
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(primaryTextColor)

                Spacer()
            }

            Text(result.message)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                feedback.playTap()
                validationFeedback = nil
            } label: {
                Text("Keep Trying")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(BrandColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackgroundStrong)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 20, x: 0, y: 10)
    }

    private var winModal: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.78, blue: 0.40))
                    .frame(width: 84, height: 84)
                    .shadow(color: Color(red: 0.15, green: 0.78, blue: 0.40).opacity(0.35), radius: 12, x: 0, y: 5)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 34)
            .padding(.bottom, 18)

            Text("Perfect!")
                .font(.system(size: 50, weight: .black))
                .foregroundStyle(primaryTextColor)

            Text("Level Cleared")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(secondaryTextColor.opacity(0.82))
                .padding(.top, 4)

            Divider()
                .overlay(dividerColor)
                .padding(.horizontal, 24)
                .padding(.top, 26)

            HStack(spacing: 0) {
                winStat(label: "LEVEL", value: "\(displayLevelNumber)")

                Rectangle()
                    .fill(dividerColor)
                    .frame(width: 1, height: 64)
                    .padding(.horizontal, 24)

                winStat(label: "GUESSES", value: "\(viewModel.guessesCount)")
            }
            .padding(.top, 22)

            Button {
                feedback.playTap()
                proceedFromSuccessModal()
            } label: {
                HStack(spacing: 10) {
                    Text(successPrimaryButtonLabel)
                        .font(.system(size: 19, weight: .heavy))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 19, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(red: 0.15, green: 0.78, blue: 0.40))
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .shadow(color: Color(red: 0.15, green: 0.78, blue: 0.40).opacity(0.26), radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 28)

            Button {
                if !hasRemovedAds {
                    feedback.playTap()
                    showRemoveAdsModal = true
                }
            } label: {
                Label(hasRemovedAds ? "Ads Removed" : "Remove Ads", systemImage: hasRemovedAds ? "checkmark.seal.fill" : "nosign")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(hasRemovedAds ? adsRemovedTextColor : Color(red: 0.89, green: 0.68, blue: 0.05))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasRemovedAds ? adsRemovedBackground : Color(red: 0.99, green: 0.96, blue: 0.87))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(hasRemovedAds ? adsRemovedStroke : Color(red: 0.95, green: 0.85, blue: 0.53), lineWidth: 1.3)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(hasRemovedAds)
            .padding(.horizontal, 24)
            .padding(.top, 14)

            Divider()
                .overlay(Color(red: 0.89, green: 0.91, blue: 0.94))
                .padding(.horizontal, 24)
                .padding(.top, 20)

            HStack(spacing: 12) {
                winActionButton(
                    title: "Level Select",
                    iconName: "square.grid.2x2.fill",
                    action: returnToLevelSelect
                )
                winActionButton(
                    title: "Main Menu",
                    iconName: "house.fill",
                    action: returnToMainMenu
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .background(cardBackgroundStrong)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(darkModeEnabled ? Color.white.opacity(0.12) : Color.white.opacity(0.88), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.17), radius: 22, x: 0, y: 12)
    }

    private func winStat(label: String, value: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 16, weight: .black))
                .tracking(1.6)
                .foregroundStyle(secondaryTextColor.opacity(0.75))

            Text(value)
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(primaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }

    private func winActionButton(title: String, iconName: String, action: @escaping () -> Void) -> some View {
        Button {
            feedback.playTap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(secondaryTextColor)

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func requestHint() {
        guard !isBlockingOverlayPresented else { return }

        isRequestingHintReward = true
        MonetizationManager.shared.showRewardedHintAd { rewarded in
            isRequestingHintReward = false

            guard rewarded else {
                feedback.playWarning()
                showHintMessage("Hint ad was not completed. Try again.")
                return
            }

            switch viewModel.applyHintFromSolution() {
            case .applied(let switchID, let color):
                feedback.playHint()
                animateHintSwitch(switchID)
                showHintMessage("Hint: Set \(switchID) to \(color.displayName).")
            case .alreadySolved:
                feedback.playWarning()
                showHintMessage("This level is already solved.")
            case .noChangeNeeded:
                feedback.playWarning()
                showHintMessage("Your switches already match a valid solution.")
            case .unavailable:
                feedback.playFailure()
                showHintMessage("No hint available for this level.")
            }
        }
    }

    private func animateHintSwitch(_ switchID: String) {
        hintedSwitchID = switchID
        hintPulseActive = false

        withAnimation(.easeInOut(duration: 0.24).repeatCount(4, autoreverses: true)) {
            hintPulseActive = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard hintedSwitchID == switchID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                hintPulseActive = false
                hintedSwitchID = nil
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

    private func showHintMessage(_ message: String) {
        withAnimation(.easeInOut(duration: 0.16)) {
            hintMessage = message
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            guard hintMessage == message else { return }

            withAnimation(.easeInOut(duration: 0.16)) {
                hintMessage = nil
            }
        }
    }

    private var displayLevelTitle: String {
        guard let packName, let packRange, packRange.contains(viewModel.currentLevelIndex) else {
            return "Level \(viewModel.currentLevelIndex + 1)"
        }

        let levelInPack = (viewModel.currentLevelIndex - packRange.lowerBound) + 1
        return "\(packName) - \(levelInPack)"
    }

    private var displayLevelNumber: Int {
        guard let packRange, packRange.contains(viewModel.currentLevelIndex) else {
            return viewModel.currentLevelIndex + 1
        }

        return (viewModel.currentLevelIndex - packRange.lowerBound) + 1
    }

    private var successPrimaryButtonLabel: String {
        hasNextLevelInCurrentPack ? "Next Level" : "Back to Packs"
    }

    private var hasNextLevelInCurrentPack: Bool {
        let nextIndex = viewModel.currentLevelIndex + 1
        guard viewModel.levels.indices.contains(nextIndex) else { return false }

        if let packRange {
            return nextIndex < packRange.upperBound
        }

        return true
    }

    private func proceedFromSuccessModal() {
        performWinModalAction {
            if hasNextLevelInCurrentPack {
                viewModel.goToNextLevel()
            } else {
                dismiss()
            }
        }
    }

    private func returnToLevelSelect() {
        performWinModalAction {
            dismiss()
        }
    }

    private func returnToMainMenu() {
        performWinModalAction {
            if let onReturnToMainMenu {
                onReturnToMainMenu()
                return
            }
            dismiss()
        }
    }

    private func performWinModalAction(_ action: @escaping () -> Void) {
        validationFeedback = nil

        let shouldShowInterstitial = pendingWinInterstitial && !hasRemovedAds
        pendingWinInterstitial = false

        guard shouldShowInterstitial else {
            action()
            return
        }

        MonetizationManager.shared.showInterstitialIfAvailable {
            action()
        }
    }

    private func switchBackground(for color: GameColor) -> Color {
        switch color {
        case .red:
            return Color(red: 0.94, green: 0.26, blue: 0.28)
        case .green:
            return Color(red: 0.16, green: 0.76, blue: 0.36)
        case .blue:
            return Color(red: 0.24, green: 0.49, blue: 0.89)
        case .gray:
            return darkModeEnabled
                ? Color(red: 0.36, green: 0.40, blue: 0.49)
                : Color(red: 0.72, green: 0.76, blue: 0.83)
        }
    }

    private func switchTextColor(for color: GameColor) -> Color {
        switch color {
        case .gray:
            return primaryTextColor
        case .red, .green, .blue:
            return .white
        }
    }
}

struct RemoveAdsOfferModal: View {
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
                        Image(systemName: "nosign")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundStyle(secondaryTextColor)
                    )

                Circle()
                    .fill(Color(red: 0.16, green: 0.76, blue: 0.40))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    )
            }
            .padding(.top, 6)

            Text("Remove Ads")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(primaryTextColor)
                .padding(.top, 20)

            Text("Enjoy a seamless experience with no interruptions and support the game.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(secondaryTextColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.top, 12)

            Button(action: onPurchase) {
                Text(purchaseButtonLabel)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(BrandColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isProcessingPurchase)
            .padding(.horizontal, 24)
            .padding(.top, 30)

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
}

struct HowToPlayExplainerModal: View {
    let isDarkMode: Bool
    let onClose: () -> Void

    private var primaryTextColor: Color {
        isDarkMode ? Color(red: 0.93, green: 0.95, blue: 0.98) : BrandColors.navy
    }

    private var secondaryTextColor: Color {
        isDarkMode ? Color(red: 0.63, green: 0.69, blue: 0.79) : BrandColors.navyMuted
    }

    private var modalBackground: Color {
        isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color.white.opacity(0.99)
    }

    private var rowBackground: Color {
        isDarkMode ? Color(red: 0.17, green: 0.19, blue: 0.24) : Color(red: 0.95, green: 0.96, blue: 0.98)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 30, height: 30)
                        .background(isDarkMode ? Color.white.opacity(0.10) : Color.white.opacity(0.8))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.77, blue: 0.40))
                        .frame(width: 44, height: 44)

                    Image(systemName: "book.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("How To Play")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(primaryTextColor)

                    Text("Use logic, then validate.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                }
            }

            VStack(spacing: 9) {
                howToStep(icon: "arrow.triangle.2.circlepath", title: "Flip switches", detail: "Tap a switch to rotate colors: Gray, Red, Green, Blue.")
                howToStep(icon: "circle.fill", title: "Gray is planning-only", detail: "Gray helps you think but cannot be part of a valid final answer.")
                howToStep(icon: "lightbulb.max.fill", title: "Need a hint?", detail: "Tap the lightbulb to watch an ad and reveal one correct switch color.")
                howToStep(icon: "list.bullet.rectangle", title: "Satisfy every rule", detail: "All listed rules must be true at the same time.")
                howToStep(icon: "checkmark.seal.fill", title: "Tap Validate Solution", detail: "You only clear the level when you validate a correct state.")
            }

            Button(action: onClose) {
                Text("Got it")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BrandColors.navy)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(18)
        .background(modalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isDarkMode ? Color.white.opacity(0.12) : Color.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 22, x: 0, y: 12)
    }

    private func howToStep(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(primaryTextColor)

                Text(detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum PendingConfirmationAction: Int, Identifiable {
    case restart
    case quit

    var id: Int { rawValue }

    var message: String {
        switch self {
        case .restart:
            return "Restart this level? Your current switch choices and crossed-out rules will be reset."
        case .quit:
            return "Quit to level select? Your current switch choices in this level will be lost."
        }
    }

    var confirmLabel: String {
        switch self {
        case .restart:
            return "Restart"
        case .quit:
            return "Quit"
        }
    }
}

private enum ValidationFeedback: Int, Identifiable {
    case success
    case failure

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .success:
            return "Correct"
        case .failure:
            return "Not Quite"
        }
    }

    var message: String {
        switch self {
        case .success:
            return "Nice solve. Continue to the next level when you're ready."
        case .failure:
            return "That solution doesn't satisfy all rules yet. Adjust your switches and validate again."
        }
    }
}
