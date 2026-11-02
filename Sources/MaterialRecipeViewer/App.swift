import AppKit
import SwiftUI
import RecipeKit
import MaterialRuntime

@MainActor
final class PreviewSession {
    let bundle: PreviewBundle
    let renderer: MRMaterialRenderer

    init(document: RecipeDocument) throws {
        bundle = try PreviewBundle(document: document)
        renderer = try MRMaterialRenderer(recipeName: bundle.recipeName, bundleURL: bundle.url)
    }
}

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
    @Published var effectEnabled = true
    @Published var background = "Colors"
    @Published var animated = false
    private(set) var directory: URL?

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

    func open(_ url: URL) {
        do {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                throw RecipeError("File not found: \(url.path)")
            }
            let directory = isDirectory.boolValue ? url : url.deletingLastPathComponent()
            let files = try RecipeDocument.recipes(in: directory)
            guard !files.isEmpty else { throw RecipeError("This folder contains no material recipes.") }
            self.directory = files[0].deletingLastPathComponent()
            self.files = files
            let selected = isDirectory.boolValue
                ? files.first(where: { $0.lastPathComponent == "platformContentLight.materialrecipe" }) ?? files[0]
                : url
            selection = selected
            load(selected)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func load(_ url: URL?) {
        guard let url else { return }
        document = nil
        session = nil
        layerJSON = "{}"
        do {
            let document = try RecipeDocument(url: url)
            self.document = document
            session = nil
            layerJSON = "{}"
            self.error = nil
            session = try PreviewSession(document: document)
            configure()
        } catch {
            session = nil
            self.error = error.localizedDescription
        }
    }

    func configure() {
        guard let session else { return }
        do {
            try session.renderer.configure(withWeight: weight, reduceTransparency: reduceTransparency)
            session.renderer.layer.opacity = effectEnabled ? 1 : 0
            refreshSnapshot()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshSnapshot() {
        guard let session else { return }
        do { layerJSON = try RecipeDocument.json(session.renderer.layerSnapshot()) }
        catch { self.error = error.localizedDescription }
    }

    func chooseInput() {
        let panel = NSOpenPanel()
        panel.title = "Open a recipe or resource folder"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = directory
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }

    func copyJSON() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(displayedJSON, forType: .string)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = ViewerModel()
    var window: NSWindow!
    let input: URL

    init(input: URL, effectEnabled: Bool, grid: Bool, layerJSON: Bool) {
        self.input = input
        model.effectEnabled = effectEnabled
        model.background = grid ? "Grid" : "Colors"
        model.jsonMode = layerJSON ? "Layer" : "Source"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu()
        applicationMenu.addItem(withTitle: "Quit Material Recipe Viewer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        menu.addItem(applicationItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(openInput), keyEquivalent: "o").target = self
        fileMenu.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "r").target = self
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)
        NSApp.mainMenu = menu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1360, height: 850),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Material Recipe Viewer"
        window.minSize = NSSize(width: 1120, height: 700)
        window.contentView = NSHostingView(rootView: Viewer(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.open(input)
    }

    @objc func openInput() { model.chooseInput() }
    @objc func reload() { model.load(model.selection) }
    func applicationWillTerminate(_ notification: Notification) { model.session?.bundle.cleanup() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
enum Launcher {
    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--help") {
            print("""
            Usage: MaterialRecipeViewer [recipe-or-folder]
                   MaterialRecipeViewer --check [recipe-or-folder]
            Default input: /System/Library/PrivateFrameworks/CoreMaterial.framework/
            Preview options: --effect-off --grid --layer-json
            """)
            return
        }
        var provided: String?
        for argument in arguments {
            if ["--check", "--effect-off", "--grid", "--layer-json"].contains(argument) {
                continue
            } else if !argument.hasPrefix("-"), provided == nil {
                provided = argument
            } else {
                fputs("Unexpected argument: \(argument)\n", stderr)
                exit(1)
            }
        }
        let input = provided.map { URL(fileURLWithPath: $0).standardizedFileURL }
            ?? URL(fileURLWithPath: "/System/Library/PrivateFrameworks/CoreMaterial.framework/", isDirectory: true)
        if arguments.contains("--check") {
            exit(check(input))
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate(input: input,
                                   effectEnabled: !arguments.contains("--effect-off"),
                                   grid: arguments.contains("--grid"), layerJSON: arguments.contains("--layer-json"))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    @MainActor
    static func check(_ input: URL) -> Int32 {
        do {
            var directory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: input.path, isDirectory: &directory) else {
                throw RecipeError("File not found: \(input.path)")
            }
            let files = directory.boolValue ? try RecipeDocument.recipes(in: input) : [input]
            guard !files.isEmpty else { throw RecipeError("No material recipes found.") }
            var failures = 0
            for file in files {
                do {
                    let document = try RecipeDocument(url: file)
                    let session = try PreviewSession(document: document)
                    let snapshot = try session.renderer.layerSnapshot()
                    try session.renderer.configure(withWeight: 0.25, reduceTransparency: true)
                    let adjusted = try session.renderer.layerSnapshot()
                    guard (adjusted["weighting"] as? NSNumber)?.doubleValue == 0.25,
                          (adjusted["isReduceTransparencyEnabled"] as? NSNumber)?.boolValue == true else {
                        throw RecipeError("The renderer did not apply the requested settings.")
                    }
                    let report: [String: Any] = ["file": file.lastPathComponent, "layer": snapshot, "warnings": document.warnings]
                    print(try RecipeDocument.json(report))
                    if !document.warnings.isEmpty { failures += 1 }
                } catch {
                    failures += 1
                    fputs("FAIL \(file.lastPathComponent): \(error.localizedDescription)\n", stderr)
                }
            }
            print("Checked \(files.count) recipes; \(failures) failures.")
            return failures == 0 ? 0 : 1
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            return 1
        }
    }
}
