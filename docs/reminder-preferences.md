# Reminder preferences

Issue: #9. Native grouped Settings extends the existing city/refresh controls with follow-up delay, sound, and login launch. It remains scrollable at the existing window size and retains isolated reminder preview actions.

## Delay and persistence

`ReminderPreferences` owns the saved `followUpDelayMinutes` and `reminderSoundEnabled` keys. Delay defaults to ten minutes. Presets five/ten and a custom text field share the same whole-number 1–60 validator. Invalid edits show a message and preserve the last saved value. An invalid stored type/range visibly falls back to ten minutes until a valid value is saved. The validated model, not a separate raw preference conversion, supplies delivery's delay.

Settings and the notch controller share this observable model. The delivery engine observes delay changes and reconciles the existing ledger. Started occurrences retain the already planned follow-up; future prayer occurrences use the new delay; explicit snoozes stay independent. Preview follow-up copy uses the current preference but previews never add delivery records or pending snoozes.

## Sound source

Sound defaults off. One persisted `reminderSoundPreset` applies to real entry, follow-up and snooze: **Bedug** (default), **Bambu / Bamboo**, or **Petik / Pluck**, using stable IDs `bedug`, `bamboo`, `pluck`. The existing enabled value is preserved. Missing/invalid values and the earlier unmerged Glass/Tink/Ping IDs resolve to Bedug without automatic writeback or enabling sound. Dev and Stable keep separate defaults domains.

The picker saves immediately without audio. **Coba suara / Test sound** explicitly auditions the selection even when automatic sound is off. Visual panel previews stay silent. A single retained playback object stops before replacement; disabling sound stops current playback. Changing selection alone does not start or restart it.

Final mono 44.1 kHz/16-bit WAV resources are bundled with explicit Xcode resource membership: Bedug 1.5 s, Bamboo 1.1 s, Pluck approximately 0.917 s (about 310 KB total). NSSound loads a Bundle.main URL rather than resolving a system sound name. No network request or user sound-library override affects playback. Missing/corrupt assets or failed starts preserve selection and show the localized Settings error; successful playback clears it. Audio never blocks visual delivery or alters event/ledger state.

Bedug is adapted from redafs/Fahrul (Fortis Record), CC BY 4.0. Bamboo is gmni's CC0 windchime recording; Pluck is railkill's CC0 two-note kalimba. Bedug/Bamboo use lossy public previews, not lossless originals. `Nida/Resources/Sounds/SoundCredits.txt` records source URLs, exact edits, gains and SHA-256 hashes; full license texts ship with both variants. About Nida includes a bilingual credit acknowledgment and Bedug source/license link. Peak attenuation and tiny edge fades prevent technical clipping/cut clicks; perceived quality and repeated-use comfort remain owner checks, not inferred from waveform inspection.

## Launch at login

`LoginLaunch` uses `SMAppService.mainApp`, querying status rather than persisting an independent boolean. Nothing registers on startup or from tests: only the user's toggle calls registration/unregistration. Enabled, not registered, requires approval, not found, and errors are shown separately. A pending approval is registered but explicitly labeled as awaiting approval; it is never labeled active. The System Settings button opens Login Items when needed.

The status refreshes when the section appears, the app becomes active, and each operation completes. Operations disable the toggle while pending and retain real OS state after errors. The app continues running when unregistered. Login launch does not create a daemon or wake a sleeping Mac.

Keep the app in a stable installed location. Ad-hoc local builds and changing build paths can fail registration or require OS approval; report the native failure instead of claiming registration succeeded. Actual enable/disable and logout/login are manual release checks in #11; automated tests inject a service adapter and never change the user's login items.

## Verification

`make test` covers preference defaults/relaunch, valid presets/custom values, invalid input and stored types, silent playback gating/error recovery, named sound availability without playback, actual-state login transitions, pending approval, failure, duplicate registration prevention, and external status refresh. Existing ledger tests cover delay preservation, snooze, and preview isolation. Build and native smoke verify integration.

Remaining hardware checks: Settings layout/keyboard/VoiceOver, audible playback and mute/output behavior, changed delay on a real future prayer, native login registration/approval and logout/login. These remain in #11 and are not marked passed by mocked tests.

API references checked through Context7: Apple [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [NSSound](https://developer.apple.com/documentation/appkit/nssound).
