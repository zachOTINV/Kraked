import Foundation
import Combine

enum HintOutcome {
    case applied(switchID: String, color: GameColor)
    case unavailable
    case alreadySolved
    case noChangeNeeded
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var levels: [Level] = []
    @Published private(set) var currentLevelIndex: Int = 0
    @Published private(set) var currentLevel: Level?
    @Published private(set) var switchStates: [String: GameColor] = [:]
    @Published private(set) var ruleResults: [Bool] = []
    @Published private(set) var isSolved: Bool = false
    @Published private(set) var guessesCount: Int = 0
    @Published private(set) var loadError: String?

    var onLevelLoaded: ((Level, [String: GameColor]) -> Void)?
    var onSwitchStatesChanged: (([String: GameColor]) -> Void)?

    private let repository: LevelRepository

    init(repository: LevelRepository) {
        self.repository = repository
    }

    convenience init() {
        self.init(repository: LevelRepository())
    }

    func loadLevels() {
        do {
            levels = try repository.loadLevels()
            loadError = nil
            guard !levels.isEmpty else {
                loadError = "No levels were loaded."
                return
            }
            startLevel(at: 0)
        } catch {
            loadError = error.localizedDescription
        }
    }

    func startLevel(at index: Int) {
        guard levels.indices.contains(index) else { return }

        currentLevelIndex = index
        currentLevel = levels[index]
        switchStates = levels[index].initialState()
        guessesCount = 0
        reevaluateRules()

        if let level = currentLevel {
            onLevelLoaded?(level, switchStates)
        }
    }

    func restartLevel() {
        startLevel(at: currentLevelIndex)
    }

    func goToNextLevel() {
        let next = currentLevelIndex + 1
        guard levels.indices.contains(next) else { return }
        startLevel(at: next)
    }

    func toggleSwitch(_ switchID: String) {
        guard switchStates[switchID] != nil else { return }
        switchStates[switchID] = (switchStates[switchID] ?? .gray).nextToggleColor
        reevaluateRules()
        onSwitchStatesChanged?(switchStates)
    }

    @discardableResult
    func validateCurrentState() -> Bool {
        guessesCount += 1
        reevaluateRules()
        return isSolved
    }

    func applyHintFromSolution() -> HintOutcome {
        guard let level = currentLevel else { return .unavailable }
        guard let solution = LevelSolver.firstSolution(for: level) else { return .unavailable }

        if isSolved {
            return .alreadySolved
        }

        let incorrectSwitches: [(id: String, target: GameColor)] = level.switches.compactMap { switchID in
            guard let targetColor = solution[switchID] else { return nil }
            let currentColor = switchStates[switchID] ?? .gray
            guard currentColor != targetColor else { return nil }
            return (id: switchID, target: targetColor)
        }

        guard let picked = incorrectSwitches.randomElement() else {
            return .noChangeNeeded
        }

        switchStates[picked.id] = picked.target
        reevaluateRules()
        onSwitchStatesChanged?(switchStates)
        return .applied(switchID: picked.id, color: picked.target)
    }

    var currentLevelTitle: String {
        "Level \(currentLevelIndex + 1)"
    }

    private func reevaluateRules() {
        guard let level = currentLevel else {
            ruleResults = []
            isSolved = false
            return
        }

        ruleResults = RuleEvaluator.evaluateLevel(level, state: switchStates)
        let hasGraySwitch = switchStates.values.contains(.gray)
        isSolved = !hasGraySwitch && ruleResults.allSatisfy { $0 }
    }
}
