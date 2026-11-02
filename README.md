# Material Recipe Viewer

A macOS tool that reads CoreMaterial property lists and previews their base
material with a real `MTMaterialLayer`.

## Build and run the app

Requires macOS 14 or later and an Xcode toolchain with Swift 6.3 or later.
The private CoreMaterial interfaces must be available on the host OS.
The app loads recipes from
`/System/Library/PrivateFrameworks/CoreMaterial.framework/`. Use **Open** or pass
an input path on the command line to inspect another recipe or folder.

```sh
./run.sh
./run.sh /path/to/example.materialrecipe
./run.sh /path/to/CoreMaterial.framework
```

Open [MaterialViewer.xcodeproj](MaterialViewer.xcodeproj) and run the
`MaterialViewer` scheme, or use `./build.sh` to build the Release configuration.
Use `CONFIGURATION=Debug ./build.sh` for a Debug build. `run.sh` builds and opens
the app. App startup flags: `--effect-off`, `--grid`, and `--layer-json`.

Signing uses Automatic with development team `VB7MJ8R223` in
[common.xcconfig](xcconfigs/common.xcconfig). The app bundle identifier is
`org.OpenSwiftUIProject.MaterialViewer`. You can pass Xcode build settings to
`build.sh`, for example `./build.sh DEVELOPMENT_TEAM=YOUR_TEAM_ID`.

`build.sh` only invokes `xcodebuild`. The project builds, embeds, and signs both
executables. The script's Release app is at
`DerivedData/Build/Products/Release/MaterialViewer.app`; Debug builds use the
`Debug` directory. The Xcode GUI uses its configured DerivedData location.
The app does not bundle recipe resources or depend on an archive location.

## Project structure

[Package.swift](Package.swift) provides two products:

- `MaterialViewerKit`: recipe parsing, resource resolution, and native rendering.
- `materialviewer`: a command-line executable that depends on `MaterialViewerKit`.

The native Xcode app target `MaterialViewerApp` uses the local package at the
repository root. It links `MaterialViewerKit`, builds the `materialviewer` product as a dependency,
and embeds it with a Copy Files phase and Code Sign on Copy. The project uses
xcconfig files and requires no project generator or custom build phase scripts.
App sources are under `App/MaterialViewer`; package sources are under `Sources`.
Only the library is in the app's package product dependencies. The CLI uses a
target dependency and a copy reference so Xcode does not treat it as a linked
library or convert their shared code to dynamic frameworks.

The app target and Swift module use `MaterialViewerApp`, while the product is
`MaterialViewer.app`. This keeps their build paths distinct from `materialviewer`
on file systems that do not distinguish uppercase and lowercase names.

The app and CLI have separate entry points and binaries:

```text
MaterialViewer.app/
  Contents/
    MacOS/MaterialViewer
    Helpers/materialviewer
```

## Command line

```sh
./build.sh
app=DerivedData/Build/Products/Release/MaterialViewer.app
"$app/Contents/Helpers/materialviewer"
"$app/Contents/Helpers/materialviewer" --check
"$app/Contents/Helpers/materialviewer" --check /path/to/example.materialrecipe
```

No arguments, `--help`, or `-h` prints help and exits. The CLI never opens the app.
`--check` prints a layer JSON report for each
recipe, followed by a text summary. It exits with a nonzero status if a recipe
fails to load or has missing style resources. Without an input path, it reads
the host's CoreMaterial framework. Invalid arguments exit with status 2.

The executable can run outside this checkout. Copy `Contents/Helpers/materialviewer`
from the built app to the desired location; no app bundle or adjacent resources
are required. The CLI requires macOS 14 or later with the native CoreMaterial
interfaces available.

To build or run only the CLI with Swift Package Manager:

```sh
swift run materialviewer --check
swift build -c release --product materialviewer
.build/release/materialviewer --check /path/to/CoreMaterial.framework
```

The SwiftPM build does not use the Xcode signing settings. Use the CLI copied
from the app when you need the configured development signature.

## Use

- Select a recipe in the sidebar, or use **Open** to select a file or folder.
- **Source** shows the original property list as JSON.
- **Resolved** shows the inherited material and referenced style sets.
- **Layer** shows the live layer tree, filter types, and available filter inputs.
- Use **Effect** to compare the filtered and unfiltered background. **Weight**
  changes CoreMaterial's interpolation weight.
- **Grid** provides a high-frequency background for blur inspection.
  **Animate** moves a color shape behind the material.
- **Reduce transparency** passes that setting to CoreMaterial. Its visible
  effect depends on the recipe and host implementation.
- **Reload** reads the selected file again. **Copy JSON** copies the current tab.

The preview applies `baseMaterial`. Fill and stroke style sets are resolved for
inspection but are not applied to the preview label or border. The border is a
viewer guide. The label is ordinary text above the material.

## Rendering and scope

The app loads the host's `/System/Library/PrivateFrameworks/CoreMaterial.framework`
with `dlopen`. It calls `setRecipeName:fromBundle:` on `MTMaterialLayer` and sets
its weight. It does not load the iOS Simulator binary into the macOS process.
The displayed runtime label identifies the host OS. Results can differ from
the original iOS or visionOS renderer.

The loader supports `materialSettingsVersion = 2`, binary and XML property lists,
and `.descendantrecipe` inheritance. Dictionary overrides merge recursively;
arrays and scalar values replace inherited values. `.visualstyleset` and
`.descendantstyleset` resources use the same resolution rule. Missing style
resources appear as warnings. Invalid recipes and inheritance cycles fail with
an error before rendering.

Each preview uses a temporary resource bundle and a unique recipe name to avoid
stale CoreMaterial cache entries. Source files are never written. Temporary
bundles are removed when their preview session is released. A forced process
termination can leave a bundle in the system temporary directory.

Private interfaces can change between OS releases. If the required class or
methods are unavailable, the app keeps the JSON visible and reports a rendering
error. There is no substitute blur implementation.

## Verification

```sh
swift test
swift run materialviewer --check
swift run materialviewer --check /path/to/CoreMaterial.framework
python3 Scripts/check-cli.py DerivedData/Build/Products/Release/MaterialViewer.app/Contents/Helpers/materialviewer
```

The tests cover flat and versioned framework resource discovery, binary/XML
decoding, descendant merging, array replacement,
missing ancestors, inheritance cycles, unsupported versions, source preservation,
and temporary bundle cleanup. `--check` loads each recipe into the actual host
renderer, verifies weight and transparency settings, and prints its layer state.
Without an input path, `--check` uses the same system framework as the app.
It returns a nonzero exit code on load
errors or missing style resources. It does not verify pixels; inspect the live
window to verify background sampling.

The CLI smoke check requires Python 3. It copies the binary to a temporary
directory, checks help and error exit codes, and loads all system recipes. This
also checks that the CLI runs without the app bundle or build directory.

Verified on macOS 26.6.2 (25G83): all 41 archived recipes load, and all four
resolved descendants produce the same layer and filter inputs as native
CoreMaterial inheritance. Window image comparisons with the effect on and off
confirm background sampling for `platformContentLight`.

Build products are local and ignored by Git.
