# Development Narrative: Building CardioScan with Claude Code + Flutter MCP

## How This App Was Built — An AI-Assisted Development Story

This document describes how the CardioScan ECG interpretation app was developed using **Claude Code** (Anthropic's CLI agent) together with the **Dart/Flutter MCP (Model Context Protocol) server**. The MCP server gave Claude direct access to Flutter tooling — launching apps, taking screenshots, tapping buttons, entering text, and hot-reloading — creating a tight feedback loop where the AI could build, deploy, test, and iterate on the app in real-time on an iOS simulator.

---

## The Setup

The starting point was a default Flutter counter app (`flutter create`). The tools available were:

- **Claude Code** — AI agent with file read/write/edit, bash commands, and planning capabilities
- **Dart/Flutter MCP Server** — Provided tools for:
  - `list_devices` — List available Flutter devices
  - `launch_app` — Launch a Flutter app on a device
  - `stop_app` — Kill a running app
  - `connect_dart_tooling_daemon` — Connect to the running app's debug tooling
  - `flutter_driver` — Send driver commands (tap, enter text, scroll, screenshot)
  - `hot_reload` / `hot_restart` — Apply code changes without full rebuild
  - `analyze_files` — Run Dart analyzer for error checking
  - `pub` — Manage dependencies

---

## Phase 1: Bootstrapping the Environment

### Launching the Simulator

The user asked to launch the app on the iOS simulator. Claude used the MCP tools to:

1. **`list_devices`** — Found only macOS and Chrome available (no simulator running)
2. **`open -a Simulator`** (bash) — Launched the Simulator app
3. **`xcrun simctl list devices`** — Found available iPhone simulators
4. **`xcrun simctl boot <device-id>`** — Booted the iPhone 16 Pro simulator
5. **`list_devices`** again — Confirmed iPhone 16 Pro was now available

### Enabling Flutter Driver

To enable screenshot and interaction capabilities, Claude needed to set up Flutter Driver:

1. Created `lib/driver_main.dart` — A separate entrypoint that calls `enableFlutterDriverExtension()` before `runApp()`
2. Added `flutter_driver` to `dev_dependencies` in `pubspec.yaml`
3. Ran `pub get` via the MCP tool
4. Launched the app with `target: lib/driver_main.dart`
5. Connected to the Dart Tooling Daemon using the WebSocket URI returned by `launch_app`

This was an iterative process — the first attempt failed because `flutter_driver` wasn't in the dependencies. Claude read the error output, added the dependency, and retried.

### First Screenshot

Once connected, Claude took the first screenshot of the default counter app, confirming the pipeline worked:

```
flutter_driver command: screenshot
→ Captured the default Flutter counter app with "You have pushed the button this many times: 0"
```

Claude then tapped the + button and took another screenshot to verify interaction worked — counter showed "1".

---

## Phase 2: Planning the ECG App

Before writing code, Claude used a planning agent to design the full architecture:

- **6 ECG patterns** to simulate (Normal, Tachycardia, Bradycardia, AFib, ST Elevation, PVCs)
- **4 screens** (Dashboard, New Recording, ECG Detail, History)
- **Data model** with SQLite storage
- **CustomPainter** for ECG waveform rendering (not a chart library — for medical-grade control)
- **Clinical UI theme** — medical blue, pink ECG grid, severity color coding

The plan was comprehensive: file structure, data model schema, service layer, screen-by-screen design, widget details, and implementation sequence.

---

## Phase 3: Building the App

Claude created the entire app in a single pass, working from the bottom up:

### 1. Directory Structure
```bash
mkdir -p lib/{models,services,screens,widgets,theme}
```

### 2. Dependencies
Added `sqflite`, `path_provider`, `path`, `intl`, `share_plus` to `pubspec.yaml`.

### 3. Models & Theme (no dependencies on other app code)
- `models/ecg_record.dart` — ECGRecord class with `toMap()`/`fromMap()` for SQLite serialization
- `theme/app_colors.dart` — Medical color palette (primary blue, ECG grid pink, severity green/amber/red)
- `theme/app_theme.dart` — Material 3 theme with clinical styling

### 4. Services
- `services/database_service.dart` — Singleton SQLite wrapper with CRUD, stats, and search
- `services/ecg_simulator.dart` — Mathematical PQRST generation using Gaussian functions
- `services/interpretation_service.dart` — Simulated AI with 1.5s delay, returns diagnosis + findings

### 5. Widgets
- `widgets/ecg_waveform_painter.dart` — CustomPainter drawing ECG trace on pink grid paper
- `widgets/severity_badge.dart` — Color-coded Normal/Warning/Critical badge
- `widgets/ecg_record_card.dart` — List tile with patient name, diagnosis, BPM, date

### 6. Screens
- `screens/home_screen.dart` — Dashboard with stats cards, recent list, bottom nav
- `screens/new_recording_screen.dart` — 3-step flow: form → animated capture → results
- `screens/ecg_detail_screen.dart` — Full report with scrollable waveform, interpretation, doctor's notes
- `screens/history_screen.dart` — Searchable, filterable list with swipe-to-delete

### 7. Entry Points
- Updated `main.dart` to launch CardioScanApp
- Updated `driver_main.dart` to match

---

## Phase 4: Analysis & Bug Fixes

After writing all code, Claude used the MCP `analyze_files` tool to check for errors before building:

```
mcp__dart__analyze_files → Found 4 issues
```

**Issues found and fixed:**

1. **`path` package not in dependencies** — `database_service.dart` imported it but it was only a transitive dependency. Added explicit dependency.
2. **`BuildContext` across async gap** — In `ecg_detail_screen.dart`, used `mounted` check on wrong context. Changed to `ctx.mounted`.
3. **Test file referencing `MyApp`** — Old counter app class. Updated to `CardioScanApp`.
4. **`flutter_driver` import warning** — Expected, since it's a dev dependency used in `driver_main.dart`.

---

## Phase 5: Deploy & Visual Testing via MCP

This is where the MCP integration really shone. Claude:

### Launched the App
```
stop_app(pid: 42978)               → Stopped old counter app
launch_app(target: driver_main.dart) → Built and launched CardioScan
connect_dart_tooling_daemon(uri)     → Connected to debug tools
```

### Screenshot: Dashboard (Empty State)
```
flutter_driver: screenshot
→ Clean dashboard with "CardioScan" title, 0/0/0 stats, "No recordings yet" empty state, "New ECG" FAB
```

Claude visually inspected the screenshot and confirmed the clinical UI looked correct.

### Navigated to New Recording
```
flutter_driver: tap(ByText: "New ECG")
flutter_driver: screenshot
→ Patient Information form with name, age, gender fields and "Start ECG Capture" button
```

### Filled in the Form
```
flutter_driver: tap(BySemanticsLabel: "Patient Name")
flutter_driver: enter_text("John Smith")
flutter_driver: tap(BySemanticsLabel: "Age")
flutter_driver: enter_text("55")
flutter_driver: screenshot
→ Form showing "John Smith", "55", Male selected
```

Note: Claude first tried `tap(ByType: TextFormField)` which failed because there were 2 TextFormFields — it adapted and used `BySemanticsLabel` instead. This kind of runtime debugging is a key advantage of the MCP approach.

### Started ECG Capture
```
flutter_driver: tap(ByText: "Start ECG Capture")
flutter_driver: screenshot (during capture)
→ Countdown at "6", progress bar at ~40%, animated ECG waveform drawing on pink grid
```

### Waited for Analysis
```
sleep 12  (10s capture + 1.5s analysis + buffer)
flutter_driver: screenshot
→ Results: "Normal" badge, "Normal Sinus Rhythm", 75 BPM, waveform preview, 6 findings
```

### Saved and Viewed Detail
```
flutter_driver: tap(ByText: "Save Recording")
flutter_driver: screenshot
→ ECG Report screen: patient card, scrollable waveform, interpretation, doctor's notes
```

### Scrolled to See Full Detail
```
flutter_driver: scroll(ByType: Scaffold, dy: -500)
flutter_driver: screenshot
→ Revealed Doctor's Notes section with edit icon at bottom
```

### Navigated Back to Dashboard
```
flutter_driver: tap(PageBack)
flutter_driver: screenshot
→ Dashboard now shows 1 Total / 1 Normal / 0 Abnormal, John Smith's recording in recent list
```

---

## Phase 6: Bug Discovery Through Visual Testing

When Claude tapped the "History" tab, the screenshot revealed an empty list despite the record existing. This was a real bug:

**Root Cause:** `IndexedStack` keeps both tabs alive. The History screen was initialized on first build (before any records existed) and never refreshed when switching tabs.

**Fix:**
1. Made `HistoryScreenState` public
2. Added a `GlobalKey<HistoryScreenState>` in HomeScreen
3. Called `_historyKey.currentState?.loadRecords()` on tab switch

After fixing, this caused a build error (`_loadRecords` was renamed to `loadRecords` but one reference in `onRefresh` was missed). Claude found it from the launch error output and fixed it.

After relaunching, the History tab correctly showed the record.

---

## Key Takeaways

### What Worked Well

1. **MCP as a visual feedback loop** — Claude could build code, deploy it, take screenshots, visually verify the UI, and fix issues — all without human intervention. This is fundamentally different from "blind" code generation.

2. **Flutter Driver for interaction testing** — Filling forms, tapping buttons, scrolling, and screenshotting allowed Claude to walk through the complete user flow programmatically.

3. **Error-driven iteration** — When things failed (missing dependencies, wrong finder types, build errors), Claude read the error messages and adapted. The MCP server provided rich error context.

4. **Bug discovery through usage** — The History tab bug was only visible by actually using the app (switching tabs). Static analysis wouldn't have caught it.

### Challenges Encountered

1. **Flutter Driver setup** — Required a separate entrypoint and explicit dependency, not just "turn it on"
2. **Finder ambiguity** — `ByType: TextFormField` failed when multiple existed; had to use `BySemanticsLabel`
3. **Hot reload limitations** — Some changes (like new imports) required full restart, and occasionally the app needed a complete stop/relaunch
4. **Simulator boot time** — Had to wait for the iOS simulator to fully boot before devices were visible

### The Power of the Approach

This development session demonstrated a complete cycle:

**Plan → Build → Deploy → Screenshot → Inspect → Fix → Redeploy → Verify**

All driven by an AI agent with direct access to the development toolchain via MCP. The human's role was to provide the vision ("build me an ECG app") and approve tool executions — the AI handled architecture, implementation, deployment, testing, bug fixing, and documentation.

Total screens built: **4**
Total files created: **14**
Total ECG patterns simulated: **6**
Bugs found and fixed during visual testing: **1** (History tab refresh)
Bugs found and fixed during static analysis: **4**
Screenshots taken during development: **~10**
