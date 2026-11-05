# MaterialViewer Agent Guidance

## Scope and layout

- Use the current checkout. Check Git status before edits and preserve unrelated
  changes. Write code, comments, and documentation in English.
- Keep [README.md](README.md) focused on features, requirements, and quick use.
  Put implementation constraints and maintenance details in this file.
- [Package.swift](Package.swift) uses Swift tools 6.3. The library supports
  macOS 14, iOS 17, watchOS 10, and visionOS 1 or later. The macOS executable
  product is `materialviewer`.
- `Sources/MaterialViewerKit` handles recipe parsing, resource resolution, and
  preview sessions. `Sources/MaterialRuntime` provides the Objective-C bridge to
  native CoreMaterial. `Sources/MaterialViewerCLI` contains the CLI entry point.
- `App/MaterialViewer` contains the shared SwiftUI app, model, navigation, JSON
  inspector, and preview. The native Xcode project uses the local package at
  the repository root. Do not introduce Tuist or XcodeGen.
- Keep screenshots in `Screenshots/`. Store only optimized images there and
  preserve originals outside the repository. The project uses [MIT](LICENSE).

## Xcode and packaging

- The app target and Swift module are `MaterialViewerApp`; the product is
  `MaterialViewer.app`. Keep target and module names distinct from `materialviewer`
  even when compared without case. Otherwise the default macOS file system can
  merge their build directories and overwrite compiler output maps.
- `MaterialViewerApp` supports macOS, iOS, and visionOS. The standalone
  `MaterialViewerWatchApp` target shares the same sources and library. Its scheme
  is `MaterialViewer Watch`, product is `MaterialViewerWatch.app`, and bundle ID
  is `org.OpenSwiftUIProject.MaterialViewer.watchkitapp`. Use `WKWatchOnly` for
  this target; do not also set `WKRunsIndependentlyOfCompanionApp`.
- Only `MaterialViewerKit` belongs in the app's `packageProductDependencies` and
  Link Binary With Libraries phase. Build the CLI through `PBXTargetDependency`
  and embed its product with a Copy Files phase and Code Sign on Copy. Adding the
  executable to the app's package product list can make Xcode convert shared
  targets to dynamic frameworks, which prevents standalone CLI use.
- Both the CLI target dependency and its Copy Files entry use
  `platformFilters = (macos, );`. Verify the build graph and installed bundles:
  iOS, visionOS, and watchOS must neither build nor contain `materialviewer`.
- Preserve the separate entry points and bundle layout:

  ```text
  MaterialViewer.app/
    Contents/
      MacOS/MaterialViewer
      Helpers/materialviewer
  ```

- `build.sh` must only invoke `xcodebuild`. The project handles compilation,
  embedding, and signing. Do not add script-based bundle assembly or signing.
- Keep build settings in `xcconfigs`. Signing defaults to Automatic with team
  `VB7MJ8R223`; the bundle ID is `org.OpenSwiftUIProject.MaterialViewer`.
- Edit `App/MaterialViewer/AppIcon.icon` with Xcode Icon Composer. Its three SVG
  layers share the macOS, iOS, and watchOS icon; Xcode generates older OS assets.
  visionOS uses `Assets.xcassets/AppIconVision.solidimagestack` because it does not
  support Composer icons. Keep its 1024-pixel PNG layers in sync with the SVGs:
  Frost in front, Blue in the middle, and Violet over an opaque background in back.
  The visionOS SDK settings select this image stack and exclude the `.icon` file.
- Use `App` as the file system synchronized root so Xcode displays the actual
  `App/MaterialViewer` folder hierarchy. Keep shared schemes tracked. Ignore
  local IDE state and standard build directories; fix misplaced build outputs
  instead of adding ignore rules for individual compiler files.

## Build and run

```sh
./build.sh
CONFIGURATION=Debug ./build.sh
./build.sh DEVELOPMENT_TEAM=YOUR_TEAM_ID
./run.sh /path/to/CoreMaterial.framework
swift build -c release --product materialviewer
.build/release/materialviewer --check /path/to/CoreMaterial.framework
```

The script builds Release by default and writes the app to
`DerivedData/Build/Products/Release/MaterialViewer.app`. Debug uses the `Debug`
directory. The Xcode GUI uses its configured DerivedData location. `run.sh`
builds and opens the app. App startup flags are `--effect-off`, `--grid`, and
`--layer-json`.

The CLI can run without its app bundle or adjacent resources. SwiftPM does not
use the Xcode signing settings; copy `Contents/Helpers/materialviewer` from the
app when a development signature is required.

Select a simulator or device in Xcode for the other platforms. Simulator
runtimes must be installed for the selected Xcode version. Example builds:

```sh
xcodebuild -project MaterialViewer.xcodeproj -scheme MaterialViewer \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -project MaterialViewer.xcodeproj -scheme MaterialViewer \
  -destination 'generic/platform=visionOS Simulator' build
xcodebuild -project MaterialViewer.xcodeproj -scheme 'MaterialViewer Watch' \
  -destination 'generic/platform=watchOS Simulator' build
```

## Behavior to preserve

- Both the app and `--check` default to the running system's CoreMaterial
  framework. Resolve its resource location with `Bundle(for:)` after loading
  the framework, so a Simulator uses its own resources instead of the Mac's.
  The fallback is `/System/Library/PrivateFrameworks/CoreMaterial.framework/`.
  Explicit input paths take priority. Do not embed Apple recipe resources or
  hard-code an artifact archive path.
- Use SwiftUI app lifecycle, navigation, toolbars, and forms. Keep models local
  to each window because a material layer can have only one parent. Preserve
  Cocoa `-key value` launch preferences and the app's documented options.
- Keep security-scoped access active while browsing imported files and release
  it when replacing the source or closing the model. Do not enumerate the parent
  of an imported file; access is limited to the selected file. Select a folder
  to browse multiple recipes and their dependencies. watchOS uses system resources
  because it has no file importer.
- The CLI never starts the GUI. No arguments, `--help`, and `-h` print help and
  exit with status 0. Invalid arguments exit with status 2. `--check` prints a
  layer JSON report per recipe followed by a text summary; load errors or missing
  style resources produce status 1.
- Support binary and XML property lists with `materialSettingsVersion = 2`.
  Resolve `.descendantrecipe` and `.descendantstyleset` inheritance. Merge
  dictionaries recursively; replace arrays and scalar values. Resolve resource
  symlinks before enumeration and inheritance checks. Reject cycles, missing
  ancestors, and unsupported recipes before rendering.
- Load the host CoreMaterial framework with `dlopen`. Use
  `setRecipeName:fromBundle:` on `MTMaterialLayer` and pass weight and reduced
  transparency settings to the native implementation. Do not load Simulator
  binaries into the macOS process or use the sibling replacement framework.
- The preview applies `baseMaterial`. Fill and stroke styles are available in
  Resolved JSON but are not applied to the label or border. The label and border
  are viewer elements. Rendering can differ from the recipe's original OS.
- Use a temporary resource bundle and a unique recipe name for each preview to
  avoid stale native cache entries. Never modify source recipes. Remove temporary
  bundles when the session ends; forced process termination can leave them behind.
- Keep JSON available when native rendering fails. Report unavailable private
  interfaces without substituting another blur implementation.
- `_CALayerView` hosts the native layer over a SwiftUI backdrop on all platforms.
  On watchOS, open the runtime layer metatype before constructing the generic
  host; erasing it to `NSObject` makes SwiftUI reject the layer at runtime.
  Keep the watchOS Core Animation selectors in the Objective-C bridge because
  the watch SDK marks those types unavailable despite their runtime presence.

## Verification

Choose checks that match the change. For documentation-only changes, verify the
diff, relative links, and whitespace; do not build or generate artifacts.

```sh
swift test
swift run materialviewer --check
swift run materialviewer --check /path/to/CoreMaterial.framework
./build.sh
python3 Scripts/check-cli.py DerivedData/Build/Products/Release/MaterialViewer.app/Contents/Helpers/materialviewer
codesign --verify --deep --strict DerivedData/Build/Products/Release/MaterialViewer.app
```

Tests cover resource discovery, binary/XML decoding, inheritance, array
replacement, missing ancestors, cycles, unsupported versions, source
preservation, temporary bundle cleanup, layer attachment, effect state, and layer
removal when a session ends. The CLI smoke check requires Python 3. It copies the
binary to a temporary directory, checks help and error exit
codes, and loads system recipes without the app bundle or build directory.

For project changes, also build in the Xcode GUI with its default DerivedData
location. A build on a case-sensitive workspace volume cannot detect every path
collision. Verify Archive when changing dependencies, embedding, or signing:

```sh
xcodebuild -project MaterialViewer.xcodeproj -scheme MaterialViewer \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath DerivedData/MaterialViewer.xcarchive archive
```

`--check` verifies native layer creation, weight, and reduced transparency; it
does not verify pixels. Inspect the live window with Effect on and off when
changing background sampling. Existing checks on macOS 26.6.2 (25G83), arm64,
covered 49 system recipes, 41 archived recipes, four resolved descendants, and
background sampling for `platformContentLight`. These checks do not establish
compatibility with every OS release.
