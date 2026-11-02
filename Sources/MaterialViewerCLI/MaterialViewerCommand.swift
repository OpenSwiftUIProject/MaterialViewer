import Foundation
import MaterialViewerKit

@main
enum MaterialViewerCommand {
    static let usage = """
    Usage: materialviewer --check [recipe-or-folder]
           materialviewer --help
    Default input: /System/Library/PrivateFrameworks/CoreMaterial.framework/
    --check prints layer JSON and a summary without opening a window.
    """

    @MainActor
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty || arguments == ["--help"] || arguments == ["-h"] {
            print(usage)
            return
        }
        guard arguments.first == "--check", arguments.count <= 2,
              arguments.count == 1 || !arguments[1].hasPrefix("-") else {
            fputs("Invalid arguments.\n\(usage)\n", stderr)
            exit(2)
        }
        let input = arguments.dropFirst().first.map { URL(fileURLWithPath: $0).standardizedFileURL }
            ?? RecipeDocument.systemFrameworkURL
        exit(check(input))
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
