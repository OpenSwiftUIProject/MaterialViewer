# MaterialViewer

Inspect CoreMaterial recipes as source and resolved JSON, and preview their base
material with the native system renderer. The Layer tab shows live filters and
inputs; preview controls adjust weight, transparency, and the background.

![MaterialViewer showing layer JSON and a live material preview](Screenshots/mac_app.png)

## Requirements

macOS 14, iOS 17, watchOS 10, or visionOS 1 and later. Building requires Xcode
with Swift 6.3 or later. Rendering uses the system's private CoreMaterial
framework, so results can vary between OS versions.

## App

Open [MaterialViewer.xcodeproj](MaterialViewer.xcodeproj). Use `MaterialViewer`
for Mac, iPhone, iPad, or Apple Vision Pro, and `MaterialViewer Watch` for the
standalone Apple Watch app. On macOS, you can also use:

```sh
./run.sh
./run.sh /path/to/example.materialrecipe
```

The app opens the running system's CoreMaterial resources by default.
Use the sidebar to browse recipes and **JSON** to inspect source, resolved
values, and live layers. **Open** can select files and folders on macOS, iOS,
and visionOS; watchOS browses the system resources.
Set your signing team in [common.xcconfig](xcconfigs/common.xcconfig) if needed.

## CLI

```sh
swift run materialviewer --check
swift run materialviewer --check /path/to/example.materialrecipe
```

`--check` prints layer JSON for each recipe and a summary, and exits with a
nonzero status on failures. With no input path, it checks the system framework.
Without arguments, the CLI prints help and exits.

The macOS app includes an independent CLI at `Contents/Helpers/materialviewer`.
You can copy that binary and run it outside the app. Other platforms do not
build or embed the CLI.

See [AGENTS.md](AGENTS.md) for project structure, build details, and validation.

## License

[MIT License](LICENSE).
