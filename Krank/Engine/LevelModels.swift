import Foundation

struct Level: Decodable, Identifiable {
    let id: String
    let switches: [String]
    let initial: [String: GameColor]
    let rules: [LevelRule]
    let metadata: LevelMetadata?
}

struct LevelRule: Decodable, Identifiable {
    let id: String
    let display: String
    let expr: RuleExpression
}

struct LevelMetadata: Decodable {
    let rawDifficultyScore: Int?
    let difficultyScore: Int?
    let checksAllowed: Int?
    let solutionHash: String?
    let difficultyPercentile: Double?
    let difficultyCalibrationVersion: Int?
    let packDifficultyPercentile: Double?
}

extension Level {
    func initialState() -> [String: GameColor] {
        var state = [String: GameColor]()
        for switchID in switches {
            state[switchID] = initial[switchID] ?? .gray
        }
        return state
    }
}
