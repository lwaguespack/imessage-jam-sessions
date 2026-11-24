import SpriteKit
import SwiftUI

@MainActor
final class RenderSpikeScene: SKScene {
    var model: RenderSpikeModel?
    var onTouch: (@MainActor (UITouch, String, CGPoint, CGSize) -> Void)?

    private var sprites: [SKSpriteNode] = []
    private let lanes = SKShapeNode()
    private let strike = SKShapeNode()
    private let touchZone = SKShapeNode()

    override func didMove(to view: SKView) {
        backgroundColor = .black
        addChild(touchZone)
        addChild(lanes)
        addChild(strike)
        let colors: [UIColor] = [.systemRed, .systemYellow, .systemGreen, .systemBlue]
        for index in 0..<200 {
            let sprite = SKSpriteNode(color: colors[index % 4], size: CGSize(width: 24, height: 5))
            sprite.zPosition = 2
            addChild(sprite)
            sprites.append(sprite)
        }
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        redraw()
    }

    override func update(_ currentTime: TimeInterval) {
        model?.frame(at: currentTime)
        for (index, sprite) in sprites.enumerated() {
            let depth = (Double(index) / 200 + currentTime / 8).truncatingRemainder(dividingBy: 1)
            let perspective = 0.18 + 0.78 * (1 - depth)
            let lane = CGFloat(index % 4)
            let highwayWidth = size.width * CGFloat(perspective)
            sprite.position = CGPoint(
                x: size.width / 2 + (lane - 1.5) * highwayWidth / 4,
                y: size.height * (0.16 + 0.77 * depth))
            sprite.setScale(CGFloat(0.35 + 0.8 * (1 - depth)))
        }
    }

    func redraw() {
        guard size.width > 0, size.height > 0 else { return }
        let path = CGMutablePath()
        for index in 0...4 {
            let fraction = CGFloat(index) / 4 - 0.5
            path.move(to: CGPoint(x: size.width / 2 + fraction * size.width * 0.96, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2 + fraction * size.width * 0.18, y: size.height))
        }
        lanes.path = path
        lanes.strokeColor = .white.withAlphaComponent(0.5)
        lanes.lineWidth = 1

        touchZone.path = CGPath(
            rect: CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.3),
            transform: nil)
        touchZone.fillColor = .white.withAlphaComponent(0.08)
        touchZone.strokeColor = .clear
        let y = size.height * ((model?.lineInsideZone ?? false) ? 0.15 : 0.3)
        let line = CGMutablePath()
        line.move(to: CGPoint(x: 0, y: y))
        line.addLine(to: CGPoint(x: size.width, y: y))
        strike.path = line
        strike.strokeColor = .white
        strike.lineWidth = 2
        strike.zPosition = 3
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: "began")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: "moved")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: "ended")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        forward(touches, phase: "cancelled")
    }

    private func forward(_ touches: Set<UITouch>, phase: String) {
        for touch in touches {
            onTouch?(touch, phase, touch.location(in: self), size)
        }
    }
}

struct HighwaySceneView: UIViewRepresentable {
    let model: RenderSpikeModel
    var onTouch: (@MainActor (UITouch, String, CGPoint, CGSize) -> Void)?

    func makeUIView(context: Context) -> SpikeSKView {
        let view = SpikeSKView()
        view.model = model
        view.preferredFramesPerSecond = 120
        view.isMultipleTouchEnabled = true
        let scene = RenderSpikeScene(size: CGSize(width: 320, height: 400))
        scene.scaleMode = .resizeFill
        scene.model = model
        scene.onTouch = onTouch
        scene.isUserInteractionEnabled = true
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SpikeSKView, context: Context) {
        guard let scene = view.scene as? RenderSpikeScene else { return }
        scene.onTouch = onTouch
        scene.redraw()
    }
}

final class SpikeSKView: SKView {
    weak var model: RenderSpikeModel?

    override func layoutSubviews() {
        super.layoutSubviews()
        recordGeometry()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        recordGeometry()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        recordGeometry()
    }

    private func recordGeometry() {
        guard let screen = window?.windowScene?.screen else { return }
        model?.geometry(size: bounds.size, safeArea: safeAreaInsets, maximumFPS: screen.maximumFramesPerSecond)
    }
}
