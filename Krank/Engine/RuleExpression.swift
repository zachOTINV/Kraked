import Foundation

indirect enum RuleExpression: Decodable {
    case and([RuleExpression])
    case or([RuleExpression])
    case not(RuleExpression)
    case xor2(RuleExpression, RuleExpression)
    case implies(RuleExpression, RuleExpression)

    case equal(String, String)
    case notEqual(String, String)
    case isColor(String, GameColor)

    case countColorEq(set: [String], color: GameColor, k: Int)
    case countColorGte(set: [String], color: GameColor, k: Int)
    case countColorLte(set: [String], color: GameColor, k: Int)

    private enum CodingKeys: String, CodingKey {
        case op
        case args
        case a
        case b
        case x
        case color
        case set
        case k
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(String.self, forKey: .op)

        switch op {
        case "AND":
            self = .and(try container.decode([RuleExpression].self, forKey: .args))

        case "OR":
            self = .or(try container.decode([RuleExpression].self, forKey: .args))

        case "NOT":
            self = .not(try container.decode(RuleExpression.self, forKey: .a))

        case "XOR2":
            self = .xor2(
                try container.decode(RuleExpression.self, forKey: .a),
                try container.decode(RuleExpression.self, forKey: .b)
            )

        case "IMPLIES":
            self = .implies(
                try container.decode(RuleExpression.self, forKey: .a),
                try container.decode(RuleExpression.self, forKey: .b)
            )

        case "EQUAL":
            self = .equal(
                try container.decode(String.self, forKey: .a),
                try container.decode(String.self, forKey: .b)
            )

        case "NOT_EQUAL":
            self = .notEqual(
                try container.decode(String.self, forKey: .a),
                try container.decode(String.self, forKey: .b)
            )

        case "IS_COLOR":
            self = .isColor(
                try container.decode(String.self, forKey: .x),
                try container.decode(GameColor.self, forKey: .color)
            )

        case "COUNT_COLOR_EQ":
            self = .countColorEq(
                set: try container.decode([String].self, forKey: .set),
                color: try container.decode(GameColor.self, forKey: .color),
                k: try container.decode(Int.self, forKey: .k)
            )

        case "COUNT_COLOR_GTE":
            self = .countColorGte(
                set: try container.decode([String].self, forKey: .set),
                color: try container.decode(GameColor.self, forKey: .color),
                k: try container.decode(Int.self, forKey: .k)
            )

        case "COUNT_COLOR_LTE":
            self = .countColorLte(
                set: try container.decode([String].self, forKey: .set),
                color: try container.decode(GameColor.self, forKey: .color),
                k: try container.decode(Int.self, forKey: .k)
            )

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .op,
                in: container,
                debugDescription: "Unsupported rule op: \(op)"
            )
        }
    }
}
