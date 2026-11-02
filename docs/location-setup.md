# Location setup

Issue: [#6](https://github.com/choiruladamm/nida/issues/6).

## User flow

First launch opens a small native setup window when there is no valid saved city. The user can use the current location or search the cached provider catalog manually. Closing setup leaves the menu bar app available; setup is offered again on relaunch until a city is successfully selected. Settings exposes both choices at any time.

Automatic detection first loads the provider catalog, then requests location authorization in response to the button. A single Core Location `requestLocation()` result is reverse geocoded through `MKReverseGeocodingRequest` (macOS 26+). Confirmation displays **Lokasi terdeteksi** using Apple’s original administrative name and **Jadwal yang digunakan** using the matched provider city. For example, `Kota Administrasi Jakarta Selatan` maps to `Kota Jakarta`. Detected names remain only in the current confirmation state and are not persisted. The detected city is only a candidate: the existing schedule remains active until **Gunakan kota ini** is selected and the provider month validates. Manual selection uses the same validated selection path.

Both the selected location and completion flag are saved after validation. Existing valid saved cities migrate without showing setup again. A flag without a valid city does not suppress setup. A failed replacement preserves the previous confirmed location and schedules.

## Matching and privacy

- Require Apple's structured region identifier `ID`; use `addressRepresentations.cityName`, never parse a formatted street address or use deprecated placemark APIs.
- Compare against validated provider catalog entries. Normalize case, accents, spacing, punctuation, and `Kab.` / `Kabupaten`. Explicitly map Apple’s five `Kota Administrasi Jakarta` names (Pusat, Selatan, Utara, Barat, Timur) to the provider’s `KOTA JAKARTA` catalog entry. Respect explicit city/regency type; an untyped name can match only one catalog ID.
- Missing, conflicting, ambiguous, foreign, and unsupported names recover through manual search. There is no fuzzy matching or nearest-city assumption. Other unrecognized Indonesian administrative names still require manual selection. Kepulauan Seribu remains its own provider regency and is never folded into Kota Jakarta.
- Requested accuracy is one kilometer; reject fixes older than two minutes, negative accuracy, or uncertainty greater than ten kilometers. City confirmation is still necessary, especially near administrative boundaries.
- Stop and release the lookup after completion, cancellation, failure, or a 30-second deadline. Cancellation also covers catalog loading; a late response cannot trigger a permission request or replace a newer candidate.
- The app keeps coordinates only in memory while resolving the city. No coordinate persistence, application logging, continuous updates, analytics, or background location tracking. Apple's geocoder processes the requested location; the provider receives only its city ID.
- Declare `com.apple.security.personal-information.location`, `NSLocationUsageDescription` (macOS), and `NSLocationWhenInUseUsageDescription`. Do not request always/background access.

Permission denial/restriction explains how to enable location in System Settings and keeps manual selection available. Missing services, weak/stale fixes, geocoding/network failures, and deadline expiration offer retry and manual recovery.

## Integration boundary

A generation guard prevents obsolete provider fetches from replacing a newer confirmed selection. A manual selection cancels pending detection, and merely receiving a detected candidate never changes `PrayerDataStore.location` or persists it.

Issue #8 observes confirmed city changes, hides an old-city reminder, and rebuilds pending events with the new city timeline, dropping old-city snoozes. Hardware interaction still requires verification. The pure timeline already rejects other-city months and event identities. Menu/notch schedules share the live store in #7; reminder previews remain labeled demo.

## Verification

`make build` and `make smoke` pass; the panel still preserves frontmost focus with a measured 179 × 32 pt camera. `make test` passes 56 tests in 9 suites and covers catalog matching, city/regency ambiguity, foreign/missing/conflicting data, no lookup before explicit start, denial/failure recovery, cancellation during catalog or geocoder work, confirmation before persistence, failed selection, migration/relaunch, and stale city-response protection. Tests inject location results and never request real location permission.

A native MapKit sample lookup at public Denpasar coordinates returned `cityName = Kota Denpasar`, `region.identifier = ID`. This checks the new address fields against the live geocoder; it does not validate device positioning or the sandbox permission flow.

The signed app's generated Info.plist and location entitlement are inspected separately. Native permission prompts, actual user-city matching, setup/sheet dismissal, VoiceOver, and visual layout still need owner verification. An ad-hoc local build is not a notarized distribution build; OS permission behavior must be checked with the installed build.

Documentation checked through Context7 and the installed Xcode 27 SDK:

- [Requesting location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services)
- [MKReverseGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest)
- [Address representations](https://developer.apple.com/documentation/mapkit/mkaddressrepresentations)

## Jakarta matching regression

The owner encountered an unsupported-region message in Jakarta. A live native MapKit reproduction at public Jakarta landmarks returned `Kota Administrasi Jakarta Pusat` and `Kota Administrasi Jakarta Selatan`, country `ID`. The live provider catalog instead exposes `KOTA JAKARTA` (`58a2fc6ed39fd083f55d4182bf88826d`) and a separate `KAB. KEPULAUAN SERIBU` (`cfecdb276f634854f3ef915e2e980c31`). The original exact matcher rejected the administrative-city names.

Five explicit aliases now resolve through the validated catalog, still requiring user confirmation. Regression coverage failed for all five names before the fix and passes afterward; separate tests preserve Kepulauan Seribu, reject unknown suffixes, and enforce the Indonesian country gate. No device coordinates were collected for this investigation.
