import Foundation

public struct RecipeError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

public struct RecipeDocument {
    public static let systemFrameworkURL = URL(
        fileURLWithPath: "/System/Library/PrivateFrameworks/CoreMaterial.framework/", isDirectory: true
    )

    public let url: URL
    public let source: [String: Any]
    public let resolved: [String: Any]
    public let styleSets: [String: Any]
    public let warnings: [String]
    public let formatName: String
    public let sourceJSON: String
    public let resolvedJSON: String
    public var name: String { url.deletingPathExtension().lastPathComponent }

    public init(url: URL) throws {
        let url = url.standardizedFileURL.resolvingSymlinksInPath()
        self.url = url
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard let source = try PropertyListSerialization.propertyList(from: data, format: &format) as? [String: Any] else {
            throw RecipeError("The property list must contain a dictionary.")
        }
        self.source = source
        formatName = format == .binary ? "Binary plist" : "XML plist"
        let resolved = try Self.resolve(url, kind: .recipe, visited: [])
        guard let version = resolved["materialSettingsVersion"] as? Int, version == 2 else {
            throw RecipeError("This viewer supports materialSettingsVersion 2.")
        }
        guard resolved["baseMaterial"] is [String: Any] else {
            throw RecipeError("The recipe has no baseMaterial dictionary.")
        }
        self.resolved = resolved
        var styleSets: [String: Any] = [:]
        var warnings: [String] = []
        if let styles = resolved["styles"] as? [String: String] {
            for name in Set(styles.values).sorted() {
                do {
                    let styleURL = try Self.resource(named: name, in: url.deletingLastPathComponent(), kind: .style)
                    styleSets[name] = try Self.resolve(styleURL, kind: .style, visited: [])
                } catch {
                    warnings.append("\(name): \(error.localizedDescription)")
                }
            }
        }
        self.styleSets = styleSets
        self.warnings = warnings
        sourceJSON = try Self.json(source)
        resolvedJSON = try Self.json(["material": resolved, "styleSets": styleSets, "warnings": warnings])
    }

    public static func recipes(in directory: URL) throws -> [URL] {
        let resources = directory.appendingPathComponent("Resources")
        var isDirectory: ObjCBool = false
        let hasResources = FileManager.default.fileExists(atPath: resources.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        let resourceDirectory = (hasResources ? resources : directory).resolvingSymlinksInPath()
        return try FileManager.default.contentsOfDirectory(at: resourceDirectory,
                                                           includingPropertiesForKeys: [.isRegularFileKey])
            .filter { ["materialrecipe", "descendantrecipe"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public static func json(_ value: Any) throws -> String {
        guard JSONSerialization.isValidJSONObject(value) else {
            throw RecipeError("The property list contains values that JSON cannot represent.")
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }

    private enum ResourceKind {
        case recipe, style
        var baseExtension: String { self == .recipe ? "materialrecipe" : "visualstyleset" }
        var childExtension: String { self == .recipe ? "descendantrecipe" : "descendantstyleset" }
        var ancestorKey: String { self == .recipe ? "ancestorRecipe" : "ancestorStyleSet" }
    }

    private static func resource(named name: String, in directory: URL, kind: ResourceKind) throws -> URL {
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else {
            throw RecipeError("Invalid resource name: \(name)")
        }
        for suffix in [kind.baseExtension, kind.childExtension] {
            let url = directory.appendingPathComponent(name).appendingPathExtension(suffix)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        throw RecipeError("Resource not found: \(name)")
    }

    private static func resolve(_ url: URL, kind: ResourceKind, visited: Set<URL>) throws -> [String: Any] {
        let url = url.resolvingSymlinksInPath()
        guard !visited.contains(url) else { throw RecipeError("Inheritance cycle at \(url.lastPathComponent).") }
        guard let dictionary = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any] else {
            throw RecipeError("Invalid property list: \(url.lastPathComponent)")
        }
        guard url.pathExtension == kind.childExtension else { return dictionary }
        guard let ancestor = dictionary[kind.ancestorKey] as? String,
              let overrides = dictionary["descendantDescription"] as? [String: Any] else {
            throw RecipeError("Invalid descendant resource: \(url.lastPathComponent)")
        }
        let ancestorURL = try resource(named: ancestor, in: url.deletingLastPathComponent(), kind: kind)
        let base = try resolve(ancestorURL, kind: kind, visited: visited.union([url]))
        return merge(base, overrides)
    }

    private static func merge(_ base: [String: Any], _ overrides: [String: Any]) -> [String: Any] {
        var result = base
        for (key, value) in overrides {
            if let original = result[key] as? [String: Any], let replacement = value as? [String: Any] {
                result[key] = merge(original, replacement)
            } else {
                result[key] = value
            }
        }
        return result
    }
}
