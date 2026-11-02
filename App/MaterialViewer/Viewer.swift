import AppKit
import SwiftUI

struct Viewer: View {
    @ObservedObject var model: ViewerModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "square.3.layers.3d").font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Material Recipe Viewer").font(.headline)
                    Text("CoreMaterial resources").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open…", systemImage: "folder") { model.chooseInput() }
                Button("Reload", systemImage: "arrow.clockwise") { model.load(model.selection) }
                    .disabled(model.selection == nil)
            }
            .padding(16)
            Divider()
            HSplitView {
                sidebar.frame(minWidth: 210, idealWidth: 260, maxWidth: 350)
                inspector.frame(minWidth: 360, idealWidth: 460)
                preview.frame(minWidth: 440, idealWidth: 600)
            }
            HStack {
                Text(model.document?.url.path ?? "Open a recipe to begin")
                    .lineLimit(1).truncationMode(.middle).help(model.document?.url.path ?? "")
                Spacer()
                Text("Read only").foregroundStyle(.secondary)
            }
            .font(.caption).padding(.horizontal, 16).padding(.vertical, 8)
        }
        .onChange(of: model.selection) { _, url in
            if url != model.document?.url { model.load(url) }
        }
        .onChange(of: model.weight) { model.configure() }
        .onChange(of: model.reduceTransparency) { model.configure() }
        .onChange(of: model.effectEnabled) { model.configure() }
        .onChange(of: model.jsonMode) { model.refreshSnapshot() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Filter recipes", text: $model.search)
                .textFieldStyle(.roundedBorder).padding(12)
            Text("\(model.filteredFiles.count) RECIPES")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.bottom, 6)
            ScrollViewReader { proxy in
                List(model.filteredFiles, id: \.self, selection: $model.selection) { url in
                    HStack(spacing: 6) {
                        Image(systemName: url.pathExtension == "descendantrecipe" ? "arrow.turn.down.right" : "square.stack.3d.up")
                            .foregroundStyle(.secondary)
                        Text(url.deletingPathExtension().lastPathComponent).font(.system(size: 12))
                            .lineLimit(1).help(url.lastPathComponent)
                    }
                    .padding(.vertical, 3).tag(url).id(url)
                }
                .listStyle(.sidebar)
                .onChange(of: model.selection) { _, selection in
                    if let selection { proxy.scrollTo(selection, anchor: .center) }
                }
            }
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("JSON").font(.headline)
                Spacer()
                Text(model.document?.formatName ?? "").font(.caption).foregroundStyle(.secondary)
                Button { model.copyJSON() } label: { Image(systemName: "doc.on.doc") }
                    .help("Copy displayed JSON").accessibilityLabel("Copy JSON")
            }
            Picker("JSON content", selection: $model.jsonMode) {
                Text("Source").tag("Source")
                Text("Resolved").tag("Resolved")
                Text("Layer").tag("Layer")
            }
            .pickerStyle(.segmented)
            JSONTextView(text: model.displayedJSON)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            Text(jsonCaption).font(.caption).foregroundStyle(.secondary).frame(height: 32, alignment: .topLeading)
        }
        .padding(16)
    }

    private var jsonCaption: String {
        switch model.jsonMode {
        case "Resolved": return "Inherited values and referenced style sets. Arrays replace inherited arrays."
        case "Layer": return "Live layer tree and filter inputs from the current macOS renderer."
        default: return "Original property list decoded as JSON. Source files stay unchanged."
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Live layer").font(.headline)
                Spacer()
                if model.session != nil {
                    Label("MTMaterialLayer", systemImage: "circle.fill")
                        .font(.caption).foregroundStyle(.green)
                }
            }
            Text(model.document?.name ?? "No recipe selected")
                .font(.system(.title3, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
                .textSelection(.enabled)
            ZStack {
                if let session = model.session {
                    MaterialPreview(session: session, background: model.background, animated: model.animated,
                                    darkText: !(model.document?.name.lowercased().contains("dark") ?? false)) {
                        model.refreshSnapshot()
                    }
                } else {
                    ContentUnavailableView("Preview unavailable", systemImage: "square.3.layers.3d",
                                           description: Text(model.error ?? "Choose a material recipe."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary))
            HStack {
                Picker("Backdrop", selection: $model.background) {
                    Text("Colors").tag("Colors")
                    Text("Grid").tag("Grid")
                }.pickerStyle(.segmented).frame(width: 180)
                Spacer()
                Toggle("Animate", isOn: $model.animated).toggleStyle(.checkbox)
            }
            HStack {
                Toggle("Effect", isOn: $model.effectEnabled).toggleStyle(.switch)
                Spacer()
                Toggle("Reduce transparency", isOn: $model.reduceTransparency).toggleStyle(.checkbox)
            }
            HStack(spacing: 12) {
                Text("Weight").font(.callout)
                Slider(value: $model.weight, in: 0...1)
                Text(model.weight, format: .number.precision(.fractionLength(2)))
                    .font(.system(.callout, design: .monospaced)).frame(width: 38)
            }
            if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            if let warnings = model.document?.warnings, !warnings.isEmpty {
                Text(warnings.joined(separator: "\n")).font(.caption).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Base material preview. Fill and stroke styles are available in Resolved JSON.")
                Text(model.session?.renderer.runtimeDescription ?? "Open a recipe to inspect the host renderer.")
                Text("The host renderer can differ from the recipe's original OS.")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

struct JSONTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        let view = NSTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = false
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textColor = .labelColor
        view.backgroundColor = .textBackgroundColor
        view.textContainerInset = NSSize(width: 12, height: 12)
        view.isHorizontallyResizable = true
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
        view.maxSize = NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text
        view.scrollToBeginningOfDocument(nil)
    }
}
