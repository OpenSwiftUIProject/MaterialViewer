import SwiftUI
import MaterialViewerKit

struct MaterialViewerApplication: App {
    var body: some Scene {
        WindowGroup("MaterialViewer") {
            ViewerRoot()
        }
        #if os(macOS) || os(visionOS)
        .defaultSize(width: 1280, height: 820)
        #endif
        #if os(macOS)
        .commands { ViewerCommands() }
        #endif
    }
}

private struct ViewerRoot: View {
    @StateObject private var model = ViewerModel(options: Launcher.options)

    var body: some View {
        Viewer(model: model)
            .task { model.openInitialInput() }
            .onOpenURL { model.open($0) }
            #if os(macOS)
            .frame(minWidth: 760, minHeight: 560)
            .focusedSceneValue(\.viewerModel, model)
            #endif
    }
}

#if os(macOS)
private struct ViewerModelKey: FocusedValueKey {
    typealias Value = ViewerModel
}

extension FocusedValues {
    var viewerModel: ViewerModel? {
        get { self[ViewerModelKey.self] }
        set { self[ViewerModelKey.self] = newValue }
    }
}

private struct ViewerCommands: Commands {
    @FocusedValue(\.viewerModel) private var model

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…", systemImage: "folder") { model?.importPresented = true }
                .keyboardShortcut("o")
                .disabled(model == nil)
            Button("Open System Materials") { model?.open(RecipeDocument.systemFrameworkURL) }
                .disabled(model == nil)
            Divider()
            Button("Reload", systemImage: "arrow.clockwise") { model?.load(model?.selection) }
                .keyboardShortcut("r")
                .disabled(model?.selection == nil)
        }
    }
}
#endif

struct LaunchOptions {
    var input: URL?
    var effectEnabled = true
    var grid = false
    var layerJSON = false
}

@main
enum Launcher {
    @MainActor static var options = LaunchOptions()

    @MainActor
    static func main() {
        var arguments: [String] = []
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            // Cocoa consumes single-dash key/value pairs as launch-time preferences.
            if argument.count > 1, argument.hasPrefix("-"), !argument.hasPrefix("--") {
                guard iterator.next() != nil else {
                    fputs("Missing value for preference: \(argument)\n", stderr)
                    exit(1)
                }
            } else {
                arguments.append(argument)
            }
        }
        if arguments.contains("--help") {
            print("""
            Usage: MaterialViewer [recipe-or-folder]
            Default input: /System/Library/PrivateFrameworks/CoreMaterial.framework/
            Preview options: --effect-off --grid --layer-json
            """)
            return
        }
        for argument in arguments {
            switch argument {
            case "--effect-off": options.effectEnabled = false
            case "--grid": options.grid = true
            case "--layer-json": options.layerJSON = true
            default:
                guard !argument.hasPrefix("-"), options.input == nil else {
                    fputs("Unexpected argument: \(argument)\n", stderr)
                    exit(1)
                }
                options.input = URL(fileURLWithPath: argument).standardizedFileURL
            }
        }
        MaterialViewerApplication.main()
    }
}
