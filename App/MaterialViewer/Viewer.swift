import SwiftUI
import UniformTypeIdentifiers
import MaterialViewerKit

struct Viewer: View {
    @ObservedObject var model: ViewerModel
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            sidebar
                .navigationTitle("Materials")
                .navigationSplitViewColumnWidth(min: 210, ideal: 260, max: 360)
                .searchable(text: $model.search, prompt: "Find a recipe")
                .toolbar {
                    #if !os(watchOS)
                    ToolbarItem {
                        Menu {
                            Button("Open…", systemImage: "folder") { model.importPresented = true }
                            Button("System Materials", systemImage: "square.3.layers.3d") {
                                model.open(RecipeDocument.systemFrameworkURL)
                            }
                        } label: {
                            Label("Open", systemImage: "folder")
                        }
                        .help("Open a recipe or folder")
                    }
                    #endif
                }
        } detail: {
            detail
                .navigationTitle(model.document?.name ?? "MaterialViewer")
                #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Reload", systemImage: "arrow.clockwise") { model.load(model.selection) }
                            .disabled(model.selection == nil)
                        #if !os(watchOS)
                        Button("JSON", systemImage: "curlybraces") { model.inspectorPresented.toggle() }
                            .help("Show JSON inspector")
                        #endif
                    }
                }
        }
        #if os(macOS) || os(iOS)
        .inspector(isPresented: $model.inspectorPresented) {
            JSONInspector(model: model)
                .inspectorColumnWidth(min: 280, ideal: 380, max: 640)
        }
        #endif
        #if !os(watchOS)
        .fileImporter(isPresented: $model.importPresented, allowedContentTypes: [.folder, .bundle, .data], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { model.open(url) }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        #endif
        .onChange(of: model.selection) { _, url in
            if url != model.document?.url { model.load(url) }
        }
        .onChange(of: model.weight) { model.configure() }
        .onChange(of: model.reduceTransparency) { model.configure() }
        .onChange(of: model.effectEnabled) { model.configure() }
        .onChange(of: model.jsonMode) { model.refreshSnapshot() }
    }

    @ViewBuilder
    private var detail: some View {
        #if os(visionOS)
        HStack(spacing: 0) {
            RecipeDetail(model: model)
            if model.inspectorPresented {
                Divider()
                JSONInspector(model: model).frame(width: 380)
            }
        }
        #else
        RecipeDetail(model: model)
        #endif
    }

    private var sidebar: some View {
        ScrollViewReader { proxy in
            List(selection: $model.selection) {
                Section("\(model.filteredFiles.count) recipes") {
                    ForEach(model.filteredFiles, id: \.self) { url in
                        NavigationLink(value: url) {
                            Label(url.deletingPathExtension().lastPathComponent,
                                  systemImage: url.pathExtension == "descendantrecipe" ? "arrow.turn.down.right" : "square.3.layers.3d")
                                .lineLimit(2)
                        }
                        .id(url)
                    }
                }
            }
            .onChange(of: model.selection, initial: true) { _, selection in
                if let selection { proxy.scrollTo(selection, anchor: .center) }
            }
        }
        .overlay {
            if model.filteredFiles.isEmpty {
                ContentUnavailableView(model.search.isEmpty ? "No Materials" : "No Results",
                                       systemImage: "square.3.layers.3d",
                                       description: Text(model.search.isEmpty ? model.error ?? "Open a recipe or resource folder." : "Try another recipe name."))
            }
        }
    }
}

private struct RecipeDetail: View {
    @ObservedObject var model: ViewerModel

    var body: some View {
        if let document = model.document {
            Form {
                Section {
                    if model.session != nil {
                        MaterialPreview(model: model)
                            #if os(watchOS)
                            .frame(height: 170)
                            #else
                            .aspectRatio(1.25, contentMode: .fit)
                            .frame(minHeight: 220, maxHeight: 520)
                            #endif
                            .listRowInsets(EdgeInsets())
                    } else {
                        ContentUnavailableView("Preview Unavailable", systemImage: "square.3.layers.3d",
                                               description: Text(model.error ?? "The renderer is unavailable on this system."))
                    }
                }
                #if os(watchOS)
                Section {
                    NavigationLink {
                        JSONInspector(model: model).navigationTitle("JSON")
                    } label: {
                        Label("JSON", systemImage: "curlybraces")
                    }
                }
                #endif
                Section("Preview") {
                    Picker("Background", selection: $model.background) {
                        Text("Colors").tag("Colors")
                        Text("Grid").tag("Grid")
                    }
                    Toggle("Animate", isOn: $model.animated)
                    Toggle("Effect", isOn: $model.effectEnabled)
                    Toggle("Reduce Transparency", isOn: $model.reduceTransparency)
                    VStack(alignment: .leading) {
                        LabeledContent("Weight", value: model.weight, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                        Slider(value: $model.weight, in: 0...1) { Text("Weight") }
                    }
                }
                .disabled(model.session == nil)
                if let error = model.error, model.session != nil {
                    Section("Preview Error") { Text(error).foregroundStyle(.red) }
                }
                if !document.warnings.isEmpty {
                    Section("Resource Warnings") {
                        ForEach(document.warnings, id: \.self) { Text($0) }
                    }
                }
                Section {
                    LabeledContent("Format", value: document.formatName)
                    #if os(watchOS)
                    NavigationLink("Details") {
                        List { metadata(document) }.navigationTitle("Details")
                    }
                    #else
                    DisclosureGroup("Details") {
                        metadata(document)
                    }
                    #endif
                }
            }
            #if !os(watchOS)
            .formStyle(.grouped)
            #endif
        } else {
            ContentUnavailableView("Select a Material", systemImage: "square.3.layers.3d",
                                   description: Text(model.error ?? "Choose a recipe from the sidebar to inspect its layers."))
        }
    }

    private func metadata(_ document: RecipeDocument) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(document.url.path)
            Text(model.session?.renderer.runtimeDescription ?? "Renderer unavailable")
            Text("Base material preview. Fill and stroke styles are available in Resolved JSON. Rendering uses the current system.")
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}

private struct JSONInspector: View {
    @ObservedObject var model: ViewerModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                #if !os(watchOS)
                HStack {
                    Text("JSON").font(.headline)
                    Spacer()
                    Button("Copy JSON", systemImage: "doc.on.doc") { model.copyJSON() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(model.document == nil)
                        .help("Copy displayed JSON")
                    ShareLink(item: model.displayedJSON) { Label("Share JSON", systemImage: "square.and.arrow.up") }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .disabled(model.document == nil)
                }
                #endif
                Picker("Content", selection: $model.jsonMode) {
                    Text("Source").tag("Source")
                    Text("Resolved").tag("Resolved")
                    Text("Layer").tag("Layer")
                }
                #if !os(watchOS)
                .pickerStyle(.segmented)
                #endif
            }
            .padding()
            Divider()
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Text(model.displayedJSON)
                        .font(.system(.caption, design: .monospaced))
                        #if !os(watchOS)
                        .textSelection(.enabled)
                        #endif
                        .fixedSize(horizontal: true, vertical: true)
                        .padding()
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
            #if !os(watchOS)
            Divider()
            Text(caption)
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            #endif
        }
    }

    private var caption: String {
        switch model.jsonMode {
        case "Resolved": return "Inherited values and referenced style sets."
        case "Layer": return "Live layer tree and filter inputs from the current renderer."
        default: return "Original property list. Source files stay unchanged."
        }
    }
}
