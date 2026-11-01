# Nida visual system

The owner's supplied reference image is the visual authority for the prototype: warm charcoal panels, translucent neutral chrome, large continuous corners, circular icon controls, pill actions, off-white type, and calm spacing. It supersedes the earlier sage-forward brainstorming mockup.

Use the dark panel in the reference for the default surface. Its frosted counterpart informs material and edge treatment; it is not a request for a second theme or a chat interface.

## Tokens

Source of truth in code: `Nida/NidaStyle.swift`.

| Role | Value / rule |
| --- | --- |
| Main surface | Warm charcoal, approximately #242521 |
| Header chrome | Approximately #34352F |
| Raised control/selected row | Approximately #474840 |
| Main text | Off-white, approximately #F6F6F2 |
| Supporting text | Warm gray, approximately #B5B6AE |
| Accent | Pale lime, approximately #C9DCAA; next-prayer dot only |
| Edge | White at 12% opacity, 0.5 pt; no strong outline |
| Main inset | 24 pt |
| Group spacing | 12 pt; 4–8 pt within text groups |
| Section spacing | 20 pt |
| Surface corners | Continuous 32 pt lower corners; 12 pt top shoulders at the notch |
| Selected prayer row | Continuous 14 pt radius |
| Controls | Native glass pills and circular icon controls; approximately 34 pt label height |
| Type | System SF, default design; regular body, medium/semibold titles |
| Prayer/time headline | 26 pt semibold / 30 pt light, monospaced time digits |
| Body/supporting type | 12–13 pt / 10–12 pt |

Colors are approximated from the supplied image, not an official Apple token specification. Native compositor materials vary with desktop content and OS accessibility settings.

## Surface rules

- Preserve opaque black around the physical camera. Content starts below the camera exclusion area.
- Keep the main reading area dark and stable. Use a native behind-window material for restrained translucency; reserve Liquid Glass for interactive controls.
- A slightly raised header, a hairline separator, and generous content padding establish hierarchy without extra cards.
- Primary reminder action is off-white with dark text. Secondary actions are neutral glass. Avoid large green fills, glow, gradient text, or ornamental badges.
- Selected prayer uses a neutral raised row and a small lime status dot. Times remain off-white.
- Keep demo-data disclosure visible without uppercase letter-spaced labels competing with the reminder.
- Native Settings retains system form structure and accessibility behavior.

## Motion and accessibility

Expand from the notch with a restrained, interruptible spring (initial tuning: 0.28 seconds, 0.12 bounce). Keep native press/focus feedback. Reduce Motion uses a brief transition; Reduce Transparency and Increase Contrast use an opaque surface. Keyboard and VoiceOver labels remain functional.

## Validation boundary

The prototype builds and its geometry/state tests run on the development Mac. Actual glass, corner treatment, hover, button appearance, and motion still require owner review on hardware. App-view raster caches do not faithfully capture native compositor effects and are not accepted as visual approval.
