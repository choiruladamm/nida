# Notch prototype verification

Issues: [setup #2](https://github.com/choiruladamm/nida/issues/2), [prototype #3](https://github.com/choiruladamm/nida/issues/3).

## Implemented

- SwiftUI menu bar panel, native Settings scene, and AppKit nonactivating panel hosting SwiftUI.
- Four in-memory states: collapsed handle, prayer-time preview, follow-up preview, and sample timetable.
- Camera space derived from NSScreen safe-area/auxiliary geometry; all content is below the camera.
- A black camera surround, warm charcoal reading surface, behind-window HUD material, native glass controls, and restrained spring animation. Shared reference-derived tokens are documented in DESIGN.md.
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
- Debug build and six Swift Testing test functions passed (including four parameterized panel states).
- Tests cover anchoring with nonzero/negative screen origins, containment, camera-adjacent trigger area, an unnotched display, preview snooze state, timeout policy, and key-window eligibility.
- Screen Recording permission was not granted. No permission was requested. App-view raster caching was unsuitable for checking compositor-rendered glass and is not used as visual evidence.

These observations establish startup, geometry and window-focus behavior, not the full interactive acceptance matrix.

## Manual checks still required

| Scenario | Status | What to check |
| --- | --- | --- |
| Camera handle and menu bar entry | Pending owner review | Both open the same sample schedule; no camera-obscured text |
| Mouse and keyboard | Pending | Buttons, Escape, outside click, no blocked clicks outside the surface |
| Motion | Pending | Rapid open/close reverses smoothly; text stays crisp; spring feels restrained |
| Background material | Pending | Glass/HUD material is legible over real light/dark desktop content |
| Fullscreen apps and Spaces | Pending | Panel visibility, screen selection, menu bar auto-hide, no disruptive focus changes |
| External displays and clamshell | Pending | Only one panel, safe fallback placement after topology changes |
| Accessibility | Pending | VoiceOver labels, Tab focus, Reduce Motion/Transparency, Increase Contrast |
| Multiple display scales | Pending | Correct positioning after scaling changes |

Do not close #3 or expand into live schedule integration until the notch feasibility gate is reviewed. Window-level/collection settings do not guarantee visibility over every system-managed fullscreen surface. No lock-screen overlay is promised.

## Deliberate prototype limits

- Data, highlighted prayer, date and follow-up interval are fixtures. No network, location access, reminders, sound, or login registration.
- Hovering restarts a full preview timeout on exit. Production remaining-time and lifecycle semantics belong to #8.
- Native materials can differ from the generated brainstorming mockup; actual desktop rendering must be reviewed on hardware.
