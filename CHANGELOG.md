# Changelog

## 0.2.0 (4) — 2026-11-02

- Align schedule/menu insets with prayer reminders: 30 pt horizontally and 20 pt vertically.
- Top-align the notch schedule and trim its surplus height to keep the footer comfortably inside the panel, retaining five visible rows and refresh-status space.

## 0.2.0 (3) — 2026-11-02

Language-selection prerelease candidate for [#22](https://github.com/choiruladamm/nida/issues/22); not yet a published GitHub release.

- Add a persisted Indonesian/English picker in Settings; Indonesian remains the default.
- Apply the selected locale to menu, notch, Settings, onboarding, reminders, tooltips and accessibility text without restarting delivery.
- Translate retained app-owned errors at presentation time, plus prayer names, dates and pluralized durations/counts.
- Bundle native id/en String Catalogs and privacy descriptions. Preserve city names, time zones, schedule/cache identities and the delivery ledger.
- Add language persistence/fallback, catalog coverage, plural/message resolution and bilingual native fit regression coverage. Hardware acceptance remains pending.

## 0.1.0 (2) — 2026-11-02

Personal MVP verification build for [#11](https://github.com/choiruladamm/nida/issues/11). Hardware acceptance remains incomplete; this is not a stable release.

- Remove scrolling from prayer schedules and fit all five rows in the menu and notch.
- Compact schedule/menu insets and align expanded preview actions in equal-width columns.
- Replace menu Settings/Quit text with accessible icon actions and tooltips.
- Display the app version and build number in Settings → Tentang Nida.
- Record automated verification and personal installation instructions.

Earlier development builds reused `0.1.0 (1)` and cannot be distinguished by version metadata alone. Build 2 starts the unique-build policy; see README.md.
