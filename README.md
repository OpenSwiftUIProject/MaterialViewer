# Material Recipe Viewer

A macOS tool that reads CoreMaterial property lists and previews their base
material with a real `MTMaterialLayer`.

## Run

Requires macOS 14 or later and an Xcode toolchain with Swift 6.3 or later.
The private CoreMaterial interfaces must be available on the host OS.
Launch without arguments to load recipes from
`/System/Library/PrivateFrameworks/CoreMaterial.framework/`. Use **Open** or pass
an input path on the command line to inspect another recipe or folder.

```sh
./run.sh
./run.sh /path/to/example.materialrecipe
./run.sh /path/to/CoreMaterial.framework
```

`build.sh` creates `dist/Material Recipe Viewer.app` with bundle identifier
`org.OpenSwiftUIProject.MaterialViewer` and the standalone executable
`dist/MaterialRecipeViewer`. Neither output bundles recipe resources or depends
on an archive location. You can also run `swift run MaterialRecipeViewer` with an
optional input path.

## Command line

```sh
./build.sh
./dist/MaterialRecipeViewer --help
./dist/MaterialRecipeViewer --check
./dist/MaterialRecipeViewer --check /path/to/example.materialrecipe
./dist/MaterialRecipeViewer --check /path/to/CoreMaterial.framework
```

`--check` runs without opening a window. It prints a layer JSON report for each
recipe, followed by a text summary. It exits with a nonzero status if a recipe
fails to load or has missing style resources. Without an input path, it reads
the host's CoreMaterial framework. Without `--check`, the executable opens the
viewer window.

The executable can run outside this checkout. Copy `dist/MaterialRecipeViewer`
to the desired location; no app bundle or adjacent resources are required. The
binary targets the build machine's architecture and requires macOS 14 or later
with the native CoreMaterial interfaces available.

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
swift run MaterialRecipeViewer --check
swift run MaterialRecipeViewer --check /path/to/CoreMaterial.framework
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

Optional startup flags: `--effect-off`, `--grid`, and `--layer-json`.

Verified on macOS 26.6.2 (25G83): all 41 archived recipes load, and all four
resolved descendants produce the same layer and filter inputs as native
CoreMaterial inheritance. Window image comparisons with the effect on and off
confirm background sampling for `platformContentLight`.

Build products are local and ignored by Git.
