# Nida design system

## Visual direction

Nida is a quiet macOS prayer reminder. The notch feels like an extension of the camera: black at the screen edge, softly rounded below, with a restrained hint of glass at its lower boundary. The menu and Settings use frosted neutral glass and native macOS controls. Off-white system typography carries the hierarchy; the native macOS accent identifies the next prayer.

This document defines the current design, not the revision history. The owner accepted the three-panel notch revamp on 2026-11-02. See [revision decisions and skill provenance](docs/ui-revision-plan.md) and [verification status](docs/mvp-verification.md) for history and evidence.

## Color and material

| Role | Treatment | Purpose |
| --- | --- | --- |
| Notch upper surface | Solid black | Visually joins the physical camera |
| Notch lower surface | Native dark glass beneath a black overlay fading from 100% to 88% opacity over the lower half | Separates the panel from underlying apps without turning the whole panel gray |
| Lower edge | 0.75 pt white stroke, fading in from 40% of panel height to 18% opacity at the bottom | Defines one quiet outer contour |
| Primary text | Warm off-white, approximately #F6F6F2 | Headlines, prayer times and active labels |
| Supporting text | Warm off-white, approximately #E6E6DE | Metadata, countdowns, source and disclosures |
| Next-prayer accent | Native macOS control accent | Notch selection dot; menu selected icon and 13% accent fill |
| Selected prayer | 8% white fill | Quiet emphasis within the schedule |
| Primary reminder action | Solid off-white capsule, dark text | Makes the explicit five-minute snooze easy to find |
| Secondary notch action | 10% white capsule | Supports dismissal and utility controls |
| Settings accent | Native system accent | Follows the user's macOS accent-color choice |

Menu and Settings share native `NSGlassEffectView`, regular style, dark Aqua appearance and 8% white tint. Let macOS own window rounding; the glass backing has zero corner radius. The notch uses its custom silhouette as the only outer clip. Its expanded shadow is black at 14%, radius 16 pt, offset 8 pt downward.

## Shape and spacing

All dimensions are macOS points. These rules apply to prayer time, follow-up and today's schedule.

| Element | Value |
| --- | --- |
| Concave upper shoulders | 18 pt |
| Convex lower curves | 36 pt |
| Horizontal content inset | 38 pt, shared by header and body |
| Effective side gutter | 20 pt after the 18 pt silhouette inset |
| Body gap after camera header | 12 pt |
| Bottom content inset | 20 pt |
| Main group gap | 12 pt |
| Schedule hero-to-strip gap | 14 pt |
| Header symbol and icon targets | 16 pt symbol; 28 × 28 pt target |
| Follow-up actions | 30 pt high; 12 pt gap |
| Schedule cells | 62 pt high; 6 pt gap; 12 pt selected corner radius |

Widths are 368 pt for prayer time, 400 pt for follow-up, and 384 pt for the schedule. Height follows the rendered content, including wrapped disclosures and errors; avoid a fixed-height body or trailing flexible spacer. The pointer region follows the same measured height. The transparent hosting canvas is 520 × 480 pt.

Reserve the selected screen's actual camera lane between equal-width header wings. The header is at least 36 pt high and never shorter than camera clearance. If either wing cannot fit a 28 pt control after horizontal insets, put the header below the camera. Collapsed presentation keeps the physical camera width and an 8 pt trigger below it, without drawing an extension, border or shadow.

## Typography and iconography

Use the system font and SF Symbols. Names use proportional type; prayer times and countdowns use monospaced digits. Align headline names and times on their first baseline. Keep metadata and disclosures at least 11 pt.

| Role | Size / weight |
| --- | --- |
| Notch prayer name | 26 pt semibold |
| Notch headline time | 32 pt regular |
| City, state caption and date | 11 pt medium |
| Supporting message and countdown | 12 pt regular |
| Schedule cell name | 11 pt regular; selected semibold |
| Schedule cell time | 14 pt medium; selected semibold |
| Reminder action | 12 pt medium |
| Source, error and preview disclosure | 11 pt regular |

A moon identifies reminders; a calendar identifies the schedule. Symbols in the camera wings sit directly on the black surface. Avoid decorative icon circles or a separate branding bar.

## Notch compositions

### Prayer time

Moon in the left wing; a calendar button in the right wing opens the live schedule. Below: quiet stage caption, prayer name on the left and prayer-start time on the right, then a short pause message. A visible sample-data disclosure distinguishes previews from real delivery.

### Follow-up

Use the same header and name/time hierarchy. The large time remains the original prayer-start time. Supporting copy explains elapsed minutes or identifies a snooze; it does not imply a mosque iqomah time. A compact secondary Close capsule precedes a wider primary five-minute snooze capsule with a clock symbol. Keep the preview or personal-reminder disclosure visible below the actions.

### Today's schedule

Calendar in the left wing; city-local date in the right wing. No X button. Below: city name, next-prayer caption, prayer/time headline and countdown. All five prayers form one horizontal strip with equal-width cells. The selected cell has a subtle rounded fill and a system-accent dot below its time. Elapsed cells use supporting text without another opacity reduction.

The footer puts source/time zone on the left and refresh/Settings controls on the right. Refresh becomes a mini spinner and disables repeat clicks while loading. A bounded, wrapping error appears above the footer while valid cached content stays visible. Missing-city, loading and missing-schedule states remain actionable. The notch schedule has no internal scroll container.

## Interaction and motion

Hovering over the collapsed notch for 180 ms opens the schedule without taking keyboard focus. A schedule opened by hover closes 250 ms after pointer exit. Clicking inside keeps it open and enables keyboard interaction; Escape or an outside click dismisses it. Menu-initiated schedules also stay open until dismissed. Opening Settings closes the originating menu/notch surface first.

Automatic prayer reminders do not take typing focus. Prayer time dismisses after seven seconds, follow-up after eighteen; hover pauses dismissal and keyboard activity renews it. Preview actions remain isolated from the delivery ledger.

Transitions use an interruptible 0.26 second spring with 0.08 bounce. Reduce Motion removes the explicit state animation. Keep text stable and avoid decorative stagger, perpetual motion or press scaling. Shared capsule controls use 82% opacity when pressed and 45% when disabled.

## Menu and Settings

The menu is 340 pt wide with 16 pt horizontal insets. Its open hero keeps the next-prayer caption and countdown on one line above a 22/30 pt prayer/time headline. Five 29 pt rows sit in a rounded 20 pt group with 4 pt internal padding, prayer-specific SF Symbols and a system-accent selected row. Attribution sits below the group. The inset footer combines preview disclosure with refresh, Settings and Quit; expanded preview actions follow beneath. Footer padding is 6 pt above and 16 pt below. Schedule content uses 10 pt top and 6 pt bottom padding, with 8–10 pt group gaps. Do not apply the notch's camera inset or horizontal strip to this surface. Avoid redundant last-prayer context beneath the hero.

Settings uses a native grouped Form, native window controls and default Form spacing. Controls follow the system accent. Titlebar backing is transparent at the top of the scroll; a 25% black backing appears after scrolling down. The city picker shares the glass backing, with a rounded search field, inset list and capsule glass actions.

Display location names separately from provider schedule identity: use concise labels such as Jakarta Selatan in UI while requests/cache retain the provider's Kota Jakarta ID. See [location behavior](docs/location-setup.md) for matching and persistence.

## Accessibility and content

Reduce Transparency or Increase Contrast gives the notch a solid black surface. Increase Contrast raises its lower-edge opacity to 50%, outlines selected cells/buttons and keeps elapsed prayer text in the primary color. Menu/Settings glass falls back to an opaque neutral surface; secondary capsules also retain an opaque fallback.

Keep native keyboard focus, labels and help for icon actions. Group reminder caption/name/time/message for VoiceOver; expose countdown label/value and selected/elapsed schedule state. Product copy follows Indonesian or English; city names and 24-hour times remain domain data. Keep preview disclosures explicit and explain real personal follow-ups separately from mosque schedules.

## Implementation references

- [NidaStyle.swift](Nida/NidaStyle.swift): shared palette, insets, controls and silhouette.
- [NotchView.swift](Nida/NotchView.swift): surface, camera wings and reminder compositions.
- [ScheduleView.swift](Nida/ScheduleView.swift): live schedule hierarchy and per-surface layouts.
- [PrototypeModel.swift](Nida/PrototypeModel.swift) and [NotchPanelController.swift](Nida/NotchPanelController.swift): geometry, pointer bounds and hover/focus behavior.
- [NidaApp.swift](Nida/NidaApp.swift): menu and native Settings composition.
