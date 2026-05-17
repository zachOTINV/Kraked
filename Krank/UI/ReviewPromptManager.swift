import Foundation

final class ReviewPromptManager {
    static let shared = ReviewPromptManager()

    enum Decision: String {
        case undecided
        case rated
        case declined
    }

    private enum StorageKeys {
        static let decision = "krank.reviewPrompt.decision"
        static let snoozeUntil = "krank.reviewPrompt.snoozeUntil"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func isEligible(completedLevelCount: Int, now: Date = .now) -> Bool {
        guard completedLevelCount >= 10 else { return false }
        guard decision == .undecided else { return false }

        guard let snoozeUntilDate else {
            return true
        }

        return now >= snoozeUntilDate
    }

    func markNotNow(now: Date = .now) {
        let snoozeUntil = calendar.date(byAdding: .day, value: 5, to: now)
            ?? now.addingTimeInterval(5 * 24 * 60 * 60)
        defaults.set(snoozeUntil, forKey: StorageKeys.snoozeUntil)
    }

    func markRated() {
        defaults.set(Decision.rated.rawValue, forKey: StorageKeys.decision)
        clearSnooze()
    }

    func markDeclined() {
        defaults.set(Decision.declined.rawValue, forKey: StorageKeys.decision)
        clearSnooze()
    }

    private var decision: Decision {
        guard let rawValue = defaults.string(forKey: StorageKeys.decision),
              let storedDecision = Decision(rawValue: rawValue) else {
            return .undecided
        }

        return storedDecision
    }

    private var snoozeUntilDate: Date? {
        defaults.object(forKey: StorageKeys.snoozeUntil) as? Date
    }

    private func clearSnooze() {
        defaults.removeObject(forKey: StorageKeys.snoozeUntil)
    }
}
