# Prayer and reminder calculations

Issue: [#5](https://github.com/choiruladamm/nida/issues/5).

## Boundary rules

`PrayerTimeline` is an immutable, UI-independent value built from a confirmed location and validated monthly schedules. Its Gregorian calendar always uses the city's IANA time zone. Duplicate dates, another location's months, and invalid source data are rejected during construction.

- `snapshot(at:)` returns today's five absolute occurrences, the next occurrence, and remaining seconds. An occurrence is started when `startsAt <= now`; next prayer uses `startsAt > now`.
- At the exact prayer boundary, the current prayer's entry event is due and the next-prayer label advances to the following prayer.
- After Isha, next is tomorrow's Subuh only when that exact day's data exists. Missing today yields no snapshot; missing tomorrow yields no invented next time. Gaps are never skipped to a more distant cached day.
- Calendar-day arithmetic handles midnight, month/year rollover, and leap days. Device time-zone changes do not reinterpret the selected city's wall-clock times.
- The system-provided countdown uses the absolute next date. Settings updates its next-prayer summary at explicit prayer/midnight boundaries through SwiftUI TimelineView, rather than polling the API or a background loop. Past-only schedules use a direct unavailable snapshot instead of an exhausted timeline.

## Event identity and reconciliation

`PrayerOccurrence.ID` consists of city ID, city-local ISO date, and prayer kind. `PrayerEvent.ID` adds its stage: entry, follow-up, or snooze with the explicit request timestamp.

Entry/follow-up identity does not change when delay settings change. Each new explicit snooze request has a distinct identity so handling an earlier snooze does not suppress a later request. IDs/events are Codable for the later delivery layer; delivery persistence and timers are implemented separately in [reminder-delivery.md](reminder-delivery.md).

`events(at:delay:pending:handled:)` rebuilds the relevant yesterday/today/tomorrow window from available data:

- Default follow-up delay is 10 minutes, presets 5/10, custom values 1–60 minutes. Entry and follow-up dates are derived from the prayer instant, not display/dismissal duration.
- Future occurrences use the latest delay. Started occurrences preserve a valid existing pending follow-up. If no prior plan exists, the supplied delay initializes that occurrence.
- Supply handling history as well as pending events when rebuilding after a wall-clock correction. A historically handled occurrence remains started even if the clock moved backward.
- Revalidate preserved IDs/start times and follow-up offsets. Recompute expiry from current validated coverage; stale pending payloads cannot extend it.
- Preserve explicit pending snoozes independent of delay changes. Multiple snoozes for one occurrence keep only the most recent request.
- Cancel another city's pending events by rebuilding with the new city's timeline; foreign IDs cannot enter its plan.

The caller owns durable handling history and pending requests. Retain records outside this calculation window until the delivery layer's retention policy expires them; the returned array is not a replacement for an entire persistent ledger.

## Expiry, collision, and recovery

- Every stage expires at the next validated prayer's start. A follow-up or snooze at that exact instant is omitted, so the newer prayer takes precedence.
- For Isha without tomorrow's data, expiry is the next local midnight. This conservative fallback prevents carrying a reminder into an uncovered day. With tomorrow available, it expires at tomorrow's Subuh.
- `snooze(for:requestedAt:)` creates only an explicit five-minute request after the occurrence started and strictly before expiry. It never starts a repeating chain.
- `dueEvent(in:at:excluding:)` selects at most one event: the newest prayer occurrence, then latest eligible fire time; ties prefer explicit snooze, follow-up, then entry.
- Recovery grace is inclusive through five minutes after the event. Expired or older events are ignored. Handling a later stage suppresses earlier ones instead of replaying a missed stack; a newly requested later snooze remains eligible.
- The selector returns a value only. Showing the notch, marking delivery/dismissal, pausing on lock/sleep, rescheduling on lifecycle events, and durable state are implemented in #8; see [delivery contract](reminder-delivery.md).

## Current UI boundary

Settings now shows the real next prayer, its city-local wall time/zone, a native countdown, and a `besok` label where appropriate. Menu bar and notch now share this live timeline through ScheduleView (#7); only reminder previews retain fixtures. Native delay controls are implemented in #9, using the validated policy and shared preferences.

## Verification

`make test` covers before/at/after all five boundaries, WIB/WITA/WIT UTC instants, changed device default zones, midnight/month/year/leap-day transitions, missing coverage, explicit update boundaries, valid delay limits, fixed absolute dates, frozen follow-ups, snooze preservation/expiry, same-instant collisions, five-minute recovery, Codable identity, and clock-backward handling history. Existing provider/cache/notch tests also run. Native countdown interaction remains a manual check.
