import Foundation

struct AutomationConfig {
    let autoPlay: Bool
    let autoLevelSelectOnly: Bool
    let autoOpenSettings: Bool
    let levelIndex: Int?
    let toggleSequence: [String]
    let autoReset: Bool
    let autoNext: Bool
    let actionDelay: TimeInterval
    let settleDelay: TimeInterval

    static let disabled = AutomationConfig(
        autoPlay: false,
        autoLevelSelectOnly: false,
        autoOpenSettings: false,
        levelIndex: nil,
        toggleSequence: [],
        autoReset: false,
        autoNext: false,
        actionDelay: 0.25,
        settleDelay: 1.0
    )

    var isEnabled: Bool {
        autoPlay || autoLevelSelectOnly || autoOpenSettings || levelIndex != nil || !toggleSequence.isEmpty || autoReset || autoNext
    }

    static func from(arguments: [String]) -> AutomationConfig {
        var autoPlay = false
        var autoLevelSelectOnly = false
        var autoOpenSettings = false
        var levelIndex: Int?
        var toggleSequence: [String] = []
        var autoReset = false
        var autoNext = false
        var actionDelay: TimeInterval = 0.25
        var settleDelay: TimeInterval = 1.0

        for argument in arguments {
            if argument == "--auto-play" {
                autoPlay = true
                continue
            }

            if argument == "--auto-level-select-only" {
                autoPlay = true
                autoLevelSelectOnly = true
                continue
            }

            if argument == "--auto-open-settings" {
                autoPlay = true
                autoOpenSettings = true
                continue
            }

            if argument == "--auto-reset" {
                autoReset = true
                continue
            }

            if argument == "--auto-next" {
                autoNext = true
                continue
            }

            if argument.hasPrefix("--auto-level=") {
                let value = String(argument.dropFirst("--auto-level=".count))
                if let level = Int(value), level > 0 {
                    levelIndex = level - 1
                }
                continue
            }

            if argument.hasPrefix("--auto-toggle=") {
                let value = String(argument.dropFirst("--auto-toggle=".count))
                toggleSequence = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                    .filter { !$0.isEmpty }
                continue
            }

            if argument.hasPrefix("--auto-delay=") {
                let value = String(argument.dropFirst("--auto-delay=".count))
                if let parsed = Double(value), parsed >= 0 {
                    actionDelay = parsed
                }
                continue
            }

            if argument.hasPrefix("--auto-settle=") {
                let value = String(argument.dropFirst("--auto-settle=".count))
                if let parsed = Double(value), parsed >= 0 {
                    settleDelay = parsed
                }
            }
        }

        return AutomationConfig(
            autoPlay: autoPlay,
            autoLevelSelectOnly: autoLevelSelectOnly,
            autoOpenSettings: autoOpenSettings,
            levelIndex: levelIndex,
            toggleSequence: toggleSequence,
            autoReset: autoReset,
            autoNext: autoNext,
            actionDelay: actionDelay,
            settleDelay: settleDelay
        )
    }
}
