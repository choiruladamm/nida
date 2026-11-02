# Reminder preferences

Issue: #9. Native grouped Settings extends the existing city/refresh controls with follow-up delay, sound, and login launch. It remains scrollable at the existing window size and retains isolated reminder preview actions.

## Delay and persistence

`ReminderPreferences` owns the saved `followUpDelayMinutes` and `reminderSoundEnabled` keys. Delay defaults to ten minutes. Presets five/ten and a custom text field share the same whole-number 1–60 validator. Invalid edits show a message and preserve the last saved value. An invalid stored type/range visibly falls back to ten minutes until a valid value is saved. The validated model, not a separate raw preference conversion, supplies delivery's delay.

Settings and the notch controller share this observable model. The delivery engine observes delay changes and reconciles the existing ledger. Started occurrences retain the already planned follow-up; future prayer occurrences use the new delay; explicit snoozes stay independent. Preview follow-up copy uses the current preference but previews never add delivery records or pending snoozes.

## Sound source

Sound defaults off and is checked only after a real event is durably recorded and presented. The app resolves the named macOS **Glass** sound through `NSSound(named:)`; there is no downloaded/bundled sound asset, full adhan, or redistributed Apple audio file. Source: the user's installed macOS named sound library (normally `/System/Library/Sounds/Glass.aiff`, provided under their macOS license; user sound-library overrides can affect named lookup). No third-party sound license is added.

**Coba suara** explicitly auditions the sound when enabled; visual reminder previews stay silent. Muted system volume, audio output, and user system settings still apply. Missing sound or failure to start playback produces a visible Settings message; it does not block the visual reminder. Disabling the toggle prevents future playback rather than interrupting an already playing short sound.

## Launch at login

`LoginLaunch` uses `SMAppService.mainApp`, querying status rather than persisting an independent boolean. Nothing registers on startup or from tests: only the user's toggle calls registration/unregistration. Enabled, not registered, requires approval, not found, and errors are shown separately. A pending approval is registered but explicitly labeled as awaiting approval; it is never labeled active. The System Settings button opens Login Items when needed.

The status refreshes when the section appears, the app becomes active, and each operation completes. Operations disable the toggle while pending and retain real OS state after errors. The app continues running when unregistered. Login launch does not create a daemon or wake a sleeping Mac.

Keep the app in a stable installed location. Ad-hoc local builds and changing build paths can fail registration or require OS approval; report the native failure instead of claiming registration succeeded. Actual enable/disable and logout/login are manual release checks in #11; automated tests inject a service adapter and never change the user's login items.

## Verification

`make test` covers preference defaults/relaunch, valid presets/custom values, invalid input and stored types, silent playback gating/error recovery, named sound availability without playback, actual-state login transitions, pending approval, failure, duplicate registration prevention, and external status refresh. Existing ledger tests cover delay preservation, snooze, and preview isolation. Build and native smoke verify integration.

Remaining hardware checks: Settings layout/keyboard/VoiceOver, audible playback and mute/output behavior, changed delay on a real future prayer, native login registration/approval and logout/login. These remain in #11 and are not marked passed by mocked tests.

API references checked through Context7: Apple [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [NSSound](https://developer.apple.com/documentation/appkit/nssound).
