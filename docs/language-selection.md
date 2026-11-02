# App language selection

Issue: [#22](https://github.com/choiruladamm/nida/issues/22). Source build: **0.2.0 (3)**, prerelease candidate.

## Behavior

Settings → Bahasa → Bahasa aplikasi offers **Bahasa Indonesia** and **English**. The default is Indonesian, including on English-language Macs. The existing `ReminderPreferences` model persists the enum's `id`/`en` raw value under `appLanguage`; absent or unsupported values fall back to Indonesian. There is no system-language mode or extra language in this slice.

Every production and Debug-review SwiftUI hosting root receives the shared locale through `appLanguage`. This changes the environment without replacing view identity or restarting services. City-selection sheets inherit it. Onboarding's native window title follows the same preference. Native SwiftUI literals use Localizable.xcstrings; non-view messages retain LocalizedStringResource and resolve with the selected locale at display time. Location detection retains its typed failure. An already-visible error can therefore switch language without repeating its failed operation.

English prayer labels are Fajr, Dhuhr, Asr, Maghrib and Isha. Display dates follow the selected locale; prayer times remain 24-hour and tied to the selected city's time zone. Provider city names, source attribution, WIB/WITA/WIT, administrative matching/reverse-geocoding locale, POSIX parsing, Codable identities and cache/ledger formats are unchanged. Language changes do not call refresh, request location, modify pending snoozes or consume reminder stages. Delivery observation continues to track schedules and delay, not language.

InfoPlist.xcstrings supplies Indonesian/English privacy descriptions for OS language selection. The in-app picker does not change macOS-owned permission dialogs, System Settings, standard system controls or underlying OS error diagnostics. Such content follows OS localization and may require relaunch/system configuration; Nida-owned explanatory text follows the app picker. Technical LocalizedError descriptions remain the Indonesian diagnostic fallback; app views use deferred localized messages instead.

## Verification

On macOS 27.0.1 / Xcode 27.0 / arm64:

- `make test`: **86 tests in 14 suites passed**. New tests cover default/invalid/persisted language, unchanged other preferences, observation invalidation and retained error resolution, both prayer-name sets, singular/plural minutes/days/follow-up text, and equal compiled catalog coverage. The cached schedule/refresh-error fitting test runs in both locales. Existing scheduling, cache, ledger, snooze and lifecycle logic coverage still passes.
- Debug and Release builds passed. Native resource compilation, version `0.2.0`/build `3`, bilingual privacy bundles, and Release signature were verified.
- All 127 compiler-extracted app keys have id/en entries; interpolation placeholder signatures match across translations, including plural variants.
- After the owner quit the normal app, `make smoke` passed: 1470 × 956 pt screen, 179 × 32 pt camera, panel visible, frontmost application preserved, panel non-key, delivery session available. The Release was copied to `/Applications/Nida.app`, signature and installed metadata `0.2.0 (3)` verified, and opened. The artifact is `build/issue-22-evidence/Nida-0.2.0-build3.zip`; it has not been published as a GitHub release. Fitting tests and smoke do not establish compositor-rendered glass, live language switching, truncation of every state or VoiceOver quality.

The first catalog-coverage test attempted to read repository source from the sandboxed test host and blocked on file access. It was replaced with checks of the compiled resources inside the app bundle. The full suite was rerun without that access; no additional permission or sandbox entitlement was added.

## Manual checks still required

- Switch id → en → id with Settings, menu, notch, city sheet, error message and real/preview reminder open. Verify immediate text/date/help updates, preserved state/focus and unchanged delivery timing.
- Relaunch and verify the language persists; inspect first-launch/manual location and OS-owned permission wording separately.
- Inspect five-row schedules, expanded preview buttons, reminders, errors and Settings in both languages, including longer English copy and accessibility settings. Confirm no clipping or new schedule scrolling.
- Exercise keyboard and VoiceOver labels/values/tooltips in both languages. Verify real reminder/snooze and ledger behavior on hardware alongside the outstanding MVP acceptance matrix.

These checks are pending, not passed by tests or changing the app's language in isolation. No claim of completed MVP hardware acceptance is made.
