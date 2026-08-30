# PathPlanner Web for CodeRunner — Design

Date: 2026-08-30
Status: Approved

## Goal

Run PathPlanner as a web app inside CodeRunner (the browser IDE for FRC
students at `~/dev/CodeRunner`). It is served as a static Flutter web build,
embedded as an iframe in the CodeRunner shell (toggled with the
AdvantageScope pane), and replaces all local file management with CRUD
calls to a new CodeRunner deploy-files API.

This repo (`pathplanner-web`) is a fork of upstream
`mjansen4857/pathplanner`. **Only the web build must work** — desktop
entrypoints may rot — but all changes must stay modular and additive
(new files under `lib/coderunner/`, mechanical guards in upstream files)
so that merging future upstream releases stays cheap.

## v1 feature scope

In scope:
- Project page, path editor, auto editor — full editing, persisted via the API.
- Choreo `.traj` files — read-only display, as on desktop.
- Undo/redo, project settings (`settings.json`), bundled field images.

Out of scope for v1 (gated off on web, cleanly, behind guards):
- Telemetry page, NT4 connection, hot reload (noop telemetry injected).
- Navgrid editor page and the path optimizer (no isolates needed).
- Custom field image import, GIF export / trajectory render dialog.
- Update checker (noop injected), window management, file/dir pickers,
  desktop log files, directory watchers (refresh-on-reload instead).

## Architecture

### File layer: hydrated MemoryFileSystem + write-through sync

Upstream already injects a `package:file` `FileSystem` into every model
and widget. We keep that seam:

- On startup, fetch a **snapshot** of the deploy tree from the CodeRunner
  API and populate a `MemoryFileSystem` under a fixed virtual project
  root (`/project`).
- Wrap it in a `ForwardingFileSystem` subclass
  (`CodeRunnerFileSystem`) that intercepts mutations — `File.writeAsString`,
  `File.rename`, `File.delete`, `Directory.create` and their sync
  variants — applies them to the memory fs, and enqueues mirror
  operations to the API.
- All upstream code, including its ~16 synchronous fs calls
  (`existsSync`, `listSync`, etc. in `home_page.dart`,
  `pathplanner_path.dart`, `pathplanner_auto.dart`,
  `project_page.dart`, `choreo_path.dart`, `nav_grid_page.dart`,
  `app_settings.dart`), works unchanged against the in-memory copy.

Verified mutation entry points (all flow through the injected fs):
- `lib/path/pathplanner_path.dart:174` `writeAsString`, `:215` `delete`,
  `:223` `rename`
- `lib/auto/pathplanner_auto.dart:136` `writeAsString`, `:118` `rename`,
  `:128` `delete`
- `settings.json` save in `lib/pages/home_page.dart`
  (`_saveProjectSettingsToFile`)

### Sync queue

- Ordered, single-flight queue of API operations (PUT / DELETE).
- Rapid saves to the same file coalesce (PathPlanner calls
  `generateAndSavePath()` on every edit).
- Rename decomposes into PUT (new path) + DELETE (old path); the queue
  preserves that order.
- Transient failures retry with backoff; the queue exposes a save-state
  notifier (`saved` / `saving` / `error`) rendered as a small indicator
  in the appbar area.
- Hydration failure shows a full-screen error with a retry button
  instead of an empty project.

### External changes (VSCodium edits, lesson load, git import)

Refresh-on-reload only. PathPlanner hydrates when its iframe loads; the
CodeRunner shell is expected to reload the iframe after lesson switches
or imports. No polling, no watch endpoint. The desktop `watcher` usage
(`lib/pages/project/project_page.dart` choreo watcher) is guarded off on
web.

### Bootstrap: `lib/coderunner/main_coderunner.dart`

A separate entrypoint (`flutter build web -t lib/coderunner/main_coderunner.dart`),
leaving `lib/main.dart` untouched:

1. Parse the workspace slug from the iframe URL query string
   (`/pathplanner/?ws=<slug>`). Same-origin iframe ⇒ session cookies
   authenticate every API call; no tokens, no CORS.
2. Build the API client (`/u/<slug>/api/deploy-files/...`).
3. Hydrate `CodeRunnerFileSystem` from the snapshot endpoint.
4. Create a `build.gradle` marker file in the memory fs at the project
   root so upstream's Gradle-layout detection
   (`lib/pages/home_page.dart:705`) resolves
   `src/main/deploy/pathplanner` + `src/main/deploy/choreo`.
5. Pre-set `SharedPreferences` `currentProjectDir` to `/project` so the
   welcome page / project picker never runs.
6. Construct `HomePage` with: the CodeRunner fs, a
   `CodeRunnerNoopTelemetry implements PPLibTelemetry` (Dart implicit
   interface — no upstream edit), a noop `UpdateChecker`, console-only
   logging (skip `Log.init()`'s `path_provider` file logger).

App-level prefs (team color, UI state) stay in `shared_preferences`,
which is `localStorage` on web. Project-scoped settings persist
server-side via `settings.json` like any other file.

### Minimal upstream edits

Eleven files import `dart:io` (mostly `Platform.*`). Handled by:

- A conditional-import platform shim (`lib/coderunner/platform/`)
  exposing `isMacOS` / `isWindows` / `isLinux` / `pathSeparator` with
  web-safe values; upstream files swap `dart:io` `Platform` for the shim
  where they only need these.
- `kIsWeb` (or a small `AppCapabilities` const) guards that hide:
  window buttons + drag handling in `lib/widgets/custom_appbar.dart`,
  telemetry and navgrid nav destinations in `home_page.dart`, custom
  field-image import (`import_field_dialog.dart`, `edit_field_dialog.dart`,
  `field_image.dart` custom loading at `home_page.dart:746`), the
  trajectory render / GIF export dialog, update-check UI, and the
  choreo directory watcher in `project_page.dart`.

Every upstream edit is a guard or import swap, never a rewrite.

## Interface agreement with CodeRunner

The CodeRunner control plane implements these (out of scope for this
repo's plan, but PathPlanner codes against them; schemas will live in
`@frc-coderunner/contracts`, routes in
`apps/control/src/app/workspace-routes.ts` style, behind the existing
`requireWorkspaceOwnership` auth):

- `GET /u/:slug/api/deploy-files/snapshot`
  → `{ ok: true, files: [{ path: string, content: string }] }`
  Paths are relative to the project root, covering
  `src/main/deploy/pathplanner/**` (read-write) and
  `src/main/deploy/choreo/**` (read-only). Empty list when the project
  has no deploy dir. Text content only (all target files are JSON).
- `PUT /u/:slug/api/deploy-files/<path>` with the raw file body
  → `{ ok: true }`. Creates parent dirs. Only allowed under
  `src/main/deploy/pathplanner/**`. Path segments validated with the
  same safe-segment pattern as `lessonModuleSubdirSchema`.
- `DELETE /u/:slug/api/deploy-files/<path>` → `{ ok: true }`.
  Same write scope.
- Errors follow the existing `{ error: string }` + status convention
  (400 invalid path, 401/403 auth, 404 delete-missing, 5xx server).

No rename endpoint (client decomposes). No NT4 changes in v1.

Serving (CodeRunner side, recorded for completeness): the web build is
produced with `flutter build web --base-href /pathplanner/` and
CanvasKit **bundled locally** (offline-demo constraint — no gstatic CDN
fetch), served at `/pathplanner/` the way AdvantageScope is served at
`/scope/`, iframed by the shell with `?ws=<slug>`.

Known follow-up for the telemetry milestone (recorded, not v1): the NT4
proxy (`apps/control/src/containers/converters.ts`) pins the upstream
client name to `/nt/AdvantageScopeLite`; a second NT4 client needs a
client-name passthrough, and the Dart `nt4` package hardcodes
`ws://<addr>:5810/nt/<name>` so PathPlanner will need a vendored client
with a full-URL override.

## Testing

- Unit tests (pure Dart, run under the existing `flutter test` suite):
  `CodeRunnerFileSystem` mutation interception, sync-queue ordering /
  coalescing / retry, snapshot hydration, config parsing — against
  `MemoryFileSystem` and a mocked HTTP client.
- One widget test booting the web entrypoint wiring against a fake
  deploy-files client and asserting the project page renders hydrated
  paths.
- Upstream's existing test suite keeps passing unmodified.

## Non-goals / constraints

- No changes to existing CodeRunner endpoints; the deploy-files API is
  additive.
- No speculative features beyond the v1 scope above.
- Keep diffs against upstream reviewable: prefer new files in
  `lib/coderunner/`, guard-style edits elsewhere.
