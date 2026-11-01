# Nida

A native macOS prayer reminder with a notch-connected interface.

## Development

Requires Xcode 26 or later, with a macOS 26+ SDK. Deployment target: macOS 26.
Verified development machine: MacBook Air M4, macOS 27.0.1, Xcode 27.0, Swift 6.4.

Open `Nida.xcodeproj` and run the **Nida** scheme. No external packages are required.

```sh
xcodebuild -project Nida.xcodeproj -scheme Nida -configuration Debug -derivedDataPath build build CODE_SIGN_IDENTITY=-
xcodebuild -project Nida.xcodeproj -scheme Nida -configuration Debug -derivedDataPath build test CODE_SIGN_IDENTITY=-
open build/Build/Products/Debug/Nida.app
```

Local builds use ad-hoc signing. These are personal development builds, not notarized releases. The app lives in the menu bar, with no Dock icon. Quit from its menu bar entry.

## Scope

Project setup and notch feasibility prototype only. No live timetable, location access, production reminder scheduling, or login launch yet.

Product plan and implementation tracker: https://github.com/choiruladamm/nida/issues/1

## Try the notch prototype

1. Launch the app. A moon-and-stars menu bar item and a small handle below the camera appear.
2. Click the handle to open the sample schedule, or open the menu bar panel and select **Buka di notch**.
3. Select **Masuk waktu** or **Pengingat kedua** to preview the two reminder states.
4. Click the panel before using Escape; clicking outside also collapses it. An automatic reminder does not take keyboard focus.
5. Open **Pengaturan** for all four preview states. Quit with **Keluar** in the menu bar panel.

The timetable and date are fixed demo fixtures, visibly labeled **Data contoh**. Snooze only confirms the preview action; it does not schedule anything. There is no production prayer scheduling or location permission request in this build.

The compact preview dismisses after 7 seconds and the follow-up after 18 seconds. Hovering pauses dismissal; leaving starts a fresh preview duration. A notched display is preferred. Without one, a top-center handle is used on the display containing the pointer at placement time.

Debug builds include a short native window smoke check (exits automatically):

```sh
build/Build/Products/Debug/Nida.app/Contents/MacOS/Nida --smoke-test
```

This cycles the four states and prints detected geometry, visibility, and focus observations. It does not simulate mouse/keyboard input or prove fullscreen behavior. See [prototype verification](docs/notch-prototype.md) for measured results and pending manual checks.
