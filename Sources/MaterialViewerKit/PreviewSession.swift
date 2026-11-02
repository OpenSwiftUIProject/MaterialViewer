import MaterialRuntime

@MainActor
public final class PreviewSession {
    public let bundle: PreviewBundle
    public let renderer: MRMaterialRenderer

    public init(document: RecipeDocument) throws {
        bundle = try PreviewBundle(document: document)
        renderer = try MRMaterialRenderer(recipeName: bundle.recipeName, bundleURL: bundle.url)
    }
}
