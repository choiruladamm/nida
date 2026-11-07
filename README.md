# Nida

A native macOS prayer reminder with a camera-integrated black/glass notch panel and frosted menu bar access. Indonesian city schedules are **Kemenag via myQuran**, with validated current/next-month offline storage, two-stage reminders, explicit five-minute snooze, optional short sound, and launch at login.

**[0.2.0 (4) · published prerelease](https://github.com/choiruladamm/nida/releases/tag/v0.2.0).** Hardware acceptance remains pending in [parent #1](https://github.com/choiruladamm/nida/issues/1); see [verification evidence and remaining checks](docs/mvp-verification.md). Requires **macOS 26+**. Local builds are ad-hoc signed, not notarized for public distribution.

## Install and use

1. Download `Nida-0.2.0-build4.zip` from [Releases](https://github.com/choiruladamm/nida/releases), extract it, and move **Nida.app** to `/Applications`. Quit any existing instance through the menu bar's power icon (**Keluar**) before replacing it.
2. Open the installed app. It lives in the menu bar, without a Dock icon. Choose a city manually or explicitly request location and confirm the suggested city.
3. Open today's schedule from the menu bar or the hover handle immediately below the camera. The arrow button opens the notch; Escape/outside click dismisses the schedule. Prayer reminders stay visible while you work in other apps; use Close to dismiss early. Set separate first/follow-up display durations in Settings with 5–60-second sliders.
4. Open the gear icon (**Pengaturan**) to change city, follow-up delay (1–60 minutes; default ten), sound, or login launch. Choose Glass, Tink or Ping; **Coba suara / Test sound** works even with automatic sound off. Check the running version in **Tentang Nida → Versi**. Keep the installed path stable before enabling login launch; macOS may require approval.
5. **Coba pengingat** shows labeled **Data contoh** previews. Preview snooze does not schedule real reminders or alter delivery history.

In source builds 0.2.0 (3) and later, **Pengaturan → Bahasa → Bahasa aplikasi** offers **Bahasa Indonesia** (default) and **English**. The saved choice updates open app surfaces immediately. Schedules, city names, time zones and reminder history are unchanged; macOS-owned dialogs follow OS language behavior. See [language behavior and verification](docs/language-selection.md).

Reminders require Nida running and the Mac awake/unlocked. Recovery shows only the latest eligible event within five minutes; stale events are skipped. Cached dates work offline; missing dates never reuse yesterday's schedule. A personal follow-up is not a mosque iqomah time. Real sleep/lock recovery, login launch, fullscreen/display behavior, keyboard/VoiceOver, and visual accessibility acceptance are still pending. See the [installation and hardware checklist](docs/mvp-verification.md).

Current source includes the owner-accepted three-panel [notch redesign](DESIGN.md): hover access, a compact five-prayer strip, shared prayer-name/time reminder hierarchy, and subtle lower glass. It also updates Settings/city selection and preserves concise Jakarta district names separately from provider IDs. These changes are not yet part of the published 0.2.0 (4) download. See [revision and skill provenance](docs/ui-revision-plan.md).

## Develop

Requires Xcode 26+ and a macOS 26+ SDK; no external packages. Verified on MacBook Air M4, macOS 27.0.1, Xcode 27.0, Swift 6.4. Open `Nida.xcodeproj` with the **Nida** scheme, or use:

```sh
make build       # Nida Dev (Debug), local ad-hoc signing
make test        # Focused Swift Testing suite
make run         # Build/restart only Nida Dev; daily Stable stays running
make smoke       # Restart only Dev, then native preview/geometry/focus check
make data-smoke  # Live provider + disposable offline-cache check; internet required
make help        # All commands, including clean, project, and doctor
```

Release: `make build CONFIGURATION=Release`; output: `build/Build/Products/Release/Nida.app`. Override derived data with `BUILD_DIR=build/check` or test destination with `DESTINATION='platform=macOS,arch=arm64'`. Smoke does not simulate user input or prove hardware acceptance.

Debug output: `build/Build/Products/Debug/Nida Dev.app` (module name remains `Nida` for tests). Debug has bundle ID `dev.choiruladam.nida.dev`, a hammer menu-bar symbol and visible Dev labels. It uses its own sandbox/settings/cache/ledger, defaults to preview-only, and has no login-launch control. Use the Dev menu to open previews/schedules; its collapsed panel passes through clicks and does not hover-open over Stable.

For deliberate real-delivery testing only: `make run DEV_REMINDERS=1`. This enables Dev delivery for that launch; the next plain `make run` returns to preview-only. Both apps may deliver if Stable is also running. No Stable settings or records are copied. See [Dev/Stable workflow](docs/dev-stable.md).

Debug-only review modes: `--review-menu`, `--review-settings`, `--review-notch`, `--review-follow-up`, and `--review-refresh-error`. Stop only the current Dev instance first. These use production views without real reminder delivery; menu/Settings use review hosts. Screen capture requires OS permission and an unlocked session.

## Personal release commands

```sh
make release-test # Installer/promotion regression tests; no real app changes
make dmg          # Test/build committed HEAD, create and mount-verify a personal DMG
make promote      # Install exact origin/main only after its push CI succeeds
make rollback     # Restore the previous Stable app binary
```

Candidates, packages and the single previous app live in `~/Library/Application Support/NidaReleases`, separate from app settings and repository build output. A merge alone never installs anything. Promotion leaves Dev running and verifies the installed login-item address while preserving enabled/disabled intent. See [safety, recovery and verification limits](docs/release-workflow.md). Current personal candidates are **0.2.0 (5)**; the public download above remains build 4. Icon artwork and actual restart/login acceptance still require owner review.

## Versioning

Use `major.minor.patch` plus an increasing integer build: **0.2.0 (4)**. Language selection advances the feature version; it remains a prerelease while MVP hardware acceptance is pending. `1.0.0` follows observed acceptance, not issue closure alone. After stable release, use patch for fixes, minor for features, major for incompatible changes.

Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in both Debug/Release app configurations in `Nida.xcodeproj/project.pbxproj`. Increment the build for every changed artifact installed for testing or shared, across all release versions; reinstalling the identical artifact retains its number. Do not bump on every compile. Update [CHANGELOG.md](CHANGELOG.md), tag the committed release source `vX.Y.Z`, and never move a published tag. Keep unverified releases marked prerelease. [Apple's build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference) describes the generated bundle keys.

## Project references

- [MVP scope and tracker #1](https://github.com/choiruladamm/nida/issues/1)
- [Design system](DESIGN.md) · [UI revision evidence](docs/ui-revision-plan.md)
- [Provider, time zones, offline cache, official comparisons](docs/prayer-data.md)
- [Location setup and permissions](docs/location-setup.md)
- [Timing rules](docs/prayer-timing.md) · [Durable reminder delivery](docs/reminder-delivery.md)
- [Preferences, sound, login launch](docs/reminder-preferences.md)
- [Notch geometry and platform limits](docs/notch-prototype.md)

`make smoke` force-closes only Nida Dev before building and cycling Debug previews, then exits. Run it after tests finish; it also terminates the Dev test host. Explicit `make run CONFIGURATION=Release` restarts the Stable variant and is not the daily development command. Building Release alone does not replace `/Applications/Nida.app`. Personal CI, icons/DMG and promotion/rollback are described in [release workflow](docs/release-workflow.md); hosted/installation/hardware acceptance is tracked in #34.
