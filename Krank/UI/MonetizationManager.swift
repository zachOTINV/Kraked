import Foundation
import UIKit
import StoreKit
import Combine

#if canImport(IronSource)
import IronSource
#endif

@MainActor
final class InAppPurchaseManager: ObservableObject {
    static let shared = InAppPurchaseManager()

    enum ProductType: CaseIterable {
        case removeAds
        case bonusPacks

        var productID: String {
            switch self {
            case .removeAds:
                return "otinv.Krank.remove_ads"
            case .bonusPacks:
                return "otinv.Krank.unlock_more_levels"
            }
        }

        var unlockStorageKey: String {
            switch self {
            case .removeAds:
                return "krank.iap.removeads.unlocked"
            case .bonusPacks:
                return "krank.iap.bonuspacks.unlocked"
            }
        }
    }

    enum PurchaseResult {
        case success
        case cancelled
        case pending
        case failed(String)
    }

    enum RestoreResult {
        case restored
        case nothingToRestore
        case failed(String)
    }

    @Published private(set) var isProcessing = false
    @Published private(set) var productsByID: [String: Product] = [:]

    private let defaults: UserDefaults
    private var didConfigure = false
    private var updatesTask: Task<Void, Never>?

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        updatesTask = observeTransactionUpdates()

        Task {
            await loadProducts()
            _ = await refreshEntitlements()
        }
    }

    func isUnlocked(_ productType: ProductType) -> Bool {
        defaults.bool(forKey: productType.unlockStorageKey)
    }

    func displayPrice(for productType: ProductType, fallback: String) -> String {
        productsByID[productType.productID]?.displayPrice ?? fallback
    }

    func purchase(_ productType: ProductType) async -> PurchaseResult {
        configureIfNeeded()

        guard !isUnlocked(productType) else {
            return .success
        }

        guard !isProcessing else {
            return .pending
        }

        isProcessing = true
        defer { isProcessing = false }

        if productsByID[productType.productID] == nil {
            await loadProducts()
        }

        guard let product = productsByID[productType.productID] else {
            return .failed("This purchase is currently unavailable. Please try again.")
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(from: verification)
                applyEntitlement(for: transaction.productID, isUnlocked: transaction.revocationDate == nil)
                await transaction.finish()
                return .success
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("Purchase could not be completed.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restore(_ productType: ProductType) async -> RestoreResult {
        configureIfNeeded()

        guard !isProcessing else {
            return .failed("A purchase action is already in progress.")
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
            let activeIDs = await refreshEntitlements()

            if activeIDs.contains(productType.productID) {
                return .restored
            }
            return .nothingToRestore
        } catch {
            return .failed("Restore failed. Please try again.")
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handleTransactionUpdate(update)
            }
        }
    }

    private func handleTransactionUpdate(_ verification: VerificationResult<Transaction>) async {
        guard let transaction = try? verifiedTransaction(from: verification) else {
            return
        }

        applyEntitlement(for: transaction.productID, isUnlocked: transaction.revocationDate == nil)
        await transaction.finish()
    }

    private func loadProducts() async {
        do {
            let productIDs = ProductType.allCases.map(\.productID)
            let products = try await Product.products(for: productIDs)
            productsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch {
            productsByID = [:]
        }
    }

    private func refreshEntitlements() async -> Set<String> {
        var activeProductIDs: Set<String> = []

        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: entitlement),
                  transaction.revocationDate == nil else {
                continue
            }

            activeProductIDs.insert(transaction.productID)
        }

        for productType in ProductType.allCases {
            applyEntitlement(
                for: productType.productID,
                isUnlocked: activeProductIDs.contains(productType.productID)
            )
        }

        return activeProductIDs
    }

    private func applyEntitlement(for productID: String, isUnlocked: Bool) {
        guard let productType = ProductType.allCases.first(where: { $0.productID == productID }) else {
            return
        }
        defaults.set(isUnlocked, forKey: productType.unlockStorageKey)
    }

    private func verifiedTransaction(from verification: VerificationResult<Transaction>) throws -> Transaction {
        switch verification {
        case .verified(let transaction):
            return transaction
        case .unverified:
            throw InAppPurchaseError.unverifiedTransaction
        }
    }
}

private enum InAppPurchaseError: LocalizedError {
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .unverifiedTransaction:
            return "The App Store could not verify this purchase."
        }
    }
}

@MainActor
final class MonetizationManager {
    static let shared = MonetizationManager()

    private enum StorageKeys {
        static let levelClearCount = "krank.ads.level_clear_count"
    }

    private let interstitialFrequency = 2
    private let defaults: UserDefaults
    private let provider: AdProvider
    private var didConfigure = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        #if canImport(IronSource)
        self.provider = LevelPlayAdProvider()
        #else
        self.provider = NoopAdProvider()
        #endif
    }

    func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        Task { @MainActor in
            await TrackingPermissionManager.shared.requestIfNeeded()
            provider.configure()
            provider.preloadInterstitial()
            provider.preloadRewarded()
        }
    }

    func registerLevelClearAndShouldShowInterstitial(hasRemovedAds: Bool) -> Bool {
        let nextCount = defaults.integer(forKey: StorageKeys.levelClearCount) + 1
        defaults.set(nextCount, forKey: StorageKeys.levelClearCount)

        guard !hasRemovedAds else { return false }
        return nextCount.isMultiple(of: interstitialFrequency)
    }

    func showInterstitialIfAvailable(completion: @escaping () -> Void) {
        configureIfNeeded()

        guard provider.isInterstitialReady, let viewController = topViewController() else {
            provider.preloadInterstitial()
            completion()
            return
        }

        provider.showInterstitial(from: viewController) { [weak self] in
            Task { @MainActor in
                self?.provider.preloadInterstitial()
                completion()
            }
        }
    }

    func showRewardedHintAd(completion: @escaping (Bool) -> Void) {
        configureIfNeeded()
        if attemptShowRewardedHintAd(completion: completion) {
            return
        }

        provider.preloadRewarded()
        Task { @MainActor in
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if attemptShowRewardedHintAd(completion: completion) {
                    return
                }
            }
            completion(false)
        }
    }

    private func attemptShowRewardedHintAd(completion: @escaping (Bool) -> Void) -> Bool {
        guard provider.isRewardedReady, let viewController = topViewController() else {
            return false
        }

        provider.showRewarded(from: viewController) { [weak self] rewarded in
            Task { @MainActor in
                self?.provider.preloadRewarded()
                completion(rewarded)
            }
        }
        return true
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseController: UIViewController?
        if let base {
            baseController = base
        } else {
            baseController = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }

        if let navigation = baseController as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }

        if let tab = baseController as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }

        if let presented = baseController?.presentedViewController {
            return topViewController(base: presented)
        }

        return baseController
    }
}

private protocol AdProvider: AnyObject {
    var isInterstitialReady: Bool { get }
    var isRewardedReady: Bool { get }

    func configure()
    func preloadInterstitial()
    func preloadRewarded()
    func showInterstitial(from viewController: UIViewController, completion: @escaping () -> Void)
    func showRewarded(from viewController: UIViewController, completion: @escaping (Bool) -> Void)
}

private class NoopAdProvider: AdProvider {
    var isInterstitialReady: Bool { true }
    var isRewardedReady: Bool { true }

    func configure() {}

    func preloadInterstitial() {}

    func preloadRewarded() {}

    func showInterstitial(from viewController: UIViewController, completion: @escaping () -> Void) {
        completion()
    }

    func showRewarded(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        completion(true)
    }
}

#if canImport(IronSource)
private final class LevelPlayAdProvider: NSObject, AdProvider {
    private enum Credentials {
        static let appKey = "2566589c5"
        static let interstitialAdUnitID = "xwp15olfcsam9nv5"
        static let rewardedAdUnitID = "q5wh0yqydd648vvw"
    }

    var isInterstitialReady: Bool {
        interstitialReady && isInitialized
    }

    var isRewardedReady: Bool {
        rewardedReady && isInitialized
    }

    private var isInitialized = false
    private var isInitializing = false

    private var interstitialReady = false
    private var rewardedReady = false

    private var interstitialAd: LPMInterstitialAd?
    private var rewardedAd: LPMRewardedAd?

    private var interstitialDelegateProxy: InterstitialDelegateProxy?
    private var rewardedDelegateProxy: RewardedDelegateProxy?

    private var pendingInitActions: [() -> Void] = []

    private var pendingInterstitialCompletion: (() -> Void)?
    private var pendingRewardedCompletion: ((Bool) -> Void)?
    private var rewardedGrantReceived = false
    private var rewardedWasDisplayed = false
    private var rewardedCloseFallbackWorkItem: DispatchWorkItem?

    func configure() {
        initializeIfNeeded()
    }

    func preloadInterstitial() {
        performAfterInitialization { [weak self] in
            guard let self, let interstitialAd else { return }
            interstitialReady = false
            interstitialAd.loadAd()
        }
    }

    func preloadRewarded() {
        performAfterInitialization { [weak self] in
            guard let self, let rewardedAd else { return }
            rewardedReady = false
            rewardedAd.loadAd()
        }
    }

    func showInterstitial(from viewController: UIViewController, completion: @escaping () -> Void) {
        performAfterInitialization { [weak self] in
            guard let self,
                  let interstitialAd,
                  interstitialReady,
                  interstitialAd.isAdReady() else {
                completion()
                return
            }

            pendingInterstitialCompletion = completion
            interstitialAd.showAd(viewController: viewController, placementName: nil)
        }
    }

    func showRewarded(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        performAfterInitialization { [weak self] in
            guard let self,
                  let rewardedAd,
                  rewardedReady,
                  rewardedAd.isAdReady() else {
                completion(false)
                return
            }

            rewardedCloseFallbackWorkItem?.cancel()
            rewardedCloseFallbackWorkItem = nil
            rewardedGrantReceived = false
            rewardedWasDisplayed = false
            pendingRewardedCompletion = completion
            rewardedAd.showAd(viewController: viewController, placementName: nil)
        }
    }

    private func initializeIfNeeded() {
        guard !isInitialized, !isInitializing else { return }
        isInitializing = true

        let request = LPMInitRequestBuilder(appKey: Credentials.appKey).build()
        LevelPlay.initWith(request) { [weak self] _, _ in
            guard let self else { return }
            isInitializing = false

            if !isInitialized {
                isInitialized = true
                setupAdsIfNeeded()
            }

            let actions = pendingInitActions
            pendingInitActions.removeAll()
            actions.forEach { $0() }
        }
    }

    private func performAfterInitialization(_ action: @escaping () -> Void) {
        if isInitialized {
            action()
            return
        }

        pendingInitActions.append(action)
        initializeIfNeeded()
    }

    private func setupAdsIfNeeded() {
        if interstitialAd == nil {
            let ad = LPMInterstitialAd(adUnitId: Credentials.interstitialAdUnitID)
            let proxy = InterstitialDelegateProxy(owner: self)
            ad.setDelegate(proxy)
            interstitialAd = ad
            interstitialDelegateProxy = proxy
        }

        if rewardedAd == nil {
            let ad = LPMRewardedAd(adUnitId: Credentials.rewardedAdUnitID)
            let proxy = RewardedDelegateProxy(owner: self)
            ad.setDelegate(proxy)
            rewardedAd = ad
            rewardedDelegateProxy = proxy
        }
    }

    fileprivate func handleInterstitialLoaded() {
        interstitialReady = true
    }

    fileprivate func handleInterstitialLoadFailed() {
        interstitialReady = false
    }

    fileprivate func handleInterstitialDisplayed() {
        interstitialReady = false
    }

    fileprivate func handleInterstitialDisplayFailed() {
        interstitialReady = false
        let completion = pendingInterstitialCompletion
        pendingInterstitialCompletion = nil
        completion?()
    }

    fileprivate func handleInterstitialClosed() {
        let completion = pendingInterstitialCompletion
        pendingInterstitialCompletion = nil
        completion?()
    }

    fileprivate func handleRewardedLoaded() {
        rewardedReady = true
    }

    fileprivate func handleRewardedLoadFailed() {
        rewardedReady = false
    }

    fileprivate func handleRewardedDisplayed() {
        rewardedReady = false
        rewardedWasDisplayed = true
    }

    fileprivate func handleRewardGranted() {
        rewardedGrantReceived = true
    }

    fileprivate func handleRewardedDisplayFailed() {
        completePendingRewarded(didReward: false)
    }

    fileprivate func handleRewardedClosed() {
        rewardedCloseFallbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Some mediated networks may not emit a reward callback consistently.
            // If the rewarded ad was displayed and then closed, grant the hint as fallback.
            let didReward = rewardedGrantReceived || rewardedWasDisplayed
            completePendingRewarded(didReward: didReward)
        }
        rewardedCloseFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func completePendingRewarded(didReward: Bool) {
        rewardedCloseFallbackWorkItem?.cancel()
        rewardedCloseFallbackWorkItem = nil

        let completion = pendingRewardedCompletion
        pendingRewardedCompletion = nil
        rewardedGrantReceived = false
        rewardedWasDisplayed = false
        completion?(didReward)
    }
}

private final class InterstitialDelegateProxy: NSObject, LPMInterstitialAdDelegate {
    weak var owner: LevelPlayAdProvider?

    init(owner: LevelPlayAdProvider) {
        self.owner = owner
    }

    func didLoadAd(with adInfo: LPMAdInfo) {
        owner?.handleInterstitialLoaded()
    }

    func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
        owner?.handleInterstitialLoadFailed()
    }

    func didDisplayAd(with adInfo: LPMAdInfo) {
        owner?.handleInterstitialDisplayed()
    }

    func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
        owner?.handleInterstitialDisplayFailed()
    }

    func didCloseAd(with adInfo: LPMAdInfo) {
        owner?.handleInterstitialClosed()
    }
}

private final class RewardedDelegateProxy: NSObject, LPMRewardedAdDelegate {
    weak var owner: LevelPlayAdProvider?

    init(owner: LevelPlayAdProvider) {
        self.owner = owner
    }

    func didLoadAd(with adInfo: LPMAdInfo) {
        owner?.handleRewardedLoaded()
    }

    func didFailToLoadAd(withAdUnitId adUnitId: String, error: Error) {
        owner?.handleRewardedLoadFailed()
    }

    func didDisplayAd(with adInfo: LPMAdInfo) {
        owner?.handleRewardedDisplayed()
    }

    func didRewardAd(with adInfo: LPMAdInfo, reward: LPMReward) {
        owner?.handleRewardGranted()
    }

    func didFailToDisplayAd(with adInfo: LPMAdInfo, error: Error) {
        owner?.handleRewardedDisplayFailed()
    }

    func didCloseAd(with adInfo: LPMAdInfo) {
        owner?.handleRewardedClosed()
    }
}
#endif
