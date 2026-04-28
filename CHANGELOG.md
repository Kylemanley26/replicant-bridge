CHANGELOG

project rename: Replicant-Bridge v2

New Scaffolding: replicant-bridge/
├── core/
│   ├── preflight.sh          # Device state, ADB auth, connection validation
│   ├── case_init.sh          # Examiner ID, case #, device fingerprint, CoC header
│   ├── acquire.sh            # READ-ONLY collection — hashes everything
│   ├── analyze.py            # Runs against acquired artifacts, never the device
│   └── report.py             # DFIR-formatted output (HTML + JSON + txt)
├── modules/
│   ├── system_state.sh       # Knox, SELinux, bootloader, encryption state
│   ├── app_artifacts.sh      # Packages, permissions, installers
│   ├── comms.sh              # SMS, call log, notification listeners
│   ├── network.sh            # Connections, VPN, proxy, DNS cache
│   ├── persistence.sh        # Boot receivers, device admins, accessibility
│   ├── location.sh           # Location mode, providers, background access
│   ├── accounts.sh           # Synced accounts, auth tokens
│   └── sqlite_pull.sh        # ADB backup / file pull for DB extraction
├── gui/                      # Phase 2 — Electron or Tauri wrapper
├── output/
│   ├── CASE_<id>/
│   │   ├── acquisition.log   # Immutable command audit trail
│   │   ├── chain_of_custody.txt
│   │   ├── hashes.sha256
│   │   ├── raw/              # Unmodified artifact dumps
│   │   └── reports/
└── replicant-bridge.sh       # Master orchestrator

goal: Alignment with GASF threat modeling, To integrate proper implementation phases, potentially implement proper risk analysis.

ie.Acquisition ≠ Analysis ≠ Remediation — these must be strictly separated phases. Current bladerunner.sh mixes all three. GASF-compatible means collection first, always, with no device modification during that phase.

Forensic soundness requirements:
Hash every artifact at collection (SHA-256)
Immutable audit log (every ADB command + timestamp + output hash)
Case metadata captured before any collection begins
Chain of custody documentation generated automatically
Examiner ID attached to the case

Tech Stack:
Layer: Acquisition -> Bash + ADB -> Minimal deps, portable, direct device access

Layer: Analysis/parsing -> Python 3 -> SQLite, JSON, hashing, regex — all native

Layer: Report generation ->Python (Jinja2 templates) -> Clean HTML output, separates logic from presentation

Layer: GUI (Phase 2) -> Tauri (Rust+WebView) -> Lighter than Electron, ships as single binary, you already have frontend skills

Layer: Output formats -> JSON + HTML + TXT -> JSON feeds the GUI; TXT is court-admissible; HTML is examiner-friendly


GASF Artifact Coverage Map
What the tool needs to collect to be comprehensive:

Tier 1 — Logical (no root needed):
Package list + installer sources + permissions
SMS/MMS (via content://sms)
Call log (via content://call_log)
Contacts
Browser history (Chrome via backup)
Accounts (adb shell accounts)
Running processes + services
Network state + connections
System properties (full getprop dump)
Installed keyboards + accessibility services
Device admin + VPN apps
Location settings + background grantees
Notification listeners

Tier 2 — Requires backup API or root:
App-specific SQLite DBs (WhatsApp, Signal, Telegram)
Shared preferences XML files
/data/data/<pkg>/ app sandboxes

Tier 3 — Physical (out of scope for ADB-only tool, note in docs):
Raw flash image
Deleted file recovery
Chip-off


Immediate Next Steps
Rewrite case_init.sh — captures examiner, case #, generates UUID, records full device fingerprint (IMEI via getprop, serial, Android build, timestamp) into CoC header before any collection
Refactor the package loop bottleneck — single dumpsys package dump → grep, cuts runtime ~80%
Add hashing layer — every output file gets SHA-256'd into hashes.sha256 post-collection
Strict phase gate — acquire.sh exits before analyze.py runs; remediation is a completely separate opt-in script with explicit consent prompt

