# MVP verification and personal installation

Release gate: [issue #11](https://github.com/choiruladamm/nida/issues/11), following merged PR #19. Hardware acceptance remains open.

## Compact menu follow-up — 2026-11-02

Product commit `2323856` passed `make test` (89 tests in 14 suites) and `make build` (Debug) after the owner finalized the menu iteration. Logs: `/tmp/nida-menu-final-test.log` and `/tmp/nida-menu-final-build.log`. `git diff --check` passed. Smoke and the broader hardware matrix were not rerun; the earlier smoke evidence below belongs to the preceding notch revision. No release artifact was produced.

## Three-panel notch revamp — 2026-11-02

Tracked in [#25](https://github.com/choiruladamm/nida/issues/25). The owner accepted prayer-time, personal follow-up and today's schedule visuals after iterative screenshots and local runs, including the final rounded shoulders, lower glass boundary and wider insets. The current visual contract is [DESIGN.md](../DESIGN.md); [ui-revision-plan.md](ui-revision-plan.md) records design decisions, documentation references and skills actually used. This source revision is not included in the published 0.2.0 (4) archive.

Final branch checks:

| Check | Result |
| --- | --- |
| `make test` | Passed: 89 tests in 14 suites |
| `make build` | Passed: Debug |
| `make smoke` with normal app stopped | Passed: 1470 × 956 pt screen, 179 × 32 pt camera, panel visible, frontmost preserved, panel non-key, delivery session available |
| `make -n run` | Confirmed build → force-close exact Nida process name → open new app instance |
| `git diff --check` | Passed |

The first final test run exposed an obsolete assertion against the old fixed reminder-height budget. The corrected check bounds naturally fitted content to the actual hosting canvas and still verifies that silhouette height equals content height. The full suite then passed. Geometry coverage includes measured, unnotched and wide-camera inputs, both app languages, complete schedules and refresh errors. Alias tests preserve provider identity and unique choice IDs; persistence tests preserve display names across refresh/relaunch and reset them on manual provider selection.

Owner visual acceptance does not complete the full hardware sheet below. Real scheduled delivery/snooze, all keyboard and VoiceOver paths, OS accessibility toggles, fullscreen/Spaces, external displays/scaling, sleep/lock/login and arbitrary-background contrast remain unverified for this revision. Native smoke checks visibility/focus, not visual quality. Release build, installation/version bump and publication were not requested for this PR. The existing 520 × 480 pt hosting canvas still bounds supported content.

Logs: `/tmp/nida-final-test.log`, `/tmp/nida-final-build.log`, `/tmp/nida-final-smoke.log`; xcresult remains under ignored `build/Logs/Test/`. Screenshots provided during iteration remain local and are not included in the PR. After smoke, the Debug app was reopened for the owner.

## Recorded automated evidence

Run on 2026-11-02 from clean tracked checkout `092a464a84a816196ae20436fb657489b7084714`, with a new derived-data directory (`build/issue-11-clean`). No product source changes were needed.

Environment: macOS 27.0.1 (26A434), Xcode 27.0 (27A266a), Swift 6.4, arm64 Mac. Minimum deployment: macOS 26.

| Check | Result |
| --- | --- |
| `make build BUILD_DIR=build/issue-11-clean` | Passed, Debug |
| `make test BUILD_DIR=build/issue-11-clean` | Passed, 81 tests in 13 suites |
| `make build CONFIGURATION=Release BUILD_DIR=build/issue-11-clean` | Passed |
| `make data-smoke BUILD_DIR=build/issue-11-clean` | Passed: 517 cities, 61 validated days, two months restored through offline transport; disposable cache removed |
| `codesign --verify --deep --strict` on Release and installed copy | Passed; ad-hoc signature, no signing team |
| Release architecture | Universal arm64/x86_64; Intel execution untested |
| `make smoke BUILD_DIR=build/issue-11-clean` | Passed after owner quit normal app: 1470 × 956 pt screen, 179 × 32 pt camera, panel visible, frontmost preserved, panel non-key, delivery session available |

Build/test logs and the personal-use ZIP are in ignored `build/issue-11-evidence/`. The xcresult is under `build/issue-11-clean/Logs/Test/`. Compiler output includes an unnecessary `try` in an existing test, a test-framework architecture warning, and App Intents metadata/runtime diagnostics; these did not fail the suite.

The suite covers stage ordering, persistent snooze/relaunch, deduplication, latest-only recovery, stale expiry, lock/session gates with simulated inputs, city changes, frozen started follow-ups, clock corrections, calendar/time-zone boundaries, corrupt/write-failed storage, offline coverage, and preference/login adapters. These are logic proofs, not observation of real sleep, lock, login or panel interaction.

After smoke exited, the installed Release at `/Applications/Nida.app` was opened for owner-assisted hardware verification. Opening the app does not itself establish any pending hardware result.

### Owner-reported schedule scrolling follow-up

The owner observed scrolling in the installed menu schedule. The shared schedule scroll container was removed, menu height now follows its content, and notch schedule content height increased from 360 to 380 pt (412 pt including the measured camera clearance; 464 pt with a refresh status). `make test` passed 82 tests including full cached schedule/status fitting coverage; Debug/Release builds and native smoke passed. The installed Release was replaced, its signature verified, and reopened. This revision changes the verified source from the clean merge baseline above; actual menu/notch visual and scrolling acceptance is pending owner review.

The owner subsequently requested a denser menu footer and icon-only Settings/Quit actions. The footer now uses one row with 12 pt vertical insets, shared 28 pt glass icon targets, Indonesian tooltips/accessibility labels, and vertically stacked preview choices when expanded. This presentation-only follow-up was compiled in Debug/Release; the earlier 82-test result predates this footer change. Actual footer interaction/VoiceOver acceptance remains pending.

The owner rejected the expanded preview indentation and oversized margins. The schedule and footer now share 24 pt horizontal / 12 pt vertical insets. Preview expansion uses a separate full-width row of two equal-width buttons below the toggle and icon controls; it no longer places preview content inside a narrow disclosure column. Actual expanded/collapsed layout and keyboard/VoiceOver review remain pending.

After this compact-layout revision, all 82 tests, Debug/Release builds, and native smoke passed. The installed Release was replaced after owner quit, signature-verified, and reopened. Logs are saved as `nida-compact-*.log` in the evidence directory.

### Versioned verification artifact

Versioning now starts unique test-artifact numbering at `0.1.0 (2)`. Debug and Release builds passed and their generated Info.plist values were explicitly checked for version `0.1.0` and build `2`. Settings displays the running bundle's version/build. The signed Release was installed at `/Applications/Nida.app` while Nida was stopped, signature-verified, and opened. Its archive is `build/issue-11-evidence/Nida-0.1.0-build2.zip`; the older baseline ZIP remains historical evidence. Tests were not repeated for this metadata/display-only change; the last 82-test run predates it. No release tag or stable-release acceptance is claimed.

For the owner-authorized PR/prerelease preparation, the complete suite was rerun after the version display change: 82 tests in 13 suites passed. The README was condensed and the existing build-2 archive retained unchanged. The GitHub `v0.1.0` prerelease points at the committed source proposed by this PR; publishing it does not complete #11 hardware acceptance.

Existing provider comparisons in [prayer-data.md](prayer-data.md) matched 45 sampled values across Jakarta, Denpasar and Jayapura. They were not repeated in this run and do not establish agreement for the owner's selected city.

## Install and use

1. Quit any running Nida using menu bar **Keluar**. Keep only one running instance.
2. The verified Release was copied to `/Applications/Nida.app`. For a fresh build, run `make build CONFIGURATION=Release`, then copy `build/Build/Products/Release/Nida.app` to `/Applications` using Finder while Nida is stopped. Keep this installed path stable.
3. Open `/Applications/Nida.app` in Finder. Nida lives in the menu bar and has no Dock icon. Select a city manually or explicitly choose **Gunakan lokasi saat ini**, then confirm the city. Inspect today's date, city and all five times in menu bar and notch.
4. In **Pengaturan**, choose the personal follow-up delay (default ten minutes), optionally enable sound, and enable launch at login only from this installed copy. Approve in macOS Login Items if requested. A pending approval is not an active login item; see Apple's [status documentation](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval).
5. Verify login launch by logging out/in after saving other work. Confirm exactly one Nida instance runs from `/Applications/Nida.app`. Disable the setting and repeat to confirm it no longer starts. Registration, approval, and actual login launch are still unverified.
6. For updates, disable login launch in the old app, quit via **Keluar**, replace the app, launch the installed copy and re-enable it. Recheck actual OS status; ad-hoc rebuilds can change signing identity and permission behavior.

This is a local personal-use build, not Developer ID signed or notarized for public distribution. Cached dates work offline; missing dates have no invented schedule. Real reminders require Nida running and the Mac awake/unlocked. Preview controls are labeled **Data contoh** and never schedule real reminders. Sound is a short system sound, not full adhan.

## Hardware execution sheet

Run on the installed Release with real schedules. For each row record timestamp/time zone, city/date, configured delay, expected event IDs/times, observed panel/action, ledger outcome, and pass/fail. Do not edit the real ledger, change the system clock, or mistake preview behavior for delivery proof. Preserve user data when testing first-launch or denied-permission states; use a separate macOS test account if necessary.

| Order | Scenario and expected result | Status |
| --- | --- | --- |
| 1 | Select/confirm city, compare representative selected-city dates with official Kemenag; menu/notch/Settings agree | Pending |
| 2 | Awake real prayer entry → personal follow-up → explicit five-minute snooze; one presentation per stage, no stolen typing focus. Entry close preserves follow-up; follow-up close ends chain | Pending |
| 3 | Relaunch after handled entry and with pending snooze; no replay, pending stages retain original times. Change delay: only future occurrences change | Pending |
| 4 | Sleep through one/several stages; wake within inclusive five-minute grace shows latest eligible only, later wake skips stale events. Repeat lock/unlock; no presentation while locked | Pending |
| 5 | Disable network after cached restoration; same valid dates remain available in both surfaces and reminders still work. Missing coverage stays unavailable. Restore network | Pending |
| 6 | Change city while old reminder is open; old panel/pending snooze disappears, no stale async selection wins; return preserves handling history | Pending |
| 7 | Manual setup and location allow/deny/unavailable/ambiguous flows; no permission request before explicit action, usable manual fallback | Pending |
| 8 | Tab/Shift-Tab, Space/Return, Escape/outside click, focus indicator, VoiceOver in menu/notch/Settings; keyboard activity postpones dismissal | Pending |
| 9 | Desktop/fullscreen/Spaces, auto-hidden menu bar, scaling, external display/clamshell; one correctly placed panel, stable camera silhouette | Pending |
| 10 | Light/dark wallpapers and appearance, Reduce Motion/Transparency, Increase Contrast, interrupted transitions; owner accepts actual glass/readability/motion | Pending |
| 11 | Sound off/on, explicit audition, mute and selected audio output; restore original preferences | Pending |
| 12 | Installed-path login enable/approval/logout/login/disable; exactly one installed instance | Pending |
| 13 | City-local midnight/month rollover and device clock/zone recovery; no duplicate storm, correct next date and cache coverage | Pending |
| 14 | Idle CPU/network observation with panels closed; no busy polling or continuous location tracking | Pending |

Lock detection includes undocumented OS notifications/session flags and is a release gate on the target OS. Fullscreen/Spaces visibility is subject to system-managed surfaces. A crash after durable handling but before presentation can miss a reminder in preference to duplicating it. No wake alarm or delivery after Quit is promised. See [delivery contract](reminder-delivery.md).

Do not close #11 or label the MVP hardware-verified until observed results replace the pending rows. Tests and native smoke cannot establish those results.
