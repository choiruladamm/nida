# Nida design system

Nida is a quiet, native macOS prayer reminder. The owner's latest frosted Liquid Glass reference defines the visual direction: translucent neutral gray, softly lit edges, off-white system type, circular icon controls, pill actions, and restrained spacing. This document describes the current implementation and guides future UI changes; earlier sage and opaque charcoal mockups are superseded.

## Source of truth

- `Nida/NidaStyle.swift`: colors, shared control dimensions, button appearance, and notch silhouette.
- `Nida/NotchView.swift`: desktop glass, reminder composition, and panel transitions.
- `Nida/ScheduleView.swift`: shared live schedule hierarchy, rows, status, and footer.
- `Nida/PrototypeModel.swift`: measured notch geometry and panel dimensions.
- `Nida/NidaApp.swift`: menu composition and native Settings scene.

Values below describe their actual use. Older general spacing constants in NidaStyle do not override the explicit schedule/reminder insets.

## Material and color

Use one shared `NidaGlassBackground`: native AppKit `NSGlassEffectView`, regular style, dark Aqua appearance, and 8% white tint. It samples the desktop; wallpaper and underlying windows affect the result. Keep the foreground readable without covering the glass with a heavy opaque fill or stacking a popover blur beneath it.

| Role | Current treatment |
| --- | --- |
| Main text | Off-white, approximately #F6F6F2 |
| Supporting text | Warm off-white, approximately #E6E6DE |
| Accent | Pale lime, approximately #C9DCAA; next-prayer dot |
| Selected row | 8% white fill; 14 pt rounded rectangle |
| Primary action | Solid off-white capsule with dark text |
| Secondary action | 10% white base plus native interactive regular glass |
| Hairline | 12% white; used for quiet separators and the reminder symbol outline |
| Accessibility surface | Opaque neutral gray, approximately #575952 |

The palette is derived from the supplied reference, not an official Apple token set. Legacy surface/chrome/raised colors are not the main glass background. The dark surface color remains the primary button's text color.

Window-backed menu and Settings use a rectangular glass background with zero glass corner radius. Native macOS window rounding owns the outer contour. Do not add another rounded clip, border, or glass rim: this previously produced visibly doubled corners.

The notch uses the custom silhouette: 10 pt concave top shoulders and 26 pt lower curves. Its glass corner radius is zero; the silhouette defines its outline. Only the expanded notch has the subtle black shadow (14% opacity, 16 pt radius, 8 pt vertical offset).

## Typography and spacing

Use the default system font and SF Symbols. Keep dates, attribution, disclosures, and statuses at least 11 pt. Prayer times and countdowns use monospaced digits; names and times align on stable columns.

| Element | Size / weight |
| --- | --- |
| City | 12 pt medium |
| Date / next-prayer caption | 11 pt regular / medium |
| Next prayer / headline time | 24 pt semibold / 28 pt regular, first-baseline aligned |
| Countdown | 12 pt regular; 10 pt clock symbol |
| Prayer rows | 13 pt regular; selected row semibold |
| Reminder title / subtitle | 18 pt semibold / 12 pt regular |
| Reminder actions | 12 pt medium |
| Status / source / preview disclosure | 11 pt regular |

Schedule insets are 24 pt horizontal and 12 pt vertical. Main groups use 12 pt spacing, the hero-to-list gap is 14 pt, and hero text uses 4 pt spacing. Each prayer row is 30 pt high with 2 pt between rows. The selection fill extends 10 pt into the side gutters; the 4 pt next-prayer dot sits outside the time column.

Reminder content uses 30 pt horizontal and 20 pt top inset, 16 pt between groups, and 12 pt between symbol/copy or actions. Its symbol is 20 pt inside a 36 pt circle. Shared icon targets are 28 × 28 pt; reminder actions are 34 pt high.

## Schedule and menu

Keep the hierarchy consistent in menu and notch:

1. City and local date, with one close or open-notch icon.
2. Quiet “Berikutnya” caption, prayer/time headline, then a separate countdown.
3. All five prayer rows in the same name/time grid.
4. Optional refresh status, followed by refresh/source actions.

Elapsed rows use the supporting text color without multiplying opacity again. Selected rows keep their time aligned with every other row. The notch footer includes Settings; the menu has Settings and Quit icon actions with tooltips in its compact bottom row. The row keeps the same 24 pt horizontal inset and uses 12 pt vertical padding. The “Coba pengingat” toggle shares the control row; when expanded, its two equal-width preview buttons sit side by side below it, spanning the full content width without a disclosure indent.

| Surface | Width | Content height |
| --- | --- | --- |
| Menu schedule region | 384 pt | Fits full content, plus status space |
| Notch schedule | 384 pt | 380 pt, plus camera clearance and status space |
| Prayer reminder | 368 pt | 112 pt, plus camera clearance |
| Follow-up reminder | 400 pt | 170 pt, plus camera clearance |
| Settings form | 520 pt | 660 pt; native window chrome is separate |

A refresh message adds `NidaStyle.scheduleStatusHeight` (52 pt) to both schedule surfaces. The notch silhouette and pointer region grow together. The message must not take space away from the five prayer rows or overlap the footer. The schedule has no scroll container; all five prayer rows remain visible. The menu follows its content height; use the horizontal gutters for selection decoration. The message wraps to at most three lines and exposes the full text through help.

While refreshing, replace the refresh symbol with a mini spinner inside the same 28 pt target and disable repeat clicks. Retain cached schedule rows on failure. Loading, missing city, missing schedule, and error copy must remain understandable without requiring a successful request.

## Notch behavior and Settings

Derive camera width, clearance, and placement from the selected display. The current development Mac measures 179 × 32 pt; these are observations, not hardcoded device dimensions. The schedule is therefore 384 × 412 pt normally and 384 × 464 pt with a status. The transparent hosting canvas is 520 × 480 pt.

At rest, draw no black extension, background, border, or shadow. The hit region matches the measured camera width and extends 8 pt below it; a 20 × 2 pt handle appears only on hover. On an unnotched display, the current fallback trigger is 164 × 8 pt. Expanded content starts below camera clearance, without a separate branding/titlebar strip.

Automatic reminders must not take keyboard focus. Explicit interaction can make the panel key; Escape and outside clicks dismiss it. Hover pauses reminder dismissal, and keyboard activity renews it. Entry and follow-up states dismiss after 7 and 18 seconds respectively; the schedule stays open until dismissed.

Settings uses the native grouped Form and real macOS window controls. Hidden titlebar backing, unified toolbar styling, and glass extending through the safe area form one continuous surface. Keep the Form background hidden so it does not mask the material. Preserve native control grouping and behavior.

Preview copy explicitly says “Preview · Data contoh”; real follow-ups explain that they are personal reminders, not a mosque's iqomah schedule. Preview actions stay isolated from real delivery state.

## Motion, controls, and accessibility

Settings begins with a native app-language picker offering self-named Bahasa Indonesia / English choices. Indonesian is the default; all SwiftUI scenes and AppKit hosting roots share the same observable preference. Language changes update copy without resetting views or reminder services. Both catalogs retain the existing type hierarchy and compact insets; five prayer rows stay visible without a scroll container. City names, source identity, zones and 24-hour prayer times remain provider/domain data. See [language selection](docs/language-selection.md) for OS-owned dialog limits and verification.

State changes use an interruptible spring with 0.26 second duration and 0.08 bounce. Reduce Motion disables that explicit state animation. Avoid decorative stagger, perpetual motion, text scaling on press, and extra glow.

`NidaButtonStyle` keeps text colors explicit even when the panel is not key. Pressed controls use 82% opacity; disabled controls use 45%. Keep native focus feedback and label/help text for icon-only actions.

Reduce Transparency or Increase Contrast replaces the desktop glass with the opaque neutral surface. Secondary buttons also use the opaque surface. Increase Contrast adds a selected-row outline and button borders, and keeps elapsed rows in the primary text color. Reminder title/subtitle are grouped for VoiceOver; the countdown has an accessible label and value.

## Skills and implementation guidance

- **SwiftUI Expert**: view composition, observable data flow, layout, native controls, accessibility, and performance.
- **Write Swift**: Swift modeling, concurrency, and separation of UI from scheduling/data behavior.
- **Emil Design Engineering**: restrained, interruptible motion, stable alignment, and interaction polish; translate principles to native APIs.
- **SwiftUI Liquid Glass** (`dimillian/skills`): material composition, modifier order, shape consistency, and grouped interactive controls. Its iOS examples require macOS-specific verification.
- **macOS Design Guidelines** (`ehmo/platform-design-skills`): native Settings, window controls, keyboard behavior, and Mac typography. Document-app or multi-window patterns are outside this utility's scope.

These skills guide decisions; they do not override the owner's reference or establish API correctness. Check changed platform APIs through Context7 and the installed Apple SDK. The project targets macOS 26 and later. See `docs/ui-revision-plan.md` for the revision history and skill provenance.

## Finish checks and evidence

For future UI changes, verify normal, loading, missing-data, and refresh-error layouts. Check all five rows, aligned time columns, stable controls, camera clearance, a single outer contour, and the shared menu/notch store. Run focused geometry/state tests and build checks when implementation changes; use native compositor captures to judge glass and fit.

Native captures have been inspected for the live notch, menu content, follow-up preview, Settings, and the notch's simulated refresh error with Isya fully visible. Menu/Settings captures use debug review hosts with production content; they do not prove every scene interaction. The menu error state has not been separately captured. Screenshots remain local because the translucent background can include desktop content.

Automated fit, geometry, and solid-palette contrast checks support those observations. They do not certify translucent contrast over arbitrary wallpaper or complete hardware acceptance. Fullscreen, VoiceOver, OS-wide accessibility toggles, display changes, and lifecycle/login checks remain tracked in issue #11.
