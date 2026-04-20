import Foundation
import UIKit

#if canImport(FBSDKCoreKit)
import FBSDKCoreKit
#endif

enum MetaAppEventsManager {
    private enum InfoPlistKeys {
        static let appID = "FacebookAppID"
        static let clientToken = "FacebookClientToken"
    }

    static func configure(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        #if canImport(FBSDKCoreKit)
        guard isConfigured else { return }

        Settings.shared.isAutoLogAppEventsEnabled = true
        Settings.shared.isAdvertiserIDCollectionEnabled = true
        _ = ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        #endif
    }

    static func applicationDidBecomeActive(application: UIApplication) {
        #if canImport(FBSDKCoreKit)
        guard isConfigured else { return }

        // `activateApp()` is the signal Meta uses for app-open/install attribution.
        AppEvents.shared.activateApp()
        #if DEBUG
        AppEvents.shared.flush()
        #endif
        #endif

        syncAdvertiserTrackingStatus()
    }

    static func syncAdvertiserTrackingStatus() {
        #if canImport(FBSDKCoreKit)
        guard isConfigured else { return }
        // FBSDK v18 reads ATT status directly on supported iOS versions.
        #endif
    }

    static func logLevelCompleted(levelNumber: Int) {
        #if canImport(FBSDKCoreKit)
        guard isConfigured else { return }

        let parameters: [AppEvents.ParameterName: Any] = [
            .level: String(levelNumber),
        ]
        AppEvents.shared.logEvent(
            .achievedLevel,
            parameters: parameters
        )
        flushIfNeededForVerification()
        #endif
    }

    static func logRated(ratingValue: Double, maxRatingValue: Int, contentType: String = "app") {
        #if canImport(FBSDKCoreKit)
        guard isConfigured else { return }

        let parameters: [AppEvents.ParameterName: Any] = [
            .maxRatingValue: String(maxRatingValue),
            .contentType: contentType,
        ]
        AppEvents.shared.logEvent(
            .rated,
            valueToSum: ratingValue,
            parameters: parameters
        )
        flushIfNeededForVerification()
        #endif
    }

    static func logAdClick(adType: String?) {
        #if canImport(FBSDKCoreKit)
        guard isConfigured else { return }

        if let adType, !adType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            AppEvents.shared.logEvent(
                .adClick,
                parameters: [.adType: adType]
            )
        } else {
            AppEvents.shared.logEvent(.adClick)
        }
        flushIfNeededForVerification()
        #endif
    }

    private static var isConfigured: Bool {
        let appID = nonEmptyPlistValue(for: InfoPlistKeys.appID)
        let clientToken = nonEmptyPlistValue(for: InfoPlistKeys.clientToken)
        return appID != nil && clientToken != nil
    }

    private static func nonEmptyPlistValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) else { return nil }

        let raw: String
        if let stringValue = value as? String {
            raw = stringValue
        } else if let numericValue = value as? NSNumber {
            raw = numericValue.stringValue
        } else {
            raw = String(describing: value)
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !isUnresolvedBuildSetting(trimmed) else { return nil }
        return trimmed
    }

    private static func isUnresolvedBuildSetting(_ value: String) -> Bool {
        let unresolvedPrefixes = ["$(", "${", "<#"]
        return unresolvedPrefixes.contains { value.hasPrefix($0) }
    }

    private static func flushIfNeededForVerification() {
        #if canImport(FBSDKCoreKit)
        if isDebugBuild || isSandboxReceiptBuild {
            AppEvents.shared.flush()
        }
        #endif
    }

    private static var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private static var isSandboxReceiptBuild: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == "sandboxReceipt"
    }

}
