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
