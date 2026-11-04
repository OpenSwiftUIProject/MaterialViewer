import SwiftUI
import MaterialViewerKit
import MaterialRuntime
#if !os(watchOS)
import QuartzCore
#endif

struct MaterialPreview: View {
    @ObservedObject var model: ViewerModel
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !model.animated || reduceMotion)) { timeline in
                    Backdrop(grid: model.background == "Grid",
                             phase: model.animated && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0)
                }
                if model.session != nil {
                    let size = CGSize(width: geometry.size.width * 0.76, height: geometry.size.height * 0.68)
                    NativeMaterialLayer(model: model, size: size, scale: displayScale)
                    .frame(width: size.width, height: size.height)
                    .overlay {
                        RoundedRectangle(cornerRadius: min(24, size.width * 0.1))
                            .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                    }
                    .overlay {
                        VStack(spacing: 4) {
                            Text("Material").font(.headline)
                            #if !os(watchOS)
                            Text("Live background sampling").font(.subheadline)
                            #endif
                        }
                        .foregroundStyle(model.document?.name.lowercased().contains("dark") == true ? .white : .black)
                        .padding()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Material preview")
        .accessibilityValue(model.effectEnabled ? "Effect enabled" : "Effect disabled")
    }
}

private struct NativeMaterialLayer: View {
    @ObservedObject var model: ViewerModel
    let size: CGSize
    let scale: CGFloat

    var body: some View {
        #if os(watchOS)
        makeLayerView(MRMaterialRenderer.previewLayerClass)
        #else
        _CALayerView(type: CALayer.self, onUpdate: update)
        #endif
    }

    #if os(watchOS)
    private func makeLayerView<Layer: AnyObject>(_ type: Layer.Type) -> AnyView {
        // Open the runtime metatype so SwiftUI sees CALayer, rather than the NSObject superclass.
        AnyView(_CALayerView(type: type) { update($0 as! NSObject) })
    }
    #endif

    private func update(_ container: NSObject) {
        do {
            try model.session?.renderer.attach(toLayer: container, size: size, scale: scale)
            Task { @MainActor in model.refreshSnapshot() }
        } catch {
            let message = error.localizedDescription
            Task { @MainActor in
                if model.error != message { model.error = message }
            }
        }
    }
}

private struct Backdrop: View {
    let grid: Bool
    let phase: TimeInterval

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            let gradient = Gradient(colors: grid ? [.white, .gray] : [Color(red: 0.09, green: 0.19, blue: 0.35), Color(red: 0.24, green: 0.42, blue: 0.65)])
            context.fill(Path(bounds), with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            if !grid {
                let colors: [Color] = [.orange, .pink, .teal, .indigo, .yellow]
                let positions: [(CGFloat, CGFloat, CGFloat)] = [(0.18, 0.82, 0.60), (0.7, 0.3, 0.55), (0.82, 0.83, 0.58), (0.15, 0.15, 0.48), (0.48, 0.45, 0.26)]
                for (index, position) in positions.enumerated() {
                    let (x, y, fraction) = position
                    let side = size.width * fraction
                    let movement = index == 0 && phase != 0 ? sin(phase * .pi / 3) * size.width * 0.2 : 0
                    let rect = CGRect(x: size.width * x - side / 2 + movement, y: size.height * y - side / 2, width: side, height: side)
                    let path = index.isMultiple(of: 2) ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 24)
                    context.fill(path, with: .color(colors[index]))
                }
            }
            var lines = Path()
            for x in stride(from: CGFloat.zero, through: size.width, by: 18) {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: 18) {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(.black.opacity(grid ? 0.65 : 0.18)), lineWidth: grid ? 2 : 1)
            let text = Text("Aa 0123456789\nMATERIAL / BACKDROP\nAa 0123456789")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(grid ? .black : .white)
            context.draw(text, at: CGPoint(x: size.width / 2, y: size.height / 2))
        }
        .accessibilityHidden(true)
    }
}
