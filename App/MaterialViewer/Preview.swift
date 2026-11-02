import AppKit
import SwiftUI
import QuartzCore
import MaterialViewerKit

struct MaterialPreview: NSViewRepresentable {
    let session: PreviewSession
    let background: String
    let animated: Bool
    let darkText: Bool
    let didLayout: () -> Void

    func makeNSView(context: Context) -> PreviewView { PreviewView() }

    func updateNSView(_ view: PreviewView, context: Context) {
        view.update(session: session, background: background, animated: animated, darkText: darkText)
        view.didLayout = didLayout
    }
}

final class PreviewView: NSView {
    private let scene = CAGradientLayer()
    private let grid = CAShapeLayer()
    private let shapes = (0..<5).map { _ in CALayer() }
    private let patternLabel = CATextLayer()
    private let caption = CATextLayer()
    private let border = CALayer()
    private var session: PreviewSession?
    private var background = "Colors"
    private var animated = false
    private var lastSize = CGSize.zero
    var didLayout: (() -> Void)?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(scene)
        scene.startPoint = CGPoint(x: 0, y: 0)
        scene.endPoint = CGPoint(x: 1, y: 1)
        for shape in shapes { scene.addSublayer(shape) }
        scene.addSublayer(grid)
        scene.addSublayer(patternLabel)
        patternLabel.string = "Aa 0123456789\nMATERIAL / BACKDROP\nAa 0123456789"
        patternLabel.font = NSFont.monospacedSystemFont(ofSize: 23, weight: .bold)
        patternLabel.fontSize = 23
        patternLabel.alignmentMode = .center
        patternLabel.foregroundColor = NSColor.white.withAlphaComponent(0.85).cgColor
        caption.string = "Material\nLive background sampling"
        caption.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        caption.fontSize = 22
        caption.alignmentMode = .center
        border.borderWidth = 1
        border.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
        border.cornerRadius = 28
        layer?.addSublayer(border)
        layer?.addSublayer(caption)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(session: PreviewSession, background: String, animated: Bool, darkText: Bool) {
        if self.session !== session {
            self.session?.renderer.layer.removeFromSuperlayer()
            self.session = session
            lastSize = .zero
            let material = session.renderer.layer
            material.cornerRadius = 28
            material.masksToBounds = true
            layer?.insertSublayer(material, above: scene)
        }
        self.background = background
        caption.foregroundColor = (darkText ? NSColor.black : NSColor.white).withAlphaComponent(0.82).cgColor
        if self.animated != animated {
            self.animated = animated
            if animated {
                let animation = CABasicAnimation(keyPath: "transform.translation.x")
                animation.fromValue = -110
                animation.toValue = 110
                animation.duration = 3
                animation.autoreverses = true
                animation.repeatCount = .infinity
                shapes[0].add(animation, forKey: "movement")
            } else {
                shapes[0].removeAnimation(forKey: "movement")
            }
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scene.frame = bounds
        let width = bounds.width
        let height = bounds.height
        let isGrid = background == "Grid"
        scene.colors = (isGrid ? [NSColor(white: 0.95, alpha: 1), NSColor(white: 0.68, alpha: 1)]
                        : [NSColor(srgbRed: 0.09, green: 0.19, blue: 0.35, alpha: 1),
                           NSColor(srgbRed: 0.24, green: 0.42, blue: 0.65, alpha: 1)]).map(\.cgColor)
        let colors: [NSColor] = [.systemOrange, .systemPink, .systemTeal, .systemIndigo, .systemYellow]
        let positions: [(CGFloat, CGFloat, CGFloat)] = [(0.18, 0.18, 0.60), (0.7, 0.7, 0.55), (0.82, 0.17, 0.58), (0.15, 0.85, 0.48), (0.48, 0.55, 0.26)]
        for (index, shape) in shapes.enumerated() {
            let (x, y, size) = positions[index]
            let side = width * size
            shape.frame = CGRect(x: width * x - side / 2, y: height * y - side / 2, width: side, height: side)
            shape.cornerRadius = index.isMultiple(of: 2) ? side / 2 : 24
            shape.backgroundColor = colors[index].cgColor
            shape.isHidden = isGrid
        }
        let path = CGMutablePath()
        for x in stride(from: CGFloat(0), through: width, by: 18) {
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height))
        }
        for y in stride(from: CGFloat(0), through: height, by: 18) {
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y))
        }
        grid.frame = bounds
        grid.path = path
        grid.strokeColor = NSColor.black.withAlphaComponent(isGrid ? 0.65 : 0.18).cgColor
        grid.lineWidth = isGrid ? 2 : 1
        grid.fillColor = nil
        let scale = window?.backingScaleFactor ?? 2
        patternLabel.contentsScale = scale
        patternLabel.frame = CGRect(x: 0, y: height * 0.35, width: width, height: 108)
        patternLabel.foregroundColor = (isGrid ? NSColor.black : NSColor.white).withAlphaComponent(0.85).cgColor
        let card = CGRect(x: width * 0.12, y: height * 0.16, width: width * 0.76, height: height * 0.68)
        session?.renderer.layer.frame = card
        session?.renderer.layer.contentsScale = scale
        border.frame = card
        caption.frame = CGRect(x: card.minX + 10, y: card.midY - 33, width: card.width - 20, height: 66)
        caption.contentsScale = scale
        CATransaction.commit()
        if lastSize != bounds.size {
            lastSize = bounds.size
            DispatchQueue.main.async { [weak self] in self?.didLayout?() }
        }
    }
}
