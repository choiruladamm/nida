# Personal Dev/Stable workflow

Issue: [#34](https://github.com/choiruladamm/nida/issues/34); parent [#1](https://github.com/choiruladamm/nida/issues/1). Dev/Stable isolation is merged. The personal [release workflow](release-workflow.md) defines CI, icon assets, DMG packaging and explicit promotion/rollback; actual activation/verification status is tracked in #34.

## Current variants

| | Daily Stable | Development |
| --- | --- | --- |
| Configuration | Release | Debug |
| App / executable | Nida | Nida Dev |
| Bundle ID | dev.choiruladam.nida | dev.choiruladam.nida.dev |
| Installed/output location | /Applications/Nida.app | build/Build/Products/Debug/Nida Dev.app |
| Menu-bar symbol | Moon | Hammer |
| Automatic reminders | Existing delivery behavior | Off by default; explicit per-launch opt-in |
| Login control | Existing Stable control | Omitted |
| Collapsed notch | Existing hover/click behavior | Passive and click-through; menu opens previews/schedule |

Both use the existing sandbox entitlement, without shared app groups or data migration. UserDefaults and Application Support resolve inside each bundle's container. Internal `Nida/PrayerSchedules` and `Nida/reminder-ledger.json` paths remain unchanged within those separate containers. Stable retains its previous identity and data. Dev starts with its own setup; location requests remain explicit. Tests use the Dev host; the Swift module remains Nida.

## Commands

```sh
make run                         # Build/restart Dev only
make test                        # Run tests in the Dev host
make smoke                       # Stop Dev, build/cycle previews, exit
make run DEV_REMINDERS=1          # Deliberately enable real delivery for this Dev launch
make build CONFIGURATION=Release # Build Stable candidate without installing/restarting it
```

A subsequent plain `make run` returns Dev to preview-only; opt-in is not persisted. Enabling Dev delivery while Stable runs can intentionally produce two reminders. Dev otherwise still restores live schedules; its menu/Settings clearly label its mode. Stable and Dev also have separate native app icons; Dev adds a DEV badge. Artwork acceptance remains an owner check.

Run smoke after tests; its exact process match terminates Dev test hosts too. It always targets Debug even if CONFIGURATION=Release is passed. `make run CONFIGURATION=Release` is an explicit Stable restart: it terminates Nida and opens the Release build from the build folder. Use ordinary make run for daily development; do not use Release run as an installation/promotion command. Manual `open -n` can create duplicate copies; use make run to relaunch Dev.

Keep main plus short-lived feature/fix branches. A merge never replaces the installed app. Only accepted code should become the daily Stable candidate. No app/data migration or automatic update service is introduced here. Use make dmg for an installer, make promote for CI-passed main, and make rollback for the previous binary; see release-workflow.md for safeguards and remaining gates.

## Stable bootstrap for this task

The accepted main commit `da36ec9fd0d24a2bd1b357676d02273f1c529fb4` was built as Release before variant edits. The candidate's bundle ID/executable, ad-hoc signature and installed binary hash were checked. The previous installed app was backed up under local ignored `build/stable-backups/`; a local receipt is in `build/stable-baseline.json`. The prior build-folder instance was stopped once and the accepted candidate installed/opened at `/Applications/Nida.app`. No preferences, caches or ledger were copied, removed or reinitialized. This is a one-time local bootstrap, not the future promotion mechanism or a published release. App version remains the accepted baseline's 0.2.0 (4); source SHA is recorded in the local receipt to distinguish it from the older published build.

The backup/receipt live in ignored build output; preserve them if manual recovery is needed. Future promotion/rollback must use durable storage independent of cleanable build output.

## Verification boundaries

Compile, tests, bundle metadata, sandbox paths, process counts and hashes establish only the observed checks. Real prayer delivery, manual location permission, login/logout, VoiceOver, notch glass/motion, fullscreen/Spaces and display topology still require hardware acceptance. Distinct identities imply separate macOS permissions/login records; Dev does not inherit Stable permission grants. Data sharing must never be added implicitly to make Dev setup easier.
