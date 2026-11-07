# Organic reminder sound sources

Research checked 2026-11-07. Scope: source and license verification only; no listening evaluation, app changes, accounts, purchases, or final asset selection. The descriptions below are uploader claims or file metadata; proposed fit is subjective and untested.

## Shortlist

| Candidate and creator | Verified evidence | Access and proposed fit |
| --- | --- | --- |
| [Kalimba Two-Notes — railkill](https://opengameart.org/content/kalimba-two-notes) | Source lists **CC0** and `kalimba.wav` (162.1 KB). Uploader describes two kalimba notes intended as a possible UI notification. Downloaded original inspected with `afinfo`: WAV, stereo, 44.1 kHz, 16-bit PCM, **0.917188 seconds**. | [Original WAV](https://opengameart.org/sites/default/files/kalimba.wav) downloaded anonymously. Best immediately obtainable candidate; audition for a restrained tonal reminder. Softness, brightness and resemblance to a generic notification remain unverified. |
| [knock-wood-soft.aiff — stereostereo](https://freesound.org/people/stereostereo/sounds/124539/) | Source lists **Creative Commons 0**, wooden-surface knocking, **2.450 seconds**, AIFF, stereo, 48 kHz, 24-bit, 689.5 KB. “Soft” is in the title, not an independently verified acoustic judgment. | Original download requires login; not obtained. [Public HQ MP3 preview](https://cdn.freesound.org/previews/124/124539_1783239-hq.mp3) downloaded anonymously. First wood candidate to audition: consider one isolated knock if the recording allows it. Could suggest a door knock or sound too abrupt. |
| [bamboo.wav — gmni](https://freesound.org/people/gmni/sounds/67046/) | Source lists **Creative Commons 0**, bamboo windchimes, **50.098 seconds**, WAV, stereo, 44.1 kHz, 16-bit, 8.4 MB. This is a long source recording, not a ready-made short alert. | Original download requires login; not obtained. [Public HQ MP3 preview](https://cdn.freesound.org/previews/67/67046_261599-hq.mp3) downloaded anonymously. Reserve candidate: audition for an isolated bamboo contact, then excerpt roughly 0.4–1.0 seconds if available. Wind, overlapping contacts or long tails may make it unsuitable. |

The preview links above were extracted from the corresponding Freesound page HTML and successfully fetched without authentication. They are lossy derivatives, not the AIFF/WAV originals. Their container durations include codec padding (approximately 2.496 and 50.129 seconds); use source-page durations for the originals. No claim is made that an appropriate excerpt has already been located.

## Redistribution evidence

All three individual upload pages associate their sound with CC0. Freesound explicitly states that copying, modification, distribution and commercial performance are permitted without asking the author. The [Creative Commons CC0 1.0 deed](https://creativecommons.org/publicdomain/zero/1.0/) confirms these permissions; the [legal code](https://creativecommons.org/publicdomain/zero/1.0/legalcode) is the governing text. This supports bundling an original or edited excerpt with Nida, including commercial distribution, without a copyright attribution requirement.

CC0 does not warrant uploader ownership, clear third-party rights, or imply creator endorsement. The pages establish the publishers' license declarations, not an independent chain-of-title audit. Retain creator, source URL, license URL, acquisition date, original checksum and edit notes with the chosen asset; a voluntary credit is useful provenance. Do not present the creators as endorsing Nida.

Access and permission are separate: CC0 does not remove Freesound's original-download login requirement. Under the no-account constraint, use the public previews to audition; if original-quality wood/bamboo acquisition remains mandatory, those candidates are blocked. A preview-derived edit would retain lossy-source limitations and should be documented as such. Kalimba is the only verified account-free original here.

## Recommendation and plan

1. Audition the wood preview and original kalimba side by side at comparable perceived levels. Prefer a single restrained wood contact if it avoids a door-knock association; otherwise consider the short kalimba. Bamboo is a fallback requiring more editing. These are proposed priorities, not listening results.
2. Choose one sound rather than adding another preset collection. Use neutral working names such as “Wood” or “Kalimba”; no singing-bowl, religious or spa framing.
3. Prepare only the chosen clip: preserve a natural decay, remove excess silence, add tiny edge fades if needed, and lower gain conservatively. Avoid aggressive normalization or effects that change its organic character. Keep the source and provenance record alongside the final asset.
4. Before bundling, listen on MacBook speakers and headphones at low and ordinary system volumes. Check audibility, startle, sharp transients, background noise, repeated-use fatigue and association with existing system alerts. Select an exact excerpt and gain only after this check.

Only this research note was added. Downloaded files were inspected in temporary storage, not added to the repository. No playback, waveform-based excerpt selection, hardware acceptance, implementation or GitHub updates were performed.

## Revised Nida recommendation and bundling plan

The owner rejected the macOS preset set after implementation. PR #38 is now draft. The earlier CC0 shortlist above remains source research; this section supersedes its generic wood-first recommendation with a Nida-specific proposal.

### Recommended listening order

1. **Bedug — primary identity candidate.** [Bedug, Beduk or Bedhug by redafs](https://freesound.org/people/redafs/sounds/348004/) credits artist Fahrul, July 2011, Fortis Record. The uploader describes a bedug recording, 16 seconds, stereo 44.1 kHz/16-bit WAV, licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). A [public HQ MP3 preview](https://cdn.freesound.org/previews/348/348004_6165769-hq.mp3) was downloaded; the lossless original requires Freesound login. Recommend a single restrained hit with a natural short decay, targeting roughly 1–2 seconds if the recording allows it. This is proposed sonic editing, not an audition result. Do not bundle the entire 16-second performance as an alert. Preserve uploader and performer credits, source, license, and modification notice in a bundled credits file and an accessible About acknowledgment. This recommendation reflects the app's Indonesian prayer-reminder purpose; it is not a claim that the sample defines a mosque's timetable.
2. **Bambu / Bamboo — lighter alternative.** Use gmni's CC0 source above only if a clean isolated contact can be selected; target roughly 0.6–1.2 seconds. It is bamboo windchime audio, not an authenticated kentongan recording. Label it accurately. Reject if wind/noise/overlapping contacts dominate.
3. **Petik / Pluck — tonal alternative.** Use railkill's original two-note kalimba, measured 0.917 seconds. Do not equate stock kalimba with a unique Nida sound; retain only if owner prefers it over the organic percussion options.

The stereostereo wood knock remains a reserve if bamboo cannot produce a suitable cue. It is not a fourth required preset. No candidate is acoustically accepted yet. The proposed default is Bedug only after owner audition; the sound-enabled toggle remains off by default.

### Concrete execution sequence

1. Provide the original/preview files and comparable audition clips before changing app resources. Obtain originals through an authorized download where available; no credentials are needed to audition the public previews. If original acquisition is blocked, use the account-free original candidate or explicitly document a preview-derived source rather than claiming lossless quality. Do not silently change the chosen sound.
2. Select exact excerpts and conservative gain by listening. Preserve attack/body/decay; remove leading/trailing silence and use short edge fades only to prevent clicks. Avoid heavy reverb, loops, vocals or a full adhan. Target final duration at most 2 seconds and combined final PCM payload under 1 MB; revise these targets only if audibility/decay demands it. No loudness or clipping pass is claimed yet.
3. Add only final PCM WAV files under Nida/Resources/Sounds, with explicit file references and Copy Bundle Resources membership in Nida.xcodeproj for both configurations. Keep source URLs, creators, source/final SHA-256, license copies and exact edit recipe in a small provenance record; ship CC BY credits/license with the app. Keep bulky source masters outside the runtime bundle.
4. Replace named system lookup with Bundle.main URL lookup plus NSSound(contentsOf:byReference:). Official [AppKit initializer documentation](https://developer.apple.com/documentation/appkit/nssound/init(contentsofurl:byreference:)) was checked via Context7. Reuse the current playback owner/protocol, audition action, single-active playback, stop behavior and visible failure state. No network access at playback and no fallback to system sounds.
5. Use stable asset IDs such as bedug/bamboo/pluck; translate display labels only. Preserve reminderSoundEnabled. Legacy Glass/Tink/Ping IDs from the unmerged Dev implementation and missing/invalid values resolve to the accepted bundled default; do not map names to unrelated sounds as if they were equivalent or change the user's enabled intent. Stable has not received PR #38 and still has its previous behavior.
6. Extend tests for every bundle URL/load without audio, resource presence in Debug and Release, valid-ID persistence and legacy/unknown fallback, selected routing, audition while off, stop/repeat and load/start failure. Retain scheduling/ledger/preview regressions. Check packaged credits and verify resources resolve offline.
7. Update DESIGN.md, sound/delivery docs, README, CHANGELOG and evidence around the final shipped assets. Run make test, make build, then Dev-only make smoke; build Release and inspect resource membership/metadata too. Existing 96-test results cover only the system-preset revision and cannot validate future bundled files.
8. Owner checks MacBook speakers/headphones, low/ordinary volume, repeated-use comfort, mute/output behavior, bilingual Settings/VoiceOver and actual reminder audio. Revise PR #38 around the final sound assets and plan before marking ready. No merge/promotion/release is part of this planning task.

### Completion gates

- Exact excerpts, names and default have been auditioned and selected; unaccepted candidates stay out of the app.
- Chosen source bytes and license/credit/edit provenance are recorded; final files load from both built bundles without system-library or network dependency.
- Existing persisted enabled intent, scheduling, event identity and ledger remain intact.
- Focused tests, builds and Dev smoke pass; pending hardware scenarios remain explicitly pending in #29/#1.

Research assets currently available locally: build/sound-research/bedug-redafs-preview.mp3, build/sound-research/bamboo-gmni-preview.mp3 and build/sound-research/kalimba-railkill.wav. They are audition material in ignored build output, not final bundled assets. No audio was played automatically and no app code changed in this revision.

## Implementation revision — 2026-11-08

Owner authorized bundled implementation. Working assets are now under Nida/Resources/Sounds with shipped SoundCredits.txt and CC BY/CC0 license texts. Bedug uses the 10.39–11.89 s interval, Bamboo 1.59–2.69 s, and Pluck its full approximately 0.917 s source. All are mono PCM WAV with 5 ms/80 ms fades and downward peak attenuation; exact gain, source/final checksums and ffmpeg version/recipe are in the shipped credits file. Bedug/Bamboo remain explicitly preview-derived. Selection used waveform onset/decay inspection, not a listening claim. Target-Mac audition and owner acceptance remain pending. Build/test/PR evidence is recorded separately in docs/mvp-verification.md and #29/#1.
