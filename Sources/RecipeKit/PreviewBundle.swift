import Foundation

public final class PreviewBundle {
    public let url: URL
    public let recipeName: String

    public init(document: RecipeDocument) throws {
        let identifier = UUID().uuidString
        recipeName = "preview-\(identifier)"
        url = FileManager.default.temporaryDirectory.appendingPathComponent("MaterialRecipeViewer-\(identifier).bundle")
        let manager = FileManager.default
        try manager.createDirectory(at: url, withIntermediateDirectories: true)
        do {
            let info = ["CFBundleIdentifier": "org.OpenSwiftUIProject.MaterialViewer.preview.\(identifier)", "CFBundlePackageType": "BNDL"]
            try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
                .write(to: url.appendingPathComponent("Info.plist"))
            // Unique names prevent CoreMaterial's shared settings cache from returning an old recipe.
            try PropertyListSerialization.data(fromPropertyList: document.resolved, format: .binary, options: 0)
                .write(to: url.appendingPathComponent(recipeName).appendingPathExtension("materialrecipe"))
            let resources = try manager.contentsOfDirectory(at: document.url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            for resource in resources where ["visualstyleset", "descendantstyleset"].contains(resource.pathExtension) {
                try manager.copyItem(at: resource, to: url.appendingPathComponent(resource.lastPathComponent))
            }
        } catch {
            try? manager.removeItem(at: url)
            throw error
        }
    }

    public func cleanup() { try? FileManager.default.removeItem(at: url) }

    deinit { cleanup() }
}
