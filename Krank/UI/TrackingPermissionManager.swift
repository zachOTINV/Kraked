import Foundation
import UIKit
import AppTrackingTransparency

@MainActor
final class TrackingPermissionManager {
    static let shared = TrackingPermissionManager()

    private enum StorageKeys {
        static let didRequestATT = "krank.privacy.att.requested"
    }

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func requestIfNeeded() async {
        guard #available(iOS 14, *) else { return }
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        guard !defaults.bool(forKey: StorageKeys.didRequestATT) else { return }

        // The ATT prompt should only be requested while app is active.
        for _ in 0..<20 where UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard UIApplication.shared.applicationState == .active else { return }

        _ = await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        MetaAppEventsManager.syncAdvertiserTrackingStatus()
        defaults.set(true, forKey: StorageKeys.didRequestATT)
    }
}
