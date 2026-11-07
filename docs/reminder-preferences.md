# Reminder preferences

Issue: #9. Native grouped Settings extends the existing city/refresh controls with follow-up delay, sound, and login launch. It remains scrollable at the existing window size and retains isolated reminder preview actions.

## Delay and persistence

`ReminderPreferences` owns the saved `followUpDelayMinutes` and `reminderSoundEnabled` keys. Delay defaults to ten minutes. Presets five/ten and a custom text field share the same whole-number 1–60 validator. Invalid edits show a message and preserve the last saved value. An invalid stored type/range visibly falls back to ten minutes until a valid value is saved. The validated model, not a separate raw preference conversion, supplies delivery's delay.

Settings and the notch controller share this observable model. The delivery engine observes delay changes and reconciles the existing ledger. Started occurrences retain the already planned follow-up; future prayer occurrences use the new delay; explicit snoozes stay independent. Preview follow-up copy uses the current preference but previews never add delivery records or pending snoozes.

## Sound source

Sound defaults off. One persisted `reminderSoundPreset` choice applies to real entry, follow-up and snooze: **Glass** (default), **Tink**, or **Ping**. Existing enabled values are preserved. Missing/invalid selections resolve to Glass without rewriting stored values; Dev and Stable use their separate defaults domains.

The native picker saves immediately without playing audio. **Coba suara / Test sound** explicitly auditions the selected sound even while automatic sound is off, without enabling it. Visual reminder previews remain silent. One retained NSSound stops before the next playback, so repeated auditions and real reminders do not layer audio. Turning the toggle off stops current playback. Changing the selection alone does not restart it.

The app uses named macOS sounds through NSSound(named:), normally supplied in /System/Library/Sounds. User/library overrides can affect named lookup. No audio files are redistributed, downloaded or bundled. Playback follows Mac volume/output settings; successful start does not establish audibility. Missing sound/start failure preserves selection and shows a localized Settings message; later success clears it. Audio failure never blocks visual delivery or changes scheduling/ledger state.

## Launch at login

`LoginLaunch` uses `SMAppService.mainApp`, querying status rather than persisting an independent boolean. Nothing registers on startup or from tests: only the user's toggle calls registration/unregistration. Enabled, not registered, requires approval, not found, and errors are shown separately. A pending approval is registered but explicitly labeled as awaiting approval; it is never labeled active. The System Settings button opens Login Items when needed.

The status refreshes when the section appears, the app becomes active, and each operation completes. Operations disable the toggle while pending and retain real OS state after errors. The app continues running when unregistered. Login launch does not create a daemon or wake a sleeping Mac.

Keep the app in a stable installed location. Ad-hoc local builds and changing build paths can fail registration or require OS approval; report the native failure instead of claiming registration succeeded. Actual enable/disable and logout/login are manual release checks in #11; automated tests inject a service adapter and never change the user's login items.

## Verification

`make test` covers preference defaults/relaunch, valid presets/custom values, invalid input and stored types, silent playback gating/error recovery, named sound availability without playback, actual-state login transitions, pending approval, failure, duplicate registration prevention, and external status refresh. Existing ledger tests cover delay preservation, snooze, and preview isolation. Build and native smoke verify integration.

Remaining hardware checks: Settings layout/keyboard/VoiceOver, audible playback and mute/output behavior, changed delay on a real future prayer, native login registration/approval and logout/login. These remain in #11 and are not marked passed by mocked tests.

API references checked through Context7: Apple [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [NSSound](https://developer.apple.com/documentation/appkit/nssound).
