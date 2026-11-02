import Foundation
import XCTest
@testable import RecipeKit

final class RecipeDocumentTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func write(_ name: String, _ value: Any, format: PropertyListSerialization.PropertyListFormat = .binary) throws -> URL {
        let url = directory.appendingPathComponent(name)
        let data = try PropertyListSerialization.data(fromPropertyList: value, format: format, options: 0)
        try data.write(to: url)
        return url
    }

    func testBinaryAndXMLHaveTheSameJSON() throws {
        let value: [String: Any] = [
            "materialSettingsVersion": 2,
            "baseMaterial": ["materialFiltering": ["blurRadius": 30, "blurAtEnd": true]]
        ]
        let binary = try RecipeDocument(url: write("binary.materialrecipe", value))
        let xml = try RecipeDocument(url: write("xml.materialrecipe", value, format: .xml))
        XCTAssertEqual(binary.sourceJSON, xml.sourceJSON)
        XCTAssertEqual(binary.formatName, "Binary plist")
        XCTAssertEqual(xml.formatName, "XML plist")
    }

    func testRecipeDiscoverySupportsFlatFoldersAndVersionedFrameworks() throws {
        let flat = try write("example.materialrecipe", ["materialSettingsVersion": 2, "baseMaterial": [:]])
        XCTAssertEqual(try RecipeDocument.recipes(in: directory).map(\.lastPathComponent), [flat.lastPathComponent])

        let framework = directory.appendingPathComponent("Example.framework")
        let resources = framework.appendingPathComponent("Versions/A/Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(atPath: framework.appendingPathComponent("Resources").path,
                                                  withDestinationPath: "Versions/A/Resources")
        let recipe = resources.appendingPathComponent("nested.materialrecipe")
        try FileManager.default.copyItem(at: flat, to: recipe)

        let discovered = try RecipeDocument.recipes(in: framework)
        XCTAssertEqual(discovered.map(\.lastPathComponent), [recipe.lastPathComponent])
        XCTAssertEqual(try RecipeDocument.recipes(in: resources).map(\.lastPathComponent), [recipe.lastPathComponent])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(discovered.first)), try Data(contentsOf: flat))

        let document = try RecipeDocument(url: framework.appendingPathComponent("Resources/nested.materialrecipe"))
        let preview = try PreviewBundle(document: document)
        defer { preview.cleanup() }
        let previewRecipe = preview.url.appendingPathComponent(preview.recipeName).appendingPathExtension("materialrecipe")
        XCTAssertEqual(try RecipeDocument(url: previewRecipe).resolvedJSON, document.resolvedJSON)
    }

    func testDescendantMergesDictionariesAndReplacesArrays() throws {
        _ = try write("base.materialrecipe", [
            "materialSettingsVersion": 2,
            "baseMaterial": ["materialFiltering": ["blurRadius": 30, "saturation": 1.5, "luminanceValues": [1, 2, 3, 4]]]
        ])
        let url = try write("child.descendantrecipe", [
            "ancestorRecipe": "base",
            "descendantDescription": ["baseMaterial": ["materialFiltering": ["blurRadius": 10, "luminanceValues": [4, 3, 2, 1]]]]
        ])
        let document = try RecipeDocument(url: url)
        let base = try XCTUnwrap(document.resolved["baseMaterial"] as? [String: Any])
        let filtering = try XCTUnwrap(base["materialFiltering"] as? [String: Any])
        XCTAssertEqual(filtering["blurRadius"] as? Int, 10)
        XCTAssertEqual(filtering["saturation"] as? Double, 1.5)
        XCTAssertEqual(filtering["luminanceValues"] as? [Int], [4, 3, 2, 1])
        XCTAssertEqual(document.resolved["materialSettingsVersion"] as? Int, 2)
    }

    func testCyclesAndMissingAncestorsFail() throws {
        let a = try write("a.descendantrecipe", ["ancestorRecipe": "b", "descendantDescription": [:]])
        _ = try write("b.descendantrecipe", ["ancestorRecipe": "a", "descendantDescription": [:]])
        XCTAssertThrowsError(try RecipeDocument(url: a))
        let missing = try write("missing.descendantrecipe", ["ancestorRecipe": "absent", "descendantDescription": [:]])
        XCTAssertThrowsError(try RecipeDocument(url: missing))
    }

    func testInvalidSchemaFailsBeforeRendering() throws {
        let url = try write("bad.materialrecipe", ["materialSettingsVersion": 99, "baseMaterial": [:]])
        XCTAssertThrowsError(try RecipeDocument(url: url))
    }

    func testPreviewBundlePreservesSourceAndIncludesStyleResources() throws {
        let style = try write("fill.visualstyleset", ["visualStyleSetVersion": 1, "styles": [:]])
        let url = try write("base.materialrecipe", [
            "materialSettingsVersion": 2,
            "baseMaterial": ["materialFiltering": ["blurRadius": 30]],
            "styles": ["fill": "fill"]
        ])
        let original = try Data(contentsOf: url)
        let document = try RecipeDocument(url: url)
        var preview: PreviewBundle? = try PreviewBundle(document: document)
        let bundleURL = try XCTUnwrap(preview?.url)
        XCTAssertNotEqual(bundleURL, directory)
        XCTAssertNotNil(Bundle(url: bundleURL))
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertEqual(try Data(contentsOf: bundleURL.appendingPathComponent(style.lastPathComponent)), try Data(contentsOf: style))
        preview = nil
        XCTAssertFalse(FileManager.default.fileExists(atPath: bundleURL.path))
    }
}
