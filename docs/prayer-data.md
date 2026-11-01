# Prayer data foundation

Issue: [#4](https://github.com/choiruladamm/nida/issues/4). Verified on 2026-11-01.

## Current feature boundary

Settings provides searchable manual city selection, today's five real prayer times, source attribution, selected-city time zone, refresh, and stored coverage. The menu bar/notch reminder previews remain explicitly labeled demo data. Next-prayer calculation, automated reminders, and automatic location detection belong to subsequent issues.

No city is assumed from the laptop's location or from the Jakarta preview fixture. The user selects a supported city. Only the confirmed city/province/zone is persisted; no GPS coordinates or account are used.

## Verified provider contract

Primary documentation: https://api.myquran.com/doc

Machine-readable OpenAPI: https://api.myquran.com/doc/apimuslim (observed version v3.1.3).

| Request | Observed contract |
| --- | --- |
| `GET /v3/sholat/kabkota/semua` | Boolean `status`, city array in `data`; each has an opaque 32-character ID and `lokasi`. Observed 517 cities. |
| `GET /v3/sholat/jadwal/{id}/{YYYY-MM}` | Boolean `status`; `data.id`, `kabko`, `prov`, and `jadwal` dictionary keyed by ISO calendar date. |
| Day values | Five required `HH:mm` strings: `subuh`, `dzuhur`, `ashar`, `maghrib`, `isya`. Additional provider fields are ignored. |
| Source metadata | `/v3/sholat` identifies Bimas Islam Kemenag as the source. Display **Kemenag via myQuran**. |

The provider's prayer documentation explicitly permits using the data. No API key was required in observed requests. No SLA or guarantee of agreement with a particular mosque is assumed. Check the live provider terms before public distribution.

The provider's repository documents 100 requests/minute overall and 5 monthly requests/minute per IP. An observed monthly response advertised `RateLimit-Limit: 15`, so deployment configuration differs from that README. Nida does not depend on that higher number: it normally fetches only two months, reuses daily cache, coalesces simultaneous requests, avoids per-keystroke API calls, and observes HTTP 429 `Retry-After` with a monthly-request cooldown. There are no automatic retry loops.

Provider implementation/rate-limit reference: https://github.com/banghasan/apiMuslim3#rate-limiting

## City time zones

The city catalog and monthly response do not provide an IANA time-zone field. The verified monthly `prov` field is mapped explicitly to WIB (`Asia/Jakarta`), WITA (`Asia/Makassar`), or WIT (`Asia/Jayapura`), including the newer Papua provinces. Unknown provinces are rejected rather than using the laptop's time zone.

For a new city, a Jakarta-zone month is requested to obtain province metadata. The app then resolves the city's actual current and next month; around the WIB/WIT month boundary this can require one additional month request. On relaunch the saved validated province/zone removes that bootstrap request. Only the city's actual current/next month are exposed as active coverage.

## Validation and persistence

- Validate HTTP and API success, city ID/name, known province and time-zone mapping, the requested year/month, every date in the complete Gregorian month, five strict `HH:mm` values, and increasing prayer-time order.
- The same checks run when reading cached schedules, including provider identity and cached time-zone/province consistency.
- Store source, city, province/zone, date-keyed times, and retrieval date in local Codable JSON, separated by provider/city/month under sandboxed Application Support: `Nida/PrayerSchedules/myquran-v3/`.
- Write atomically. A failed/malformed refresh leaves the previous valid file intact. A write failure can expose freshly validated in-memory data with an explicit offline-storage warning.
- Reuse today's validated cache; an older fetch is refreshed when Settings opens. Refresh is explicit otherwise. Cache coverage is by exact date, never yesterday's fallback.
- Cache the city catalog for 24 hours, with stale catalog fallback if the network fails. Catalog persistence is best effort; month write failures are surfaced to the user.
- Persist the selected location only after its provider response validates. A request identity prevents a late response from a previously selected city from replacing the latest selection.
- A missing next-month response does not erase the available current month. A missing current date is shown as unavailable.

## Official comparison

Comparison source: https://bimasislam.kemenag.go.id/jadwal-sholat

The page's public `/api/sihat` proxy was used to select province/city and retrieve the same November 2026 month. Its opaque selectors are obtained from the page's province/city endpoints; they are not application API dependencies.

Values below are ordered Subuh / Dzuhur / Ashar / Maghrib / Isya. **All 45 compared values matched exactly** between the myQuran response and the official timetable:

| City | Date | Both sources |
| --- | --- | --- |
| Kota Jakarta (WIB) | 2026-11-01 | 04:09 / 11:40 / 14:55 / 17:49 / 19:00 |
| Kota Jakarta (WIB) | 2026-11-15 | 04:06 / 11:41 / 15:01 / 17:52 / 19:05 |
| Kota Jakarta (WIB) | 2026-11-30 | 04:06 / 11:45 / 15:09 / 17:58 / 19:13 |
| Kota Denpasar (WITA) | 2026-11-01 | 04:32 / 12:06 / 15:19 / 18:18 / 19:30 |
| Kota Denpasar (WITA) | 2026-11-15 | 04:28 / 12:07 / 15:27 / 18:22 / 19:36 |
| Kota Denpasar (WITA) | 2026-11-30 | 04:28 / 12:11 / 15:35 / 18:28 / 19:44 |
| Kota Jayapura (WIT) | 2026-11-01 | 03:58 / 11:24 / 14:42 / 17:30 / 18:41 |
| Kota Jayapura (WIT) | 2026-11-15 | 03:56 / 11:25 / 14:47 / 17:32 / 18:44 |
| Kota Jayapura (WIT) | 2026-11-30 | 03:57 / 11:29 / 14:54 / 17:37 / 18:50 |

These are sample comparisons, not validation of all cities/dates. Jakarta is a comparison sample, not a confirmed user location. A mosque's iqomah remains outside this data source.

## Verification

- `make test`: deterministic provider, calendar/time-zone, cache, selection-race, and existing notch tests; no internet required.
- `make data-smoke`: an opt-in live check through the signed sandboxed app. Fetches the catalog and current/next Jakarta months into a temporary directory, validates and saves them, restores them through an offline transport, then removes that directory. Does not change the selected city or persistent user cache.
- Observed native live check: 517 cities, 61 validated days for November/December 2026, both months restored with offline transport.
- Outgoing-network entitlement is explicitly declared; no location, incoming-network, or screen-capture permission was added.

Tests cover malformed/failed payloads, wrong city/date/name, invalid/missing/reversed/equal times, unknown provinces, month/year/leap-day boundaries, offline fallback, missing coverage, corrupt cache/recovery, write failure, concurrent request coalescing, rate-limit cooldown, restored selection, and late selection responses. Native Settings interaction still needs manual user verification.
