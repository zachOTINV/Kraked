import SwiftUI
import UIKit

extension GameColor {
    var uiColor: UIColor {
        switch self {
        case .red: return UIColor(red: 0.88, green: 0.23, blue: 0.25, alpha: 1)
        case .green: return UIColor(red: 0.18, green: 0.72, blue: 0.38, alpha: 1)
        case .blue: return UIColor(red: 0.20, green: 0.45, blue: 0.93, alpha: 1)
        case .gray: return UIColor(red: 0.63, green: 0.66, blue: 0.72, alpha: 1)
        }
    }

    var swiftUIColor: Color {
        Color(uiColor)
    }
}

enum BrandColors {
    static let navy = Color(red: 10 / 255, green: 22 / 255, blue: 57 / 255)
    static let navyMuted = Color(red: 58 / 255, green: 73 / 255, blue: 101 / 255)
    static let cardText = Color(red: 62 / 255, green: 79 / 255, blue: 110 / 255)
    static let pageBackgroundA = Color(red: 236 / 255, green: 241 / 255, blue: 247 / 255)
    static let pageBackgroundB = Color(red: 223 / 255, green: 233 / 255, blue: 242 / 255)
}
