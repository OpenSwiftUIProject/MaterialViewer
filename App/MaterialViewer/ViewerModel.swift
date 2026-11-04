import Foundation
import SwiftUI
import MaterialViewerKit
#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS)
import UIKit
#endif

@MainActor
final class ViewerModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var selection: URL?
    @Published var document: RecipeDocument?
    @Published var session: PreviewSession?
    @Published var error: String?
    @Published var search = ""
    @Published var jsonMode = "Source"
    @Published var layerJSON = "{}"
    @Published var weight = 1.0
    @Published var reduceTransparency = false
    @Published var effectEnabled: Bool
    @Published var background: String
    @Published var animated = false
    @Published var importPresented = false
    @Published var inspectorPresented: Bool
    private let initialInput: URL?
    private var didOpenInitialInput = false
    private var scopedURL: URL?

    init(options: LaunchOptions) {
        initialInput = options.input
        effectEnabled = options.effectEnabled
        background = options.grid ? "Grid" : "Colors"
        jsonMode = options.layerJSON ? "Layer" : "Source"
        #if os(macOS) || os(visionOS)
        inspectorPresented = true
        #else
        inspectorPresented = options.layerJSON
        #endif
    }

    var filteredFiles: [URL] {
        files.filter { search.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(search) }
    }

    var displayedJSON: String {
        switch jsonMode {
        case "Resolved": return document?.resolvedJSON ?? "{}"
        case "Layer": return layerJSON
        default: return document?.sourceJSON ?? "{}"
        }
    }

    func openInitialInput() {
        guard !didOpenInitialInput else { return }
        didOpenInitialInput = true
        open(initialInput ?? RecipeDocument.systemFrameworkURL)
    }

    func open(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        do {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                throw RecipeError("File not found: \(url.path)")
            }
            let files = isDirectory.boolValue
                ? try RecipeDocument.recipes(in: url)
                : [url.resolvingSymlinksInPath()]
            guard !files.isEmpty else { throw RecipeError("This folder contains no material recipes.") }
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = accessing ? url : nil
            self.files = files
            selection = isDirectory.boolValue
                ? files.first(where: { $0.lastPathComponent == "platformContentLight.materialrecipe" }) ?? files[0]
                : url.resolvingSymlinksInPath()
            load(selection)
        } catch {
            if accessing { url.stopAccessingSecurityScopedResource() }
            self.error = error.localizedDescription
        }
    }

    func load(_ url: URL?) {
        document = nil
        session = nil
        layerJSON = "{}"
        error = nil
        guard let url else { return }
        do {
            let document = try RecipeDocument(url: url)
            self.document = document
            session = try PreviewSession(document: document)
            configure()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func configure() {
        guard let session else { return }
        do {
            try session.renderer.configure(withWeight: weight, reduceTransparency: reduceTransparency)
            session.renderer.effectEnabled = effectEnabled
            refreshSnapshot()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshSnapshot() {
        guard let session else { return }
        do {
            let json = try RecipeDocument.json(session.renderer.layerSnapshot())
            if json != layerJSON { layerJSON = json }
        } catch {
            self.error = error.localizedDescription
        }
    }

    #if !os(watchOS)
    func copyJSON() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayedJSON, forType: .string)
        #else
        UIPasteboard.general.string = displayedJSON
        #endif
    }
    #endif

    deinit { scopedURL?.stopAccessingSecurityScopedResource() }
}
