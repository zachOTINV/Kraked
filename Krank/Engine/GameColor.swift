import Foundation

enum GameColor: String, Codable, CaseIterable {
    case red = "R"
    case green = "G"
    case blue = "B"
    case gray = "GRAY"

    // Gray is a temporary "undecided" state and should not be part of solved assignments.
    static let playable: [GameColor] = [.red, .green, .blue]

    var displayName: String {
        switch self {
        case .red: return "RED"
        case .green: return "GREEN"
        case .blue: return "BLUE"
        case .gray: return "GRAY"
        }
    }

    var nextToggleColor: GameColor {
        switch self {
        case .gray: return .red
        case .red: return .green
        case .green: return .blue
        case .blue: return .gray
        }
    }
}
