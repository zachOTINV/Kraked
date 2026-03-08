import Foundation

enum LevelSolver {
    static func firstSolution(for level: Level) -> [String: GameColor]? {
        var state = level.initialState()
        return search(level: level, switchOrder: level.switches, index: 0, state: &state)
    }

    static func hasSolution(for level: Level) -> Bool {
        firstSolution(for: level) != nil
    }

    private static func search(
        level: Level,
        switchOrder: [String],
        index: Int,
        state: inout [String: GameColor]
    ) -> [String: GameColor]? {
        if index == switchOrder.count {
            return RuleEvaluator.isSolved(level, state: state) ? state : nil
        }

        let switchID = switchOrder[index]
        let original = state[switchID] ?? .gray

        for color in GameColor.playable {
            state[switchID] = color
            if let solution = search(level: level, switchOrder: switchOrder, index: index + 1, state: &state) {
                return solution
            }
        }

        state[switchID] = original
        return nil
    }
}
