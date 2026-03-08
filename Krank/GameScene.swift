import SpriteKit
import UIKit

final class GameScene: SKScene {
    private weak var gameViewModel: GameViewModel?
    private var switchNodes: [String: SKShapeNode] = [:]

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func bind(to viewModel: GameViewModel) {
        gameViewModel = viewModel

        viewModel.onLevelLoaded = { [weak self] level, state in
            self?.drawLevel(level, state: state)
        }

        viewModel.onSwitchStatesChanged = { [weak self] state in
            self?.updateSwitchColors(state: state)
        }

        if let level = viewModel.currentLevel {
            drawLevel(level, state: viewModel.switchStates)
        }
    }

    private func drawLevel(_ level: Level, state: [String: GameColor]) {
        removeAllChildren()
        switchNodes.removeAll()

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Tap to Cycle Colors"
        title.fontSize = 22
        title.fontColor = UIColor(white: 0.20, alpha: 1)
        title.position = CGPoint(x: size.width / 2, y: size.height - 52)
        addChild(title)

        let count = level.switches.count
        guard count > 0 else { return }

        let columns = min(5, max(2, Int(ceil(sqrt(Double(count))))))
        let rows = Int(ceil(Double(count) / Double(columns)))

        let usableWidth = size.width - 56
        let spacingX = columns == 1 ? 0 : usableWidth / CGFloat(columns - 1)
        let startX = size.width / 2 - (spacingX * CGFloat(columns - 1) / 2)

        let topY = size.height * 0.68
        let spacingY: CGFloat = 108

        for (index, switchID) in level.switches.enumerated() {
            let row = index / columns
            let col = index % columns

            let x = startX + CGFloat(col) * spacingX
            let y = topY - CGFloat(row) * spacingY
            let position = CGPoint(x: x, y: y)

            let node = makeSwitchNode(id: switchID, position: position, color: state[switchID] ?? .gray)
            switchNodes[switchID] = node
            addChild(node)
        }

        if rows > 1 {
            let bottom = topY - CGFloat(rows - 1) * spacingY - 70
            let baseline = SKShapeNode(rectOf: CGSize(width: size.width * 0.84, height: 2), cornerRadius: 1)
            baseline.fillColor = UIColor(white: 0.88, alpha: 1)
            baseline.strokeColor = .clear
            baseline.position = CGPoint(x: size.width / 2, y: bottom)
            addChild(baseline)
        }
    }

    private func makeSwitchNode(id: String, position: CGPoint, color: GameColor) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: 36)
        node.name = "switch_\(id)"
        node.position = position
        node.fillColor = color.uiColor
        node.strokeColor = UIColor(white: 0.97, alpha: 1)
        node.lineWidth = 4

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = "label"
        label.text = id
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -1)

        node.addChild(label)
        return node
    }

    private func updateSwitchColors(state: [String: GameColor]) {
        for (switchID, node) in switchNodes {
            node.fillColor = (state[switchID] ?? .gray).uiColor
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedNode = atPoint(location)

        guard let switchID = switchID(from: tappedNode) else { return }
        gameViewModel?.toggleSwitch(switchID)
    }

    private func switchID(from node: SKNode?) -> String? {
        var current = node

        while let inspected = current {
            if let name = inspected.name, name.hasPrefix("switch_") {
                return String(name.dropFirst(7))
            }
            current = inspected.parent
        }

        return nil
    }
}
