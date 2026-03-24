# CardioScan - ECG Interpretation App

## Development Report

**Date:** March 24, 2026
**Platform:** iOS (iPhone 16 Pro Simulator, iOS 18.6)
**Framework:** Flutter (Dart)

---

## Overview

CardioScan is a mobile application for capturing, interpreting, and storing ECG (electrocardiogram) recordings. The app simulates ECG capture via a dummy SDK, processes the data through a simulated AI interpretation algorithm, and stores all recordings locally on-device using SQLite.

---

## Architecture

### File Structure

```
lib/
├── main.dart                          # App entry point, theme, routing
├── driver_main.dart                   # Flutter Driver entrypoint (testing)
├── models/
│   └── ecg_record.dart                # Data model + DB serialization
├── services/
│   ├── database_service.dart          # SQLite CRUD (singleton)
│   ├── ecg_simulator.dart             # Generates realistic ECG waveforms
│   └── interpretation_service.dart    # Simulated AI interpretation API
├── screens/
│   ├── home_screen.dart               # Dashboard with stats + recent list
│   ├── new_recording_screen.dart      # 3-step capture flow
│   ├── ecg_detail_screen.dart         # Full report view
│   └── history_screen.dart            # Searchable/filterable history
├── widgets/
│   ├── ecg_waveform_painter.dart      # CustomPainter for ECG trace on grid
│   ├── severity_badge.dart            # Color-coded severity indicator
│   └── ecg_record_card.dart           # List tile for ECG summaries
└── theme/
    ├── app_theme.dart                 # Material 3 clinical theme
    └── app_colors.dart                # Medical color palette
```

### Dependencies

| Package | Purpose |
|---------|---------|
| `sqflite` | Local SQLite database for on-device storage |
| `path_provider` | Database file path resolution |
| `path` | Path manipulation |
| `intl` | Date/time formatting |
| `share_plus` | Share/export functionality |

### Data Model

```dart
ECGRecord {
  id, patientName, patientAge, patientGender,
  timestamp, ecgData (2500 samples), interpretation,
  severity (normal/warning/critical), heartRate,
  findings (list), doctorNotes
}
```

ECG data is stored as a JSON-encoded array of doubles (~2500 samples = 10 seconds at 250 Hz).

---

## Screens & User Flow

### 1. Dashboard (Home Screen)

The main landing screen provides an at-a-glance overview of all ECG activity.

**Features:**
- **Stats cards** — Total, Normal, and Abnormal recording counts with color-coded backgrounds (blue/green/red)
- **Recent Recordings** — Last 5 ECGs shown as cards with patient name, diagnosis, heart rate, date, and severity badge
- **Empty state** — Friendly prompt when no recordings exist
- **Bottom navigation** — Dashboard and History tabs
- **FAB** — "New ECG" floating action button to start a recording

![Dashboard with recording](screenshots described below)

*The dashboard after one recording: stats show 1 Total / 1 Normal / 0 Abnormal. John Smith's recording appears in the recent list with "Normal Sinus Rhythm · 75 BPM" and a green "Normal" badge.*

---

### 2. New ECG Recording (3-Step Flow)

#### Step 1: Patient Information

A clean form to capture patient demographics before starting the ECG.

**Features:**
- Patient Name (text input with person icon)
- Age (numeric input with cake icon)
- Gender (segmented button: Male / Female / Other)
- Form validation — all fields required, age must be 1-150
- "Start ECG Capture" button

*The form shows fields for Patient Name ("John Smith"), Age ("55"), and Gender (Male selected), with a prominent blue "Start ECG Capture" button.*

#### Step 2: ECG Capture Animation

A real-time animated ECG recording simulation.

**Features:**
- **Countdown timer** — Large numeric display (10 → 0 seconds)
- **Progress bar** — Linear indicator of capture progress
- **Live ECG waveform** — Animated trace drawing left-to-right on a classic pink ECG grid paper background
- **Grid** — Minor gridlines (1mm) and major gridlines (5mm) matching standard ECG paper
- **Status indicator** — "Recording in progress..." with sensor icon

*The capture screen at 6 seconds remaining shows PQRST complexes being drawn in dark blue on the pink ECG grid, with a progress bar at ~40%.*

#### Step 3: Results / Interpretation

After capture completes, a 1.5-second "Analyzing ECG..." loading screen simulates the AI API call, then results are displayed.

**Features:**
- **Severity badge** — Color-coded (green Normal / amber Warning / red Critical)
- **Diagnosis** — Large bold text (e.g., "Normal Sinus Rhythm")
- **Heart rate** — BPM with heart icon
- **ECG preview** — Compressed full waveform on grid
- **Description** — Detailed interpretation text
- **Findings list** — Bulleted clinical findings
- **Save/Discard** — Save to database or discard

*Results screen shows "Normal" badge, "Normal Sinus Rhythm" diagnosis, 75 BPM heart rate, a compressed ECG preview, and 6 clinical findings including "Regular R-R intervals" and "Normal P wave morphology".*

---

### 3. ECG Detail Screen (Report View)

Full detailed view of a saved ECG recording.

**Features:**
- **Patient info card** — Name, age, gender, date/time with avatar
- **Scrollable ECG waveform** — Full 10-second trace on pink grid, horizontally scrollable, with "10s · 250 Hz · 25mm/s" metadata
- **Interpretation card** — Severity badge, diagnosis, heart rate, divider, and findings list
- **Doctor's Notes** — Tap-to-edit section with pencil icon, opens bottom sheet for adding/editing clinical notes
- **Delete** — Trash icon in app bar with confirmation dialog

*The ECG Report screen displays John Smith's info (55 yrs · Male), a scrollable waveform, "Normal Sinus Rhythm" interpretation with Normal badge, and a "Doctor's Notes" section with "Tap to add notes..." placeholder.*

---

### 4. History Screen

Complete searchable, filterable list of all recordings.

**Features:**
- **Search** — Magnifying glass icon expands to search by patient name
- **Filter chips** — All / Normal / Warning / Critical severity filters
- **Recording list** — All ECGs sorted by date (newest first) with patient name, diagnosis, BPM, date, and severity badge
- **Swipe to delete** — Swipe left to reveal delete action with confirmation
- **Pull to refresh** — Pull down to reload from database
- **Empty state** — "No recordings found" when filters match nothing
- **Tap to view** — Opens ECG Detail screen

*History screen shows filter chips (All selected), John Smith's recording card, and a search icon in the app bar.*

---

## ECG Simulation Engine

The simulator generates 6 distinct ECG patterns using mathematical Gaussian functions for PQRST wave components:

| Pattern | Heart Rate | Severity | Probability |
|---------|-----------|----------|-------------|
| Normal Sinus Rhythm | 60-90 BPM | Normal | 50% |
| Sinus Tachycardia | 110-140 BPM | Warning | 15% |
| Sinus Bradycardia | 40-55 BPM | Warning | 13% |
| Atrial Fibrillation | Variable | Critical | 10% |
| ST Elevation (STEMI) | ~80 BPM | Critical | 7% |
| Premature Ventricular Contractions | ~75 BPM | Warning | 5% |

Each pattern generates realistic PQRST morphology:
- **P wave**: Small Gaussian bump (~0.15 mV)
- **QRS complex**: Sharp R peak (~1.2 mV) with Q and S dips
- **T wave**: Broad Gaussian (~0.30 mV)
- **Noise**: Random Gaussian noise (±0.03 mV)
- **AFib variant**: Replaces P waves with fibrillatory baseline, irregular R-R intervals
- **PVC variant**: Every 4th beat has wide, inverted QRS without P wave

---

## Interpretation AI (Simulated)

The interpretation service simulates an API call with a 1.5-second delay and returns:
- **Diagnosis** — Clinical name of the rhythm
- **Severity** — normal / warning / critical
- **Heart rate** — Estimated from R-peak detection algorithm
- **Details** — One-sentence clinical summary
- **Findings** — 5-6 specific clinical observations per diagnosis

Heart rate estimation uses a peak detection algorithm that finds R-peaks above 60% of maximum amplitude with a minimum 0.3-second refractory period.

---

## Design Decisions

### Clinical UI Theme
- **Primary**: Medical blue (#1565C0) with white app bars
- **Background**: Light grey (#F5F7FA) for reduced eye strain
- **ECG Grid**: Classic pink/salmon palette matching real ECG paper
- **Severity colors**: Green (normal), Amber (warning), Red (critical)
- **Typography**: Clean sans-serif, larger body text for readability
- **Material 3**: Modern components (SegmentedButton, NavigationBar, FilterChip)

### On-Device Storage
- SQLite via `sqflite` — all data stays on the device
- Single denormalized table — simple schema, no patient management overhead
- ECG data as JSON string — ~25KB per recording, well within SQLite limits

### No External Dependencies for ECG Rendering
- `CustomPainter` instead of chart libraries — full control over grid appearance, calibration marks, and medical-grade aesthetics

### State Management
- Simple `setState` + singleton service pattern — appropriate for this app's complexity level
- No Provider/Riverpod/Bloc overhead

---

## Bug Fixes During Development

1. **`flutter_driver` not in dependencies** — Added to `dev_dependencies` and created `driver_main.dart` entrypoint
2. **`path` package missing** — Added explicit dependency for `database_service.dart`
3. **`BuildContext` across async gap** — Changed `mounted` to `ctx.mounted` in bottom sheet callback
4. **History tab not refreshing** — `IndexedStack` kept stale state; added `GlobalKey` to trigger `loadRecords()` on tab switch
5. **Test file referencing old `MyApp`** — Updated to reference `CardioScanApp`

---

## Future Enhancements

- **PDF Export** — Generate and share ECG reports as PDF documents
- **Real SDK Integration** — Replace simulator with actual ECG hardware SDK (e.g., Tricog)
- **Real AI API** — Replace dummy interpretation with actual ML model endpoint
- **Multi-lead ECG** — Support 12-lead ECG display (currently single-lead)
- **Patient Database** — Separate patient management with multiple ECGs per patient
- **Cloud Sync** — Optional encrypted backup to cloud storage
- **Comparison View** — Side-by-side comparison of two ECG recordings
- **Trend Analysis** — Heart rate trends over time per patient
