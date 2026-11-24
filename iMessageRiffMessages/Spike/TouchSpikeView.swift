import SwiftUI
import UIKit.UIGestureRecognizerSubclass

struct TouchSpikeView: View {
    let report: SpikeReport
    let requestExpanded: @MainActor () -> Void
    @State private var model: RenderSpikeModel
    @State private var exclusive = false

    init(report: SpikeReport, requestExpanded: @escaping @MainActor () -> Void) {
        self.report = report
        self.requestExpanded = requestExpanded
        _model = State(initialValue: RenderSpikeModel(report: report))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Expand") { requestExpanded() }
                Picker("Input mode", selection: $exclusive) {
                    Text("Scene").tag(false)
                    Text("UIKit").tag(true)
                }
                .pickerStyle(.segmented)
                HStack(spacing: 4) {
                    Text("Haptic").font(.caption)
                    Toggle("Haptics", isOn: $model.hapticsEnabled).labelsHidden()
                }
            }
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    HighwaySceneView(model: model, onTouch: exclusive ? nil : sceneTouch)
                    if exclusive {
                        ExclusiveTouchSurface { touch, phase, point, size in
                            model.touch(touch, phase: phase, point: point, size: size, mode: "UIKit")
                        }
                        .frame(height: geometry.size.height * 0.3)
                    }
                }
                .accessibilityIdentifier("spike-highway")
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text("Lane starts: \(model.touchCounts.map(String.init).joined(separator: ", "))")
                .accessibilityIdentifier("spike-lane-counts")
            Text("Cancelled: \(model.cancelledTouches). Delivery: \(model.deliveryStatus)")
                .font(.caption)
            HStack {
                Button("Start or reset this mode") { model.resetTouches(mode: modeName) }
                Button("Record summary") { model.reportTouchSummary(mode: modeName) }
                Button("Copy report") { report.copy() }
            }
            .font(.caption)
            if let error = report.storageError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Text("In the shaded zone: 200 two-thumb taps, 20 holds per lane and 20 swipes.")
                .font(.caption)
        }
        .padding(8)
        .navigationTitle("S5 Touch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeName: String { exclusive ? "UIKit" : "scene" }

    private func sceneTouch(_ touch: UITouch, _ phase: String, _ point: CGPoint, _ size: CGSize) {
        model.touch(touch, phase: phase, point: point, size: size, mode: "scene")
    }
}

private struct ExclusiveTouchSurface: UIViewRepresentable {
    let onTouch: @MainActor (UITouch, String, CGPoint, CGSize) -> Void

    func makeUIView(context: Context) -> ExclusiveTouchView {
        let view = ExclusiveTouchView()
        view.onTouch = onTouch
        return view
    }

    func updateUIView(_ view: ExclusiveTouchView, context: Context) {
        view.onTouch = onTouch
    }
}

private final class ExclusiveTouchView: UIView {
    var onTouch: (@MainActor (UITouch, String, CGPoint, CGSize) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        let recognizer = ExclusiveTouchRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        addGestureRecognizer(recognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
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
        for touch in touches { onTouch?(touch, phase, touch.location(in: self), bounds.size) }
    }
}

private final class ExclusiveTouchRecognizer: UIGestureRecognizer {
    private var activeTouches: Set<UITouch> = []

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouches.formUnion(touches)
        state = state == .possible ? .began : .changed
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouches.subtract(touches)
        state = activeTouches.isEmpty ? .ended : .changed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        activeTouches.subtract(touches)
        state = activeTouches.isEmpty ? .cancelled : .changed
    }

    override func reset() {
        activeTouches.removeAll()
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
