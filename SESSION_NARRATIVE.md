# Session Narrative: Building CardioScan from Scratch

## A real-time collaboration between a developer and Claude Code

**Date**: March 24, 2026
**Duration**: Single continuous session
**Starting point**: Default Flutter counter app
**End point**: Full patient-facing ECG app with backend spec, demo videos, and documentation

---

## Act 1: "Can you launch this app?"

It started simply. The developer asked me to launch a Flutter app using the Dart MCP server. I listed devices — no iOS simulator was running. I booted the iPhone 16 Pro simulator, waited for it to come online, and launched the default counter app. Took a screenshot: the classic "You have pushed the button this many times: 0". Tapped the + button, screenshot again: "1". The pipeline was working — I could see, interact with, and verify a running app.

But to get here, I had to set up Flutter Driver. The first attempt failed because `flutter_driver` wasn't in the dependencies. I read the error, added the package, created a `driver_main.dart` entrypoint with `enableFlutterDriverExtension()`, and relaunched. This kind of iterative problem-solving — try, fail, read the error, adapt — became the rhythm of the entire session.

## Act 2: "Build me an app for ECG interpretations"

The developer gave a broad brief: an app that captures ECG (simulated), shows AI interpretation (simulated), and stores history on-device. "Think about more scenarios," they said. "Go and build this out."

I planned the architecture first: 6 ECG patterns generated with Gaussian math, CustomPainter for the waveform rendering (not a chart library — ECGs need precise medical-grade visuals), SQLite for local storage, and a clean clinical UI theme. Four screens: Dashboard, New Recording (3-step flow), ECG Detail, and History.

Then I built all 14 source files in one pass, bottom-up: models → services → widgets → screens → main. Ran the Dart analyzer through MCP — caught 4 issues before the first build. Fixed them all. Launched.

The dashboard appeared: "CardioScan" in medical blue, stats cards at 0/0/0, empty state. I filled in the patient form via Flutter Driver (`BySemanticsLabel` for text fields after `ByType` failed on ambiguous matches), started the ECG capture, and watched the animated waveform trace across the pink grid. After the 10-second capture and simulated AI analysis: "Normal Sinus Rhythm, 75 BPM" with a green badge.

I saved the record, verified the detail screen (scrollable waveform, interpretation, doctor's notes), went back to the dashboard — stats updated to 1 Total, 1 Normal. Then I found a real bug: the History tab showed an empty list because `IndexedStack` kept stale state. Fixed it with a `GlobalKey` to trigger reload on tab switch. This bug was only discoverable through actual usage, not static analysis.

## Act 3: "This is only for the patient"

A pivot. The developer clarified this wasn't a clinical tool — it's for the patient themselves. That changed the entire framing: no per-recording patient form (that's your profile, set once), patient-friendly language instead of clinical jargon, symptom tracking, and the ability to share with your doctor.

We discussed features. The developer picked four:
1. **One-time profile setup** — Onboarding with name, DOB, gender, medical conditions, medications
2. **Symptom logging** — "How are you feeling?" before each ECG
3. **Heart rate trends** — Chart showing HR over time with severity coloring
4. **Share with doctor** — Text report via system share sheet

I built all four, including a DB migration from v1 to v2 (new `user_profile` table + symptom columns on `ecg_records`). The recording flow changed: instead of entering patient info each time, you now select symptoms ("Chest Pain", "Palpitations", "Dizziness", etc.) with a "Routine Check" option that's mutually exclusive with symptom selections.

I added patient-friendly guidance cards: green "All looks good" for normal, amber "Worth monitoring" for warning, red "Contact your doctor" for critical. The results screen now speaks to a patient, not a cardiologist.

Relaunched the app. The onboarding screen appeared (fresh DB, no profile). Filled in "Sarah Johnson", picked a date of birth, selected Female, checked Hypertension and High Cholesterol. Tapped "Get Started" — dashboard appeared with the profile icon and new Heart Rate Trends card. Started a new ECG — the symptom screen replaced the old patient form. Selected Palpitations and Dizziness, captured, got results with the guidance card. Saved. The detail screen showed the symptom chips. The trends chart showed 3 data points in the normal band.

## Act 4: "Record a video"

The developer wanted a demo video. I used `xcrun simctl io booted recordVideo` in the background while driving the app through Flutter Driver — tapping through every screen, filling forms, selecting symptoms, waiting for the capture animation, saving recordings, switching between tabs and filters.

The first video was 6.5 minutes (lots of dead time between interactions). The developer asked me to speed it up. I tried `mpdecimate` (FFmpeg's duplicate frame dropper) but the ECG capture animation has subtle per-frame changes that fooled the algorithm. Settled on a straight 8x speedup: 6:30 → 53 seconds, 1.9MB. Punchy, no dead time.

## Act 5: "Can you compile a report?"

Along the way, the developer asked for documentation several times:

- **REPORT.md** — Technical report with architecture, all screens described with what the screenshots showed, ECG simulation engine details, design decisions, and bug fixes
- **DEVELOPMENT_NARRATIVE.md** — First-person story of the development process, how the MCP feedback loop worked, and what I learned
- **BUILDING_CARDIOSCAN.md** — A shareable narrative covering the full journey from counter app to patient-facing ECG app, written in first person for the developer to share externally

Each was written to serve a different audience: REPORT.md for engineers, the narratives for anyone interested in AI-assisted development.

## Act 6: "Build out the server"

The developer wanted a backend. We discussed the stack:

- **FastAPI** for the API server
- **PostgreSQL on Neon** for the database
- **Tigris** (S3-compatible on Fly.io) for ECG waveform storage
- **Clerk** for authentication (email+password and phone OTP)
- **Fly.io** for deployment
- **Terraform** for infrastructure-as-code

I asked clarifying questions: auth model, sync strategy, ECG data storage approach, interpretation API location, deployment target. The developer had clear answers: Tigris for waveforms, server-hosted interpretation, Fly.io deployment, Neon for Postgres.

They provided the Clerk keys (publishable and secret). I designed a full backend spec: 2 database tables with every column, type, constraint, and index documented. 11 API endpoints across 6 groups. A seed script that generates 20 realistic ECG records spanning 6 weeks with a narrative arc (a patient with hypertension whose intermittent arrhythmia episodes escalate over time).

The developer caught that I'd over-specified Terraform — Fly.io doesn't need it. "We don't need terraform for fly I don't think." They were right. I updated the spec: Terraform for Neon DB only, Fly.io managed via CLI (`fly apps create`, `fly storage create`, `fly secrets set`, `fly deploy`).

## The Collaboration Pattern

Looking back, a clear pattern emerged:

**The developer provided vision and course corrections. I provided execution and detail.**

- Developer: "Build me an ECG app" → I planned architecture and built 14 files
- Developer: "This is only for the patient" → I redesigned the UX and built 4 new features
- Developer: "Record a video" → I recorded, compressed, and iterated on playback speed
- Developer: "Build the server" → I asked clarifying questions, then designed a full spec
- Developer: "We don't need terraform for fly" → I updated immediately

The developer never wrote code. They never debugged. They never looked up API docs. But they made every important decision: what to build, who it's for, what stack to use, when to pivot. The AI handled the how, the developer handled the what and why.

## What the MCP Changed

The Flutter MCP server was the differentiator. Without it, this would have been blind code generation — write files, hope they compile, hope the UI looks right. Instead:

- I **saw** every screen I built, on a real device
- I **interacted** with the app (tapping buttons, entering text, scrolling)
- I **found a real bug** through visual testing that static analysis couldn't catch
- I **recorded demo videos** by driving the app programmatically
- I **iterated in real-time** — screenshot, assess, fix, re-screenshot

This isn't "AI writes code." This is "AI develops software" — the full loop of design, build, deploy, test, debug, document, and deliver.

## By the Numbers

| Metric | Value |
|---|---|
| Source files created | 21 |
| Lines of Dart code | ~2,400 |
| Screens built | 7 |
| ECG patterns simulated | 6 |
| Bugs found via static analysis | 5 |
| Bugs found via visual testing | 1 |
| Screenshots taken | ~15 |
| Demo videos recorded | 3 |
| Documentation files written | 5 |
| Git commits | 7 |
| Backend API endpoints designed | 11 |
| Sample data records planned | 20 |
| Terraform resources specified | 3 |
| Times the developer wrote code | 0 |

---

*Captured from a live Claude Code session, March 24, 2026*
