# Live schedule panels

Issue: #7. Menu bar and notch host the same `ScheduleView` and the same `PrayerDataStore` instance owned by `NotchPanelController`. Settings reads that instance too. No provider logic or schedule copies live in the views.

The panel displays city-local date, five prayer times, next-prayer highlight and countdown, elapsed styling, and source/time zone. The pure timeline supplies exact prayer and midnight boundaries; SwiftUI's explicit timeline updates the rows there while the system timer renders the countdown. After Isya, tomorrow's Subuh appears only with exact next-day coverage. A missing next day is stated explicitly.

Opening either view restores/refreshes coverage. The store guards simultaneous loads and the repository coalesces requests and reuses today's cache. Date changes reload current/next-month coverage; wake refreshes it. Refresh does not erase valid rows; failures appear beside retained data. Without today's coverage, no old timetable is substituted. City choice is reachable through Settings; refresh is inline and Quit remains in the menu bar.

The notch retains the physical camera clearance and 360 × 358 pt outer geometry. Its 326 pt content region scrolls when content, error messages, or accessibility settings need more room. No black cap or wider collapsed notch is added. Automatic production reminders remain #8; the existing reminder previews retain their demo disclosures.

Verification: `make test` exercises shared store ownership, concurrent restoration without extra provider calls, pure next-day/midnight/expiry coverage, offline recovery, and native content fit. `make smoke` checks real panel geometry and focus. Native SettingsLink activation from the manually hosted notch, keyboard/VoiceOver, glass readability, scrolling, midnight on a running Mac, fullscreen, and external displays require hardware review; automated fit checks are not visual approval.
