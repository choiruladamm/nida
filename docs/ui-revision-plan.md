# Glass and layout revision

Owner feedback after PR #19: Settings is consistent but insufficiently glass-like; notch hierarchy, typography, spacing, and material need a substantive revision.

## Skills reviewed and installed

- `dimillian/skills/swiftui-liquid-glass`: native glass composition, modifier order, grouped controls. Observed 5.7K skills.sh installs; GitHub repository 4,021 stars.
- `ehmo/platform-design-skills` (`skills/macos`): Mac typography, Settings conventions, keyboard/accessibility. Observed 4.4K installs; repository 637 stars.

These are independent guidelines, not Apple-authored specifications. Verify native macOS APIs against current Apple documentation/installed SDK. Existing SwiftUI Expert, Write Swift, and Emil guidance remain applicable. Broad multi-window/document-app recommendations do not apply to this single-purpose menu bar utility.

## Revision contract

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
