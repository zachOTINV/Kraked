import Foundation

enum FeedbackType: String, CaseIterable, Identifiable {
    case bug = "Bug"
    case puzzleIssue = "Puzzle issue"
    case suggestion = "Suggestion"
    case other = "Other"

    var id: String { rawValue }

    var subjectLabel: String {
        switch self {
        case .bug:
            return "Bug"
        case .puzzleIssue:
            return "Puzzle Issue"
        case .suggestion:
            return "Suggestion"
        case .other:
            return "Other"
        }
    }
}

struct FeedbackMailBuilder {
    static let recipient = "contact@overtimeinnovations.com"

    static func mailtoURL(
        type: FeedbackType,
        message: String,
        appVersion: String,
        buildNumber: String,
        systemVersion: String,
        deviceModel: String
    ) -> URL? {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = recipient
        components.queryItems = [
            URLQueryItem(name: "subject", value: "KRANK Feedback - \(type.subjectLabel)"),
            URLQueryItem(name: "body", value: body(
                type: type,
                message: trimmedMessage,
                appVersion: appVersion,
                buildNumber: buildNumber,
                systemVersion: systemVersion,
                deviceModel: deviceModel
            ))
        ]
        return components.url
    }

    private static func body(
        type: FeedbackType,
        message: String,
        appVersion: String,
        buildNumber: String,
        systemVersion: String,
        deviceModel: String
    ) -> String {
        """
        Feedback type: \(type.rawValue)

        Message:
        \(message)

        ---
        App: KRANK
        Version: \(appVersion)
        Build: \(buildNumber)
        iOS: \(systemVersion)
        Device: \(deviceModel)
        """
    }
}
