# Nida visual system

The owner's latest cropped frosted Liquid Glass reference is the visual authority: translucent neutral-gray surfaces, softly lit edges, circular icon controls, pill actions, off-white type, and calm spacing. It supersedes both the earlier sage mockup and the subsequently implemented dark charcoal default.

The owner's hardware screenshots also establish a geometry defect in that earlier version: the collapsed software pill widened the physical notch, and the expanded branding header looked like a separate attached window. Preserve the physical notch at rest and use one compact glass silhouette when expanded.

## Tokens

Source of truth in code: `Nida/NidaStyle.swift`.

| Role | Value / rule |
| --- | --- |
| Main surface | Native behind-window popover material plus neutral white tint and Liquid Glass; background-dependent |
| Header chrome | Same material, at most a subtle 4% white lift in the menu bar; no separate notch titlebar |
| Raised control/selected row | Neutral glass controls / 12% black selected-row tint |
| Main text | Off-white, approximately #F6F6F2 |
| Supporting text | Warm off-white, approximately #E6E6DE, to preserve contrast over the brighter material |
| Accent | Pale lime, approximately #C9DCAA; next-prayer dot only |
| Edge | Native Liquid Glass specular edge; no duplicate outer border |
| Main inset | Menu: 24 pt; notch: 20 pt vertical and 30 pt horizontal, including 10 pt shoulders |
| Group spacing | 12 pt; 4–8 pt within text groups |
| Section spacing | Menu: 20 pt; compact notch: 12 pt |
| Surface corners | Custom 10 pt concave shoulders joining the screen edge, 26 pt lower curves |
| Selected prayer row | Continuous 14 pt radius |
| Controls | Shared NidaButtonStyle: off-white primary, neutral native glass secondary, opaque fallback; 34 pt action height and 28 pt icon targets |
| Type | System SF, default design; regular body, medium/semibold titles |
| Prayer/time headline | Menu: 26 / 30 pt; notch: 21 / 26 pt, monospaced time digits |
| Body/supporting type | 12–13 pt / 11–12 pt |

Colors are approximated from the supplied image, not an official Apple token specification. Native compositor materials vary with desktop content and OS accessibility settings. Automated sRGB contrast checks cover the solid primary and opaque fallback palettes only; they do not certify transparent glass over arbitrary wallpaper.

## Surface rules

- The physical camera is already black: do not paint a full-width black cap over the expanded panel. Content starts below the camera exclusion area.
- Use native behind-window translucency plus Liquid Glass on the expanded notch surface. Do not place an 80%-opaque charcoal fill over the material. Use an opaque neutral-gray accessibility fallback.
- Keep branding/header chrome in the menu bar. The notch has only a small city/close row, followed by the next prayer and timetable; no separate titlebar or divider.
- Primary reminder action is off-white with dark text. Secondary actions are neutral glass. Avoid large green fills, glow, gradient text, or ornamental badges.
- Selected prayer uses a restrained neutral dark tint and a small lime status dot. Times remain off-white.
- Keep demo-data disclosure visible without uppercase letter-spaced labels competing with the reminder.
- Native Settings retains system form structure and accessibility behavior.

## Notch fit

- Collapsed state draws no background, border, black extension, or shadow. Its click region matches the measured camera width and extends only 8 pt below it. The 20 × 2 pt handle appears only on hover.
- On the current Mac the physical camera is 179 × 32 pt. Expanded schedule size is 360 × 358 pt, including camera clearance; the content height is tested using a real NSHostingView fitting measurement.
- Reminder and follow-up widths are 368 and 400 pt. Concave top shoulders flow into the screen edge; lower curves finish the glass silhouette.

## Motion and accessibility

Expand from the notch with a restrained, interruptible spring (baseline tuning: 0.26 seconds, 0.08 bounce). Keep native press/focus feedback. Reduce Motion uses a brief transition; Reduce Transparency and Increase Contrast use an opaque surface. Keyboard activity refreshes reminder dismissal; Escape still dismisses. Native button focus effects remain enabled. Reminder title/subtitle are grouped for VoiceOver, and icon controls include labels and help text.

## Validation boundary

The prototype builds and its geometry/state tests run on the development Mac. Actual glass, corner treatment, hover, button appearance, and motion still require owner review on hardware. App-view raster caches do not faithfully capture native compositor effects and are not accepted as visual approval.

## Polish implementation (#10)

NidaButtonStyle consolidates secondary/primary action and icon colors, press opacity without text scaling, native glass feedback, and opaque bordered controls under Reduce Transparency/Increase Contrast. The schedule keeps elapsed text readable without a second opacity reduction; selected rows get a border in Increase Contrast. Date/source/reminder disclosure text is at least 11 pt.

The outer notch silhouette, camera clearance, collapsed hit region, and shared schedule/store remain unchanged. No black camera cap, ornamental accent fill, stagger, or continuous animation is added. Native appearance fitting tests and contrast checks do not establish owner visual approval. Hardware finish checks remain in #11.
