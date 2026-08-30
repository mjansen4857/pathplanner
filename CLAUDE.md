# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

This is a monorepo containing four related pieces:

| Directory | What it is |
| --- | --- |
| `lib/`, `test/` | The PathPlanner desktop GUI — a Flutter app for Windows/macOS/Linux (no mobile/web) |
| `pathplannerlib/` | PathPlannerLib, the robot-side vendor library: Java (`src/main/java`) and C++ (`src/main/native`), built with the WPILib Gradle plugin |
| `pathplannerlib-python/` | The RobotPy port of PathPlannerLib (`robotpy-pathplannerlib`) |
| `Writerside/` | Docs published to pathplanner.dev (JetBrains Writerside) |

`lib/` in the repo root is Flutter code; `pathplannerlib/src/main/native/include/pathplanner/lib/` is C++. Don't confuse them.

## Commands

### GUI (Flutter)

Flutter version is pinned in CI (`FLUTTER_VERSION` in `.github/workflows/pathplanner-ci.yaml`).

```bash
flutter pub get
dart run build_runner build        # REQUIRED before tests: *.mocks.dart are gitignored and must be generated
flutter test
flutter test test/path/pathplanner_path_test.dart      # single file
flutter test --plain-name 'HomePage initial rendering' # single test
dart format lib/* test/*           # CI runs this with -o none --set-exit-if-changed
flutter analyze
flutter run                        # debug run
flutter build <windows|macos|linux>
```

CI also runs `dart run full_coverage` before tests, which generates `test/coverage_helper_test.dart` so untouched files count toward coverage.

### PathPlannerLib (Java/C++)

All commands run from `pathplannerlib/`:

```bash
./gradlew build                              # compiles Java + C++ and runs both test suites
./gradlew test --tests "*PathPlannerPath*"   # single Java test class
./gradlew spotlessApply                      # formatting; CI enforces spotlessCheck
./gradlew publish                            # maven artifacts into build/repos
```

Do not let the VSCode WPILib extension "import" `pathplannerlib/` as a robot project — it rewrites the build and breaks it.

### PathPlannerLib Python

From `pathplannerlib-python/`: `pip install -r requirements.txt`, then `pytest` (or `pytest tests/util_test.py::test_name`).

Formatting on a PR can also be triggered by commenting `/format`, which runs both `dart format` and `spotlessApply` and pushes the result.

## Architecture

### Four parallel implementations

Path/trajectory math exists **four times**: Dart (`lib/trajectory/`, `lib/path/`, `lib/util/wpimath/`), Java, C++, and Python. The GUI's Dart code is a port of the library so previews and simulation match on-robot behavior. A change to trajectory generation, path geometry, or the JSON schema generally has to be mirrored across all of them, and the Java/C++/Python versions must stay behaviorally identical to each other.

`lib/util/wpimath/` is a hand-ported subset of WPILib's geometry/kinematics/units for the Dart side.

### On-disk project format

The GUI edits a user's robot project directory, not its own files:

- `src/main/deploy/pathplanner/` (or `deploy/pathplanner/` for non-Gradle projects) — `paths/*.path`, `autos/*.auto`, `navgrid.json`, and `settings.json`
- `src/main/deploy/choreo/` — `*.traj` files imported from Choreo (read-only in the GUI)

`settings.json` holds project-scoped settings (robot dimensions, drivetrain config, folder lists) and is mirrored into `SharedPreferences`; see `_loadProjectSettingsFromFile`/`_saveProjectSettingsToFile` in `lib/pages/home_page.dart` and the key/default pairs in `lib/util/prefs.dart` (`PrefsKeys` / `Defaults`). Adding a setting means touching all three.

Path and auto files carry a `version` field checked against the `fileVersion` constant in `lib/path/pathplanner_path.dart` and `lib/auto/pathplanner_auto.dart` (each season bumps it, e.g. `2025.0`). The same version check exists in the robot libraries.

### GUI conventions

- **Filesystem is injected.** Model classes and page widgets take a `FileSystem fs` (package `file`) rather than using `dart:io` directly, so tests pass a `MemoryFileSystem`. Keep new file-touching code on that pattern.
- **Undo/redo via a shared `ChangeStack`** (package `undo`) threaded from `main.dart` down into every editor tree widget. Mutations are wrapped in a `Change(oldValueClone, execute, undo)` — see `_waypointChange` in `lib/widgets/editor/tree_widgets/waypoints_tree.dart` for the house style. Direct mutation without pushing a `Change` is a bug.
- **Editor structure.** Each editor page (`lib/pages/*_editor_page.dart`) hosts a `split_*_editor.dart` widget: a `CustomPainter` field view (`lib/widgets/editor/path_painter.dart`) on one side, a tree of collapsible property cards (`lib/widgets/editor/tree_widgets/`) on the other. Editing a path calls `generateAndSavePath()`, which regenerates path points and writes the file.
- **Expensive work runs in isolates** via `isolate_manager` (`lib/util/path_optimizer.dart`, GIF export in `lib/widgets/dialogs/trajectory_render_dialog.dart`).
- **Telemetry and hot reload** go over NetworkTables 4 in `lib/services/pplib_telemetry.dart` — exposed as streams for the telemetry page, and publishing to `/PathPlanner/HotReload/*` so the robot picks up edited paths without a redeploy. The robot side is `util/PPLibTelemetry` in each library.
- **Directory watchers** (`package:watcher`) keep the project page in sync when files change on disk, including the Choreo directory.

### Lints

`analysis_options.yaml` enables extras beyond `flutter_lints`, notably `always_use_package_imports` (no relative imports), `prefer_single_quotes`, and the `prefer_const_*` family.
