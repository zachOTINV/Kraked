import SwiftUI

private enum LevelTileState {
    case completed
    case current
    case available
    case locked
}

private struct PackDefinition: Identifiable {
    let id: Int
    let name: String
    let accent: Color
    let range: Range<Int>
    let isPremium: Bool
}

struct LevelSelectView: View {
    let automationConfig: AutomationConfig

    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = InAppPurchaseManager.shared
    private let feedback = FeedbackManager.shared
    @AppStorage("krank.iap.bonuspacks.unlocked") private var hasUnlockedBonusPacks = false
    @AppStorage("krank.setting.darkmode") private var darkModeEnabled = false

    @State private var levels: [Level] = []
    @State private var loadError: String?
    @State private var selectedPackID = 0
    @State private var completedLevels: Set<Int> = []
    @State private var selectedLevelIndex = 0
    @State private var showGame = false
    @State private var showUnlockLevelsModal = false
    @State private var pendingReturnToMainMenu = false
    @State private var didRunAutomation = false
    @State private var purchaseMessage: String?

    private let repository = LevelRepository()
    private let progressStore = LevelProgressStore.shared

    private let freePackNames = ["Easy", "Medium", "Hard", "Extreme"]
    private let levelsPerPack = 50
    private let packColors: [Color] = [
        Color(red: 0.19, green: 0.77, blue: 0.43),
        Color(red: 0.23, green: 0.49, blue: 0.91),
        Color(red: 0.96, green: 0.63, blue: 0.18),
        Color(red: 0.94, green: 0.26, blue: 0.28)
    ]

    private var freePackCount: Int {
        freePackNames.count
    }

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

    private var cardBackgroundSelected: Color {
        darkModeEnabled ? Color(red: 0.18, green: 0.21, blue: 0.26) : Color.white.opacity(0.82)
    }

    private var cardBackgroundUnselected: Color {
        darkModeEnabled ? Color(red: 0.15, green: 0.17, blue: 0.22) : Color.white.opacity(0.55)
    }

    private var headerButtonBackground: Color {
        darkModeEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.7)
    }

    private var overlayColor: Color {
        Color.black.opacity(darkModeEnabled ? 0.5 : 0.34)
    }

    private var unlockLevelsIconName: String {
        hasUnlockedBonusPacks ? "checkmark.seal.fill" : "square.stack.3d.up.fill"
    }

    private var unlockLevelsIconColor: Color {
        hasUnlockedBonusPacks
            ? Color(red: 0.16, green: 0.76, blue: 0.40)
            : Color(red: 0.95, green: 0.74, blue: 0.05)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [pageBackgroundStart, pageBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 20)

                packsScroller
                    .padding(.horizontal, 22)

                ScrollView(showsIndicators: false) {
                    levelGrid
                        .padding(.horizontal, 22)
                        .padding(.top, 2)
                        .padding(.bottom, 14)
                }
                .safeAreaPadding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
        }
        .onAppear {
            loadLevelsIfNeeded()
            refreshProgress()
            runAutomationIfNeeded()
            purchaseManager.configureIfNeeded()
            feedback.setScene(.levelSelect)
            feedback.refreshSettings()
        }
        .onChange(of: showGame) { _, isShowing in
            if !isShowing {
                refreshProgress()

                if pendingReturnToMainMenu {
                    pendingReturnToMainMenu = false
                    dismiss()
                    return
                }

                feedback.setScene(.levelSelect)
            }
        }
        .onChange(of: hasUnlockedBonusPacks) { _, _ in
            ensureSelectedPackIsPlayable()
        }
        .animation(.easeInOut(duration: 0.18), value: showUnlockLevelsModal)
        .preferredColorScheme(darkModeEnabled ? .dark : .light)
        .navigationBarBackButtonHidden(true)
        .alert("Store", isPresented: purchaseMessageBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseMessage ?? "")
        }
        .navigationDestination(isPresented: $showGame) {
            GameScreenView(
                initialLevelIndex: selectedLevelIndex,
                packName: selectedPack?.name,
                packRange: selectedPack?.range,
                automationConfig: automationConfig,
                onReturnToMainMenu: {
                    pendingReturnToMainMenu = true
                    showGame = false
                }
            )
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

    private var header: some View {
        HStack {
            Button {
                feedback.playTap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .frame(width: 54, height: 54)
                    .background(headerButtonBackground)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Select Level")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(primaryTextColor)

            Spacer()

            Button {
                feedback.playTap()
                showUnlockLevelsModal = true
            } label: {
                Image(systemName: unlockLevelsIconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(unlockLevelsIconColor)
                    .frame(width: 54, height: 54)
                    .background(headerButtonBackground)
                    .clipShape(Circle())
            }
        }
        .padding(.top, 4)
    }

    private var packsScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(packDefinitions) { pack in
                    packCard(for: pack)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func packCard(for pack: PackDefinition) -> some View {
        let selected = selectedPackID == pack.id
        let isPlayable = isPackPlayable(pack)
        let progress = packProgress(for: pack)

        return Button {
            guard isPlayable else { return }
            feedback.playSelection()
            selectedPackID = pack.id
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(String(format: "PACK %02d", pack.id + 1))
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle((selected ? pack.accent : secondaryTextColor).opacity(selected ? 1 : 0.62))

                    if pack.isPremium {
                        Text("BONUS")
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(Color(red: 0.95, green: 0.74, blue: 0.05))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(darkModeEnabled ? Color.white.opacity(0.10) : Color.white.opacity(0.75))
                            .clipShape(Capsule())
                    }
                }

                Text(pack.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle((selected ? primaryTextColor : secondaryTextColor).opacity(selected ? 1 : 0.7))

                Capsule()
                    .fill((darkModeEnabled ? Color.white.opacity(0.16) : Color(red: 0.83, green: 0.86, blue: 0.90)).opacity(selected ? 0.7 : 0.55))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(pack.accent)
                            .frame(width: max(0, 140 * progress))
                    }
                    .frame(height: 8)
            }
            .frame(width: 152, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(selected ? cardBackgroundSelected : cardBackgroundUnselected)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(selected ? pack.accent.opacity(0.55) : (darkModeEnabled ? Color.white.opacity(0.08) : .clear), lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if !isPlayable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(secondaryTextColor)
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .opacity(isPlayable ? 1 : 0.62)
        }
        .buttonStyle(.plain)
        .disabled(!isPlayable)
    }

    private var levelGrid: some View {
        VStack(spacing: 12) {
            if let error = loadError {
                Text(error)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }

            LazyVGrid(columns: [
                GridItem(.flexible(minimum: 90), spacing: 12),
                GridItem(.flexible(minimum: 90), spacing: 12),
                GridItem(.flexible(minimum: 90), spacing: 12)
            ], spacing: 12) {
                ForEach(gridLevelIndices, id: \.self) { index in
                    levelTile(for: index)
                }
            }
        }
    }

    private func levelTile(for levelIndex: Int) -> some View {
        let state = tileState(for: levelIndex)
        let number = levelNumberInSelectedPack(for: levelIndex)

        return Button {
            guard state != .locked else { return }
            feedback.playTap()
            selectedLevelIndex = levelIndex
            showGame = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(tileBackground(for: state))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(tileBorder(for: state), lineWidth: state == .current ? 3 : 2)
                    )

                VStack(spacing: 5) {
                    if state == .locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(darkModeEnabled ? secondaryTextColor.opacity(0.7) : Color(red: 0.78, green: 0.81, blue: 0.86))
                    }

                    Text("\(number)")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(tileNumberColor(for: state))

                    if state == .current {
                        Image(systemName: "play.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(darkModeEnabled ? secondaryTextColor : Color(red: 0.62, green: 0.69, blue: 0.80))
                    }
                }

                if state == .completed {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 27, weight: .bold))
                                .foregroundStyle(Color(red: 0.18, green: 0.77, blue: 0.41))
                        }
                        Spacer()
                    }
                    .padding(10)
                }
            }
            .frame(height: 128)
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
    }

    private func loadLevelsIfNeeded() {
        guard levels.isEmpty else { return }

        do {
            levels = try repository.loadLevels()
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }

        if selectedPackID >= packDefinitions.count {
            selectedPackID = 0
        }
        ensureSelectedPackIsPlayable()
    }

    private func refreshProgress() {
        completedLevels = progressStore.completedLevels()
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

    private func runAutomationIfNeeded() {
        guard automationConfig.autoPlay, !didRunAutomation else { return }
        didRunAutomation = true

        if let levelIndex = automationConfig.levelIndex, levels.indices.contains(levelIndex) {
            if let pack = packDefinitions.first(where: { $0.range.contains(levelIndex) }) {
                selectedPackID = pack.id
            }

            if !automationConfig.autoLevelSelectOnly {
                selectedLevelIndex = levelIndex
                showGame = true
            }
        }
    }

    private var packDefinitions: [PackDefinition] {
        let total = max(levels.count, 1)
        let count = max(Int(ceil(Double(total) / Double(levelsPerPack))), 1)

        return (0..<count).compactMap { index in
            let start = index * levelsPerPack
            let end = min(start + levelsPerPack, total)
            guard start < end else { return nil }

            let isPremium = index >= freePackCount
            let name: String
            if index < freePackNames.count {
                name = freePackNames[index]
            } else {
                let bonusIndex = index - freePackCount
                let difficultyName = freePackNames[bonusIndex % freePackNames.count]
                let cycle = (bonusIndex / freePackNames.count) + 1
                name = cycle == 1 ? "Bonus \(difficultyName)" : "Bonus \(difficultyName) \(cycle)"
            }

            return PackDefinition(
                id: index,
                name: name,
                accent: packColors[index % packColors.count],
                range: start..<end,
                isPremium: isPremium
            )
        }
    }

    private var selectedPack: PackDefinition? {
        packDefinitions.first { $0.id == selectedPackID } ?? packDefinitions.first
    }

    private var gridLevelIndices: [Int] {
        guard let selectedPack else { return [] }
        return Array(selectedPack.range)
    }

    private func levelNumberInSelectedPack(for globalIndex: Int) -> Int {
        guard let selectedPack else { return globalIndex + 1 }
        return (globalIndex - selectedPack.range.lowerBound) + 1
    }

    private func packProgress(for pack: PackDefinition) -> CGFloat {
        guard !pack.range.isEmpty else { return 0 }

        let completedCount = pack.range.reduce(0) { partial, index in
            partial + (completedLevels.contains(index) ? 1 : 0)
        }

        return CGFloat(completedCount) / CGFloat(pack.range.count)
    }

    private func tileState(for index: Int) -> LevelTileState {
        guard let selectedPack else { return .locked }
        guard isPackPlayable(selectedPack) else { return .locked }
        guard selectedPack.range.contains(index) else { return .locked }

        if completedLevels.contains(index) {
            return .completed
        }

        if index == firstIncompleteLevel(in: selectedPack) {
            return .current
        }

        return .locked
    }

    private func isPackPlayable(_ pack: PackDefinition) -> Bool {
        !pack.isPremium || hasUnlockedBonusPacks
    }

    private func firstIncompleteLevel(in pack: PackDefinition) -> Int {
        pack.range.first(where: { !completedLevels.contains($0) }) ?? pack.range.lowerBound
    }

    private func ensureSelectedPackIsPlayable() {
        guard let selected = packDefinitions.first(where: { $0.id == selectedPackID }),
              isPackPlayable(selected) else {
            selectedPackID = packDefinitions.first(where: isPackPlayable)?.id ?? 0
            return
        }
    }

    private func tileBackground(for state: LevelTileState) -> Color {
        if darkModeEnabled {
            switch state {
            case .completed:
                return Color(red: 0.17, green: 0.26, blue: 0.22)
            case .current:
                return Color(red: 0.21, green: 0.24, blue: 0.31)
            case .available:
                return Color(red: 0.19, green: 0.22, blue: 0.28)
            case .locked:
                return Color(red: 0.14, green: 0.16, blue: 0.20)
            }
        }

        switch state {
        case .completed:
            return Color(red: 0.84, green: 0.94, blue: 0.90)
        case .current:
            return Color.white.opacity(0.78)
        case .available:
            return Color.white.opacity(0.66)
        case .locked:
            return Color.white.opacity(0.34)
        }
    }

    private func tileBorder(for state: LevelTileState) -> Color {
        if darkModeEnabled {
            switch state {
            case .completed:
                return Color(red: 0.34, green: 0.66, blue: 0.50)
            case .current:
                return Color(red: 0.36, green: 0.43, blue: 0.58)
            case .available:
                return Color(red: 0.30, green: 0.36, blue: 0.49)
            case .locked:
                return Color.white.opacity(0.08)
            }
        }

        switch state {
        case .completed:
            return Color(red: 0.63, green: 0.88, blue: 0.76)
        case .current:
            return Color(red: 0.82, green: 0.85, blue: 0.90)
        case .available:
            return Color(red: 0.84, green: 0.87, blue: 0.91)
        case .locked:
            return Color(red: 0.86, green: 0.89, blue: 0.93).opacity(0.7)
        }
    }

    private func tileNumberColor(for state: LevelTileState) -> Color {
        if darkModeEnabled {
            switch state {
            case .completed:
                return Color(red: 0.36, green: 0.86, blue: 0.57)
            case .current:
                return primaryTextColor
            case .available:
                return Color(red: 0.70, green: 0.76, blue: 0.86)
            case .locked:
                return Color(red: 0.46, green: 0.51, blue: 0.61)
            }
        }

        switch state {
        case .completed:
            return Color(red: 0.26, green: 0.79, blue: 0.47)
        case .current:
            return primaryTextColor
        case .available:
            return Color(red: 0.34, green: 0.43, blue: 0.57)
        case .locked:
            return Color(red: 0.76, green: 0.80, blue: 0.86)
        }
    }

}
