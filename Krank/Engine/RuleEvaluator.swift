import Foundation

enum RuleEvaluator {
    static func evaluateRule(_ expr: RuleExpression, state: [String: GameColor]) -> Bool {
        switch expr {
        case .and(let args):
            return args.allSatisfy { evaluateRule($0, state: state) }

        case .or(let args):
            return args.contains { evaluateRule($0, state: state) }

        case .not(let inner):
            return !evaluateRule(inner, state: state)

        case .xor2(let a, let b):
            let left = evaluateRule(a, state: state)
            let right = evaluateRule(b, state: state)
            return left != right

        case .implies(let a, let b):
            let left = evaluateRule(a, state: state)
            let right = evaluateRule(b, state: state)
            return !left || right

        case .equal(let a, let b):
            return state[a] == state[b]

        case .notEqual(let a, let b):
            return state[a] != state[b]

        case .isColor(let x, let color):
            return state[x] == color

        case .countColorEq(let set, let color, let k):
            return count(in: set, color: color, state: state) == k

        case .countColorGte(let set, let color, let k):
            return count(in: set, color: color, state: state) >= k

        case .countColorLte(let set, let color, let k):
            return count(in: set, color: color, state: state) <= k
        }
    }

    static func evaluateLevel(_ level: Level, state: [String: GameColor]) -> [Bool] {
        level.rules.map { evaluateRule($0.expr, state: state) }
    }

    static func isSolved(_ level: Level, state: [String: GameColor]) -> Bool {
        evaluateLevel(level, state: state).allSatisfy { $0 }
    }

    private static func count(in set: [String], color: GameColor, state: [String: GameColor]) -> Int {
        set.reduce(0) { partialResult, switchID in
            partialResult + (state[switchID] == color ? 1 : 0)
        }
    }
}
