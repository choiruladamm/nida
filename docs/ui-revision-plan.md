# UI revision history and skill provenance


## Notch motion follow-up — 2026-11-02

The retained Dynamic Island-inspired approach animates the shell independently from content fades. Expansion uses spring response 0.4/damping 0.82; collapse uses smooth 0.24 s. Content reveals over 0.18 s after 0.06 s and hides over 0.1 s. A local private `NotchMotion` helper centralizes timing and Reduce Motion behavior. Measured expanded heights are retained per panel state; first opening still relies on natural layout until measured. No shimmer or staged unfold remains.

`find-skills` searched animation options; installed SwiftUI Expert and Emil Design Engineering guidance were sufficient, so no additional skill or package was installed. References: [Apple Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities) and [NotchKit motion notes](https://github.com/duongductrong/NotchKit/blob/master/docs/motion.md). This is an adaptation for the Mac camera silhouette, not a reproduction of private iOS system animation. First/repeated opens, rapid reversal, changing content/language and accessibility toggles remain hardware checks.

## Compact menu experiment — 2026-11-02

The final local menu iteration retains next prayer as the hero, puts its countdown beside the caption, groups five icon-led rows, and consolidates refresh with Settings/Quit. Width is 340 pt; footer bottom inset is 16 pt after owner feedback. Menu highlights and notch dots now follow the macOS control accent. A proposed latest-prayer context line was tried and removed as redundant at the owner's request.

The same macOS Design Guidelines, SwiftUI Expert and Emil Design Engineering guidance informed these iterations. `grilling` (invoked through `grill-me`) supported the one-question-at-a-time content discussion; it introduced no retained extra content. No dependency was added. The owner reviewed successive running screenshots. Build/tests were deferred during experimentation, then rerun at the owner's final request: product commit `2323856` passed 89 tests in 14 suites and a Debug build. Smoke was not rerun; earlier smoke evidence applies to the preceding notch commit.

## Accepted three-panel notch revamp — 2026-11-02

Tracked in [#25](https://github.com/choiruladamm/nida/issues/25). The owner iterated on real running previews and supplied screenshots, then explicitly accepted the result after the final shoulder and horizontal-padding adjustments. The accepted scope is prayer time, personal follow-up and today's notch schedule. [DESIGN.md](../DESIGN.md) is the current visual specification; earlier contracts below describe prior iterations.

The final direction joins black camera wings to a naturally fitted body, uses more rounded shoulders/lower curves and adds a subtle native-glass gradient and lower edge. Reminders share a prayer-name/start-time headline; schedule uses a horizontal five-prayer strip. Hover replaces the schedule close button. Menu/Settings remain native frosted surfaces. No new dependency or design skill was installed for this revamp.

### Skills actually used

| Skill | Role in this revision | Source / installed reference |
| --- | --- | --- |
| `find-skills` | Search the skill directory and verify relevant existing skills | [vercel-labs/skills](https://skills.sh/vercel-labs/skills/find-skills) |
| `macos-design-guidelines` | Native controls, compact pointer targets, keyboard/focus and Settings conventions | [ehmo/platform-design-skills](https://skills.sh/ehmo/platform-design-skills/macos-design-guidelines) |
| `emil-design-eng` | Hierarchy, restrained motion, stable alignment and interaction polish; translated to native APIs | [emilkowalski/skills](https://skills.sh/emilkowalski/skills/emil-design-eng) |
| `swiftui-expert-skill` | SwiftUI composition, layout, observable state and accessibility | Installed `~/.agents/skills/swiftui-expert-skill/SKILL.md` |
| `write-swift` | Swift modeling, concurrency and separation of scheduling from presentation | Installed `~/.codex/skills/write-swift/SKILL.md` |
| `ponytail` | Small reversible edits and short owner-run experiment cycles | Installed `~/.agents/skills/ponytail/SKILL.md` |
| `writing-for-agents` | Consolidate the current design contract and keep historical evidence separate | Installed `~/.agents/skills/writing-for-agents/SKILL.md` |
| `pr` | Structure the final change description and verification evidence | Installed `~/.agents/skills/pr/SKILL.md` |

`swiftui-liquid-glass` was recorded during the earlier frosted revision below; it is historical provenance, not an additional skill newly invoked for this three-panel revamp. Context7 and Apple's documentation supplied API checks; they are documentation tools/sources rather than extra design skills.

### Documentation structure

DESIGN.md describes the visual language, semantic roles, component anatomy, spacing and interaction rules. Revision chronology, skill provenance and validation belong here and in the verification docs. This structure follows the separation of design decisions/components in [Google Labs' DESIGN.md workflow](https://github.com/google-labs-code/stitch-skills/blob/main/plugins/stitch-utilities/skills/design-md/README.md) and reusable semantic decisions in [Adobe Spectrum's design-token guidance](https://spectrum.adobe.com/foundations/design-data). These references informed documentation structure only; no Stitch workflow or skill was installed or run.

Owner acceptance establishes the appearance reviewed in this session. It does not establish fullscreen/display, VoiceOver, accessibility-toggle, real-reminder delivery or login acceptance. Final PR verification is recorded in [mvp-verification.md](mvp-verification.md).

## Earlier frosted revision

Owner feedback after PR #19: Settings is consistent but insufficiently glass-like; notch hierarchy, typography, spacing, and material need a substantive revision.

## Skills reviewed and installed

- `dimillian/skills/swiftui-liquid-glass`: native glass composition, modifier order, grouped controls. Observed 5.7K skills.sh installs; GitHub repository 4,021 stars.
- `ehmo/platform-design-skills` (`skills/macos`): Mac typography, Settings conventions, keyboard/accessibility. Observed 4.4K installs; repository 637 stars.

These are independent guidelines, not Apple-authored specifications. Verify native macOS APIs against current Apple documentation/installed SDK. Existing SwiftUI Expert, Write Swift, and Emil guidance remain applicable. Broad multi-window/document-app recommendations do not apply to this single-purpose menu bar utility.

## Historical frosted revision contract

- Keep the selected frosted neutral reference, system typography, restrained off-white controls, and lime next-prayer indicator.
- Replace stacked popover blur/gray fills with native AppKit NSGlassEffectView. The window must still sample the desktop; no CSS imitation or painted specular gradients.
- Preserve Settings controls and grouping, with unified native titlebar/traffic lights; expose native window translucency instead of placing glass behind an opaque Form background.
- Give the expanded schedule a 384 pt width and 360 pt content region plus measured camera clearance. Keep the collapsed physical-notch-sized hit region unchanged.
- Header: city/date, quiet close control. Main hierarchy: next-prayer caption, aligned prayer/time headline, then a clear countdown. Five rows share a stable name/time grid, 30 pt row height, and consistent spacing; attribution/actions sit below.
- Reminder: calm symbol, aligned title/supporting copy, consistent inset and action sizes. Reduce Motion/Transparency and Increase Contrast continue to work.
- Preserve data, next-prayer calculation, delivery ledger, location, preferences, and preview isolation.

## Execution and finish gate

1. Capture the incumbent native notch as a baseline.
2. Revise shared material/layout and native Settings background.
3. Build/test, then capture real compositor output for schedule, reminder, and Settings.
4. Inspect rendered typography, fit, control contrast, and glass; fix observed defects before updating PR #19.
5. Update DESIGN.md and issue #10 evidence. Distinguish captured visual review from still-unperformed fullscreen, VoiceOver, lock/login tests in #11.

## Native review findings and resolution

The initial capture confirmed a heavy popover underlay and a crowded schedule. A SwiftUI-only material adjustment still looked too solid. Replacing the background with AppKit NSGlassEffectView produced visible desktop sampling/frosting in actual compositor captures. The owner then requested unified Settings window controls; native hidden titlebar/unified toolbar plus safe-area glass resolved the separate black strip in the review host.

Menu feedback identified duplicate Settings access, an oversized preview region, and mismatched time-column alignment. The revised menu collapses preview controls, keeps one Settings entry, uses a one-line header, and aligns headline/list times. A subsequent capture exposed a next-prayer dot touching the time; it was moved into an explicit outside gutter.

Capture was temporarily blocked while the session was locked; it resumed only after unlock. Debug `--review-menu`, `--review-settings`, `--review-notch`, and `--review-follow-up` render production views without starting real delivery or changing preferences/login items. Screenshots stay local and are not committed.
