# Notch reminder delivery

Issue: #8. `ReminderDelivery` bridges the existing pure timeline, atomic local ledger, and single AppKit notch panel. The app starts it after test/smoke guards, without requesting notification permission or sending ordinary banners.

## Accepted panel presentation

Prayer-time and personal follow-up panels follow [DESIGN.md](../DESIGN.md). The shared headline shows prayer name and original prayer-start time; the follow-up subtitle describes elapsed time or snooze. Close is secondary, the explicit five-minute snooze is primary, and preview/personal-reminder disclosures remain visible. Both panels fit content and use the same camera wings, lower glass and rounded silhouette as today's schedule. This presentation change does not alter ledger identity, event timing or snooze semantics.

## Delivery contract

- Entry at the validated prayer instant; personal follow-up at the configured delay (`followUpDelayMinutes`, validated 1–60, default 10). Native preference controls are provided by #9. Started occurrences preserve their existing pending follow-up when the setting changes.
- Entry and follow-up/snooze use separately persisted display durations (`entryDisplaySeconds` / `followUpDisplaySeconds`), defaulting to 10/20 seconds. Native Settings sliders select 5–60 seconds in 5-second steps with automatic persistence; invalid stored values safely fall back to defaults. Each presentation, including previews, captures one continuous-clock deadline; later Settings changes apply only to subsequent presentations. Hover, panel keyboard input, and inside/outside clicks do not pause, renew, or dismiss the reminder. Explicit Close/Escape (when focused), snooze/navigation, lifecycle hiding, expiry, or a newer presentation may end it early. Outside clicks pass through without taking typing focus. Actual prayer name, selected-city time, and actual follow-up offset replace preview copy. Optional system sound is played only on real presentation when enabled; default off. Automatic presentation resigns keyboard focus.
- Entry close leaves the follow-up intact. Closing a follow-up/snooze retires that occurrence's chain. Only an explicit snooze action adds one request for five minutes later, strictly before the next prayer. Snooze failure at the next-prayer cutoff leaves an explanatory message in the panel.
- Real delivery saves handled IDs before presentation. On recovery, only the latest eligible stage within the inclusive five-minute grace is delivered; past skipped stages are retired too. A process crash between save and presentation may miss a reminder, rather than duplicate it.
- Pending follow-ups, explicit snoozes, handled IDs, and closed occurrence IDs live in `Application Support/Nida/reminder-ledger.json`, inside the sandbox. Writes are atomic. A corrupt file blocks automatic delivery rather than clearing history and replaying events. A write failure blocks that presentation and appears in Settings. After resolving a corrupt file, restart is required. History is retained across cities and clock corrections; this personal-use version has no automatic history deletion.
- City/month changes are observed on the shared store. A confirmed city change hides an old-city reminder and rebuilds the plan; old-city snoozes are discarded. Returning to a previously used city keeps its handling history.
- One cancellable task waits for the next future event, capped at sixty seconds to recheck the session and calendar. API refresh is on launch, wake, clock/time-zone change, and city-local date rollover, with repository cache/coalescing. It is not polled every minute. The shared validated preference model is observed alongside schedules; changing the delay reschedules future occurrences without relying on a separate raw UserDefaults conversion.

## Session and lifecycle limits

Workspace sleep/screens-off/inactive-session notifications suspend delivery and hide a real reminder; wake/screens-on/session-active notifications refresh coverage and reconcile. Clock and system-zone notifications replan absolute dates. Lock/unlock distributed notifications are also observed. No wake alarm, background daemon, or promise of delivery while the app is quit is added.

macOS provides no dedicated public lock-state query. Presentation additionally checks the current console-session dictionary and its `CGSSessionScreenIsLocked` flag. That flag and the distributed lock notification names are undocumented OS integration points; they must be verified on the owner's OS and may change. Missing session/console information blocks presentation. Sleep/lock/unlock behavior is not claimed proven by unit tests.

Preview buttons remain isolated: `show` clears the displayed real-event descriptor without creating or resetting delivery records. Preview snooze only displays its disclosure. Native preview smoke does not start the delivery engine or touch the real ledger.

## Verification

`make test`: 68 tests in ten suites, including ledger persistence/relaunch, two stages, close behavior, explicit one-shot snooze, next-prayer cutoff, latest-only recovery, availability gates, stale-event retirement, city changes, delay freeze, corrupt files/write failure, and existing pure boundary/collision/grace tests.

`make build` and `make smoke` verify compilation, geometry, non-key automatic presentation, preserved frontmost app, and the actual sandbox console-session gate. Hardware checks remain: observe both real stages, fixed-timeout multitasking/hover/keyboard behavior, close/snooze, sleep through several events, unlock, relaunch, source refresh, city changes while a panel is open, and clock corrections without replay storms. These are tracked in #8; simulated session dictionaries do not prove lock-screen behavior.

Runtime check on 2026-11-02 at 11:50 WIB: the normal sandboxed app created its atomic ledger and recorded the due Dzuhur follow-up. This establishes coordinator/ledger execution; it does not substitute for owner verification of the displayed reminder and actions.
