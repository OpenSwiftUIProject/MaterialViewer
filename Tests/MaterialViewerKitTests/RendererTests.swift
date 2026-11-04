import Foundation
import XCTest
@testable import MaterialViewerKit

final class RendererTests: XCTestCase {
    @MainActor
    func testReleasingSessionRemovesItsLayer() throws {
        let files = try RecipeDocument.recipes(in: RecipeDocument.systemFrameworkURL)
        let url = try XCTUnwrap(files.first { $0.lastPathComponent == "platformContentLight.materialrecipe" })
        let document = try RecipeDocument(url: url)
        var host: NSObject?

        try autoreleasepool {
            let session = try PreviewSession(document: document)
            let layerClass = try XCTUnwrap(type(of: session.renderer).previewLayerClass as? NSObject.Type)
            let container = layerClass.init()
            host = container
            try session.renderer.attach(toLayer: container, size: CGSize(width: 320, height: 240), scale: 2)
            XCTAssertEqual((container.value(forKey: "sublayers") as? [NSObject])?.count, 1)
        }

        XCTAssertTrue((host?.value(forKey: "sublayers") as? [NSObject] ?? []).isEmpty)
    }

    @MainActor
    func testLayerAttachmentAndEffectState() throws {
        let files = try RecipeDocument.recipes(in: RecipeDocument.systemFrameworkURL)
        let url = try XCTUnwrap(files.first { $0.lastPathComponent == "platformContentLight.materialrecipe" })
        let session = try PreviewSession(document: RecipeDocument(url: url))
        let renderer = session.renderer
        let layerClass = try XCTUnwrap(type(of: renderer).previewLayerClass as? NSObject.Type)
        let firstHost = layerClass.init()
        let secondHost = layerClass.init()

        try renderer.attach(toLayer: firstHost, size: CGSize(width: 320, height: 240), scale: 2)
        try renderer.configure(withWeight: 0.25, reduceTransparency: true)
        renderer.effectEnabled = false
        var snapshot = try renderer.layerSnapshot()
        XCTAssertEqual(snapshot["frame"] as? [Double], [0, 0, 320, 240])
        XCTAssertEqual(snapshot["opacity"] as? Double, 0)
        XCTAssertEqual(snapshot["weighting"] as? Double, 0.25)
        XCTAssertEqual(snapshot["isReduceTransparencyEnabled"] as? Bool, true)

        try renderer.attach(toLayer: secondHost, size: CGSize(width: 180, height: 120), scale: 2)
        renderer.effectEnabled = true
        snapshot = try renderer.layerSnapshot()
        XCTAssertEqual(snapshot["frame"] as? [Double], [0, 0, 180, 120])
        XCTAssertEqual(snapshot["opacity"] as? Double, 1)
        XCTAssertTrue((firstHost.value(forKey: "sublayers") as? [NSObject] ?? []).isEmpty)
        XCTAssertEqual((secondHost.value(forKey: "sublayers") as? [NSObject])?.count, 1)
    }
}
