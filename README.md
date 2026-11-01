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

The notch remains a feasibility prototype. Settings now supports manual city selection, real daily schedules, and validated current/next-month offline storage. Automatic location, next-prayer calculation, production reminders, and login launch are not implemented yet.

Product plan and implementation tracker: https://github.com/choiruladamm/nida/issues/1

## Visual direction

The owner’s supplied frosted Liquid Glass reference is the visual authority. Shared palette, spacing, and radii live in `Nida/NidaStyle.swift`; see [DESIGN.md](DESIGN.md).

## Try the notch prototype

1. Launch the app. A moon-and-stars menu bar item appears. The physical notch is left visually unchanged while collapsed.
2. Hover immediately below the camera to reveal the small handle, then click to open the sample schedule, or open the menu bar panel and click the circular **arrow-up-right** button.
3. Select **Masuk waktu** or **Pengingat kedua** to preview the two reminder states.
4. Click the panel before using Escape; clicking outside also collapses it. An automatic reminder does not take keyboard focus.
5. Open **Pengaturan** for all four preview states. Quit with **Keluar** in the menu bar panel.

The timetable and date are fixed demo fixtures, visibly labeled **Data contoh**. Snooze only confirms the preview action; it does not schedule anything. There is no production prayer scheduling or location permission request in this build.

The compact preview dismisses after 7 seconds and the follow-up after 18 seconds. Hovering pauses dismissal; leaving starts a fresh preview duration. A notched display is preferred. Without one, a hover-revealed top-center handle is used on the display containing the pointer at placement time.

Debug builds include a short native window smoke check (exits automatically):

```sh
make smoke
```

This cycles the four states and prints detected geometry, visibility, and focus observations. It does not simulate mouse/keyboard input or prove fullscreen behavior. See [prototype verification](docs/notch-prototype.md) for measured results and pending manual checks.

## Real prayer schedules

Open **Pengaturan → Lokasi jadwal**, choose a city/regency, then inspect **Jadwal hari ini**. The search runs locally against the provider's cached catalog. The app fetches the selected city's current and next month and reuses cached dates offline. Refresh failures preserve usable data and show a message; unavailable dates are never replaced with yesterday's timetable.

The menu bar/notch schedule and reminder buttons still show labeled preview fixtures until the next UI/scheduling issues. Real source attribution is **Kemenag via myQuran**. See [provider contract, time zones, and official comparisons](docs/prayer-data.md).

`make data-smoke` uses live internet requests and a disposable cache, verifies offline restoration, and leaves the selected city unchanged. It is separate from the offline unit suite.
