# Notch prototype verification

Issues: [setup #2](https://github.com/choiruladamm/nida/issues/2), [prototype #3](https://github.com/choiruladamm/nida/issues/3).

## Current accepted presentation — 2026-11-02

The owner accepted the three-panel revamp in [#25](https://github.com/choiruladamm/nida/issues/25). [DESIGN.md](../DESIGN.md) owns the current visual specification. Prayer time, personal follow-up and today's schedule share measured camera wings, more rounded shoulders/lower curves, a black upper surface, subtle lower glass and a fitted body. The schedule uses five horizontal cells and no close icon; a delayed hover opens/closes it, while clicking keeps it open until Escape/outside dismissal. Rendered content height also controls pointer pass-through. Keep the physical collapsed trigger unchanged.

Dimensions and captures below describe earlier prototype revisions, not current fixed heights. Current owner visual acceptance covers the reviewed running previews; fullscreen, display topology/scaling, accessibility, real delivery and lifecycle acceptance remain pending in [mvp-verification.md](mvp-verification.md).

## Historical prototype record

## Implemented

- SwiftUI menu bar panel, native Settings scene, and AppKit nonactivating panel hosting SwiftUI.
- Four in-memory states: collapsed handle, prayer-time preview, follow-up preview, and sample timetable.
- Camera space derived from NSScreen safe-area/auxiliary geometry; all content is below the camera.
- A hover-only collapsed handle that does not enlarge the physical notch; expanded frosted Liquid Glass with concave screen-edge shoulders and a compact timetable. Shared reference-derived tokens are documented in DESIGN.md.
- Automatic previews do not become key windows. User-initiated schedule access or clicking the panel enables keyboard interaction. Escape collapses the key panel.
- Pointer events outside the current panel bounds pass through the otherwise transparent host window; outside clicks collapse it. No global keyboard monitor or accessibility permission is used.
- Fullscreen auxiliary/all-Spaces window behavior is configured with public APIs. Geometry is recalculated on screen, Space, and wake changes.
- Reduce Motion uses a short transition; Reduce Transparency or increased contrast uses an opaque surface.
- Preview-only snooze explicitly confirms that no reminder was scheduled.

## Observed on the development Mac

- MacBook Air M4, built-in Liquid Retina display.
- macOS 27.0.1, Xcode 27.0, Swift 6.4; deployment target macOS 26.0.
- The native smoke check detected a 1470 × 956 point screen and a 179 × 32 point camera exclusion area.
- Panel visible: true. The frontmost application stayed unchanged during automatic appearance; panel key status: false.
- Debug build and eight Swift Testing test functions passed (including four parameterized panel states).
- Tests cover anchoring with nonzero/negative screen origins, containment, camera-width collapsed hit area, concave shoulder path, compact native content fitting below the camera, an unnotched display, preview snooze state, timeout policy, and key-window eligibility.
- Screen Recording permission was not granted. No permission was requested. App-view raster caching was unsuitable for checking compositor-rendered glass and is not used as visual evidence.

These observations establish startup, geometry and window-focus behavior, not the full interactive acceptance matrix.

## Manual checks still required

| Scenario | Status | What to check |
| --- | --- | --- |
| Camera handle and menu bar entry | Pending owner review | Both open the same sample schedule; no camera-obscured text |
| Mouse and keyboard | Pending | Buttons, Escape, outside click, no blocked clicks outside the surface |
| Motion | Pending | Rapid open/close reverses smoothly; text stays crisp; spring feels restrained |
| Background material | Pending | Frosted Liquid Glass material is legible over real light/dark desktop content |
| Fullscreen apps and Spaces | Pending | Panel visibility, screen selection, menu bar auto-hide, no disruptive focus changes |
| External displays and clamshell | Pending | Only one panel, safe fallback placement after topology changes |
| Accessibility | Pending | VoiceOver labels, Tab focus, Reduce Motion/Transparency, Increase Contrast |
| Multiple display scales | Pending | Correct positioning after scaling changes |

Keep #3 open until its remaining hardware checks are recorded. After PR #12 merged, the owner authorized the live data foundation in #4; its implementation does not claim those visual checks are complete. Window-level/collection settings do not guarantee visibility over every system-managed fullscreen surface. No lock-screen overlay is promised.

## Deliberate prototype limits

- Data, highlighted prayer, date and follow-up interval are fixtures. No network, location access, reminders, sound, or login registration.
- Hovering restarts a full preview timeout on exit. Production remaining-time and lifecycle semantics belong to #8.
- Native materials can differ from the generated brainstorming mockup; actual desktop rendering must be reviewed on hardware.

## Owner-reported geometry correction

The owner supplied real screenshots of the widened collapsed pill and oversized dark schedule. The fix removes all collapsed background/cap/shadow drawing, removes the full-width black camera cap and separate notch titlebar, reduces the schedule from 400 × 446 pt to 360 × 358 pt on the measured display, and uses native Liquid Glass matching the owner's latest frosted reference. The compact content fit is covered by a native NSHostingView fitting-size regression test. Actual visual acceptance remains an owner hardware check.

## Polish follow-up (#10)

Shared action/icon styling now preserves explicit text contrast in non-key panels, uses opaque high-contrast/transparency fallbacks, and keeps 28 pt icon targets. Supporting text is at least 11 pt; elapsed schedule rows no longer have a second opacity reduction. The spring baseline is 0.26 seconds / 0.08 bounce; Reduce Motion removes panel size animation. Keyboard activity resets the existing dismissal interval. The physical notch shape and collapsed hit area are unchanged. These implementation changes do not close pending visual/input/display hardware checks; they are consolidated in #11.

## Subsequent material/layout revision

Owner feedback expanded the schedule to 384 × 392 pt on the 179 × 32 pt camera display (360 pt content). The collapsed region is unchanged. NSGlassEffectView now supplies the desktop glass directly; Settings extends the same material through a unified native titlebar. Current layout/material evidence is in `docs/ui-revision-plan.md`; earlier dimensions above are historical prototype measurements.
