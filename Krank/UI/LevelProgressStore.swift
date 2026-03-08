import Foundation

final class LevelProgressStore {
    static let shared = LevelProgressStore()

    private let completedKey = "krank.completed.level.indices"
    private let defaults = UserDefaults.standard

    private init() {}

    func completedLevels() -> Set<Int> {
        let raw = defaults.array(forKey: completedKey) as? [Int] ?? []
        return Set(raw.filter { $0 >= 0 })
    }

    func markCompleted(levelIndex: Int) {
        guard levelIndex >= 0 else { return }
        var completed = completedLevels()
        completed.insert(levelIndex)
        defaults.set(Array(completed).sorted(), forKey: completedKey)
    }

    func resetAllProgress() {
        defaults.removeObject(forKey: completedKey)
    }

    func highestUnlockedLevel(totalLevels: Int) -> Int {
        guard totalLevels > 0 else { return 0 }

        let completed = completedLevels()
        let highestCompleted = completed.max() ?? -1
        return min(max(highestCompleted + 1, 0), totalLevels - 1)
    }

    func isUnlocked(levelIndex: Int, totalLevels: Int) -> Bool {
        levelIndex <= highestUnlockedLevel(totalLevels: totalLevels)
    }
}
