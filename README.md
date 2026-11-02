# Nida

A native macOS prayer reminder with a notch-connected interface.

## Development

Requires Xcode 26 or later, with a macOS 26+ SDK. Deployment target: macOS 26.
Verified development machine: MacBook Air M4, macOS 27.0.1, Xcode 27.0, Swift 6.4.

Open `Nida.xcodeproj` and run the **Nida** scheme. No external packages are required.

```sh
make help      # List commands
make build     # Build the app
make test      # Run tests
make run       # Build and open Nida
make smoke     # Cycle native previews and exit
make data-smoke # Check live API + offline storage (uses internet)
make project   # Open Xcode
make doctor    # Show local toolchain versions
make clean     # Clean build products
```

`make run` opens the current app instance if one is already running. Quit **Keluar** from Nida's menu bar before running it again to load a newly built binary. Quit the normal instance before `make smoke` to avoid overlapping prototype panels.

Optional overrides: `make build CONFIGURATION=Release`, `make test BUILD_DIR=build/check`, or `make test DESTINATION='platform=macOS,arch=arm64'`. Builds use local ad-hoc signing.

Local builds use ad-hoc signing. These are personal development builds, not notarized releases. The app lives in the menu bar, with no Dock icon. Quit from its menu bar entry.

## Scope

The notch geometry retains its prototype verification boundary. First launch offers automatic location with city confirmation or manual selection. Settings supports location refresh, real daily schedules, and validated current/next-month offline storage. Menu bar, notch, and Settings show the selected city’s real schedule and next prayer. Two-stage notch reminders run while the app is open and the Mac is awake/unlocked. Settings includes validated 5/10-minute presets or a custom 1–60-minute follow-up delay, optional short sound (off by default), and optional native launch at login.

Product plan and implementation tracker: https://github.com/choiruladamm/nida/issues/1

## Visual direction

The owner’s supplied frosted Liquid Glass reference is the visual authority. Shared palette, spacing, and radii live in `Nida/NidaStyle.swift`; see [DESIGN.md](DESIGN.md).

## Try the notch prototype

1. Launch the app. A moon-and-stars menu bar item appears. The physical notch is left visually unchanged while collapsed.
2. Hover immediately below the camera to reveal the small handle, then click to open today’s schedule, or open the menu bar panel and click the circular **arrow-up-right** button.
3. Select **Masuk waktu** or **Pengingat kedua** to preview the two reminder states.
4. Click the panel before using Escape; clicking outside also collapses it. An automatic reminder does not take keyboard focus.
5. Open **Pengaturan** for all four preview states. Quit with **Keluar** in the menu bar panel.

The schedule uses real city-local data. Reminder previews still use fixed fixtures, visibly labeled **Data contoh**. Snooze only confirms the preview action; it does not schedule anything. Real reminders use a separate durable delivery ledger; preview controls never schedule reminders. Location permission is requested only after choosing **Gunakan lokasi saat ini**.

The compact preview dismisses after 7 seconds and the follow-up after 18 seconds. Hovering pauses dismissal; leaving starts a fresh preview duration. A notched display is preferred. Without one, a hover-revealed top-center handle is used on the display containing the pointer at placement time.

Debug builds include a short native window smoke check (exits automatically):

```sh
make smoke
```

This cycles the four states and prints detected geometry, visibility, and focus observations. It does not simulate mouse/keyboard input or prove fullscreen behavior. See [prototype verification](docs/notch-prototype.md) for measured results and pending manual checks.

## Real prayer schedules

On first launch, use **Gunakan lokasi saat ini**, confirm the suggested city, or choose **Pilih kota manual**. Existing users keep their saved city. To change it later, open **Pengaturan → Lokasi jadwal**, choose or detect a city, then inspect **Jadwal hari ini**. The search runs locally against the provider's cached catalog. The app fetches the selected city's current and next month and reuses cached dates offline. Refresh failures preserve usable data and show a message; unavailable dates are never replaced with yesterday's timetable.

The menu bar and notch share one schedule store, with a local date, next-prayer countdown, elapsed styling, refresh, and Settings access. Valid schedules remain visible during refresh failures; missing dates stay unavailable. Reminder preview buttons still use labeled fixtures; real event delivery runs separately. Real source attribution is **Kemenag via myQuran**. See [provider contract, time zones, and official comparisons](docs/prayer-data.md) and [location setup and verification](docs/location-setup.md).

`make data-smoke` uses live internet requests and a disposable cache, verifies offline restoration, and leaves the selected city unchanged. It is separate from the offline unit suite.

## Timing foundation

Settings provides reminder preferences alongside city selection and real schedules. The timetable includes **Berikutnya**, the city-local prayer time, and a system countdown. At each prayer boundary it advances to the next prayer; after Isha it shows tomorrow's Subuh only when tomorrow's schedule exists.

The pure timing engine also produces stable entry/follow-up/snooze events with delay-change, expiry, collision, and recovery rules. The delivery layer now persists and presents these events through the notch. See [delivery contract](docs/reminder-delivery.md). See [timing contract](docs/prayer-timing.md).

## Reminder preferences

Open **Pengaturan** to choose the follow-up delay, enable the short sound, or register Nida to open at login. Invalid delay input leaves the last saved value unchanged. Started follow-ups and explicit snoozes keep their original times; new prayer occurrences use the new delay.

Login registration reflects macOS status and can require approval in System Settings. Keep the app at a stable installed path before enabling it. Preview buttons remain visual-only and do not affect real delivery; **Coba suara** auditions audio only when sound is enabled. See [settings contract and manual checks](docs/reminder-preferences.md).

## Accessibility and motion

Notch controls share explicit contrasting primary/secondary colors, native glass feedback, larger icon targets, and an opaque fallback for Reduce Transparency/Increase Contrast. Increase Contrast also outlines the next prayer; elapsed rows retain readable text. Reduce Motion disables panel size animation. Keyboard activity refreshes the reminder timeout, and Escape/outside-click dismissal is retained. Visual, keyboard, VoiceOver, and wallpaper checks remain part of the final hardware gate in #11.

## Native design review (Debug)

The latest material/layout revision uses AppKit Liquid Glass and unified native Settings chrome. See [revision plan and review findings](docs/ui-revision-plan.md). With the normal app stopped, Debug builds accept `--review-menu`, `--review-settings`, `--review-notch`, or `--review-follow-up` to inspect the production views without starting real delivery. Menu/Settings use native review hosts; the notch uses its actual panel. Screen capture requires the user's OS permission and an unlocked session.

Debug `--review-refresh-error` shows a simulated rate-limit status on the real notch panel after normal cached restoration; it never forces requests or starts reminder delivery. This reproduces error layout without spamming the live provider.
