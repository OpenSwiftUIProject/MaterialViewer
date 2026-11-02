# MaterialViewer Agent Guidance

## Scope and layout

- Use the current checkout. Check Git status before edits and preserve unrelated
  changes. Write code, comments, and documentation in English.
- Keep [README.md](README.md) focused on features, requirements, and quick use.
  Put implementation constraints and maintenance details in this file.
- [Package.swift](Package.swift) uses Swift tools 6.3 and targets macOS 14 or later.
  It provides the `MaterialViewerKit` library and `materialviewer` executable.
- `Sources/MaterialViewerKit` handles recipe parsing, resource resolution, and
  preview sessions. `Sources/MaterialRuntime` provides the Objective-C bridge to
  native CoreMaterial. `Sources/MaterialViewerCLI` contains the CLI entry point.
- `App/MaterialViewer` contains the app. The native Xcode project uses the local
  package at the repository root. Do not introduce Tuist or XcodeGen.
- Keep screenshots in `Screenshots/`. Store only optimized images there and
  preserve originals outside the repository. The project uses [MIT](LICENSE).

## Xcode and packaging

- The app target and Swift module are `MaterialViewerApp`; the product is
  `MaterialViewer.app`. Keep target and module names distinct from `materialviewer`
  even when compared without case. Otherwise the default macOS file system can
  merge their build directories and overwrite compiler output maps.
- Only `MaterialViewerKit` belongs in the app's `packageProductDependencies` and
  Link Binary With Libraries phase. Build the CLI through `PBXTargetDependency`
  and embed its product with a Copy Files phase and Code Sign on Copy. Adding the
  executable to the app's package product list can make Xcode convert shared
  targets to dynamic frameworks, which prevents standalone CLI use.
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

## Behavior to preserve

- Both the app and `--check` default to
  `/System/Library/PrivateFrameworks/CoreMaterial.framework/`. Explicit input
  paths take priority. Do not embed Apple recipe resources or hard-code an
  artifact archive path.
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
preservation, and temporary bundle cleanup. The CLI smoke check requires Python
3. It copies the binary to a temporary directory, checks help and error exit
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
