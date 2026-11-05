# Nida

Native macOS prayer reminder: SwiftUI content, AppKit notch panel, menu bar access. Follow the current GitHub issue; [parent #1](https://github.com/choiruladamm/nida/issues/1) owns MVP scope.

## Read when relevant

- UI or motion changes: read `DESIGN.md` first. The accepted notch design uses a black camera-integrated surface with subtle lower glass; menu and Settings retain frosted glass.
- API/cache/date changes: read `docs/prayer-data.md` for the verified contract, time-zone mapping, and data/UI boundary.
- Location/onboarding changes: read `docs/location-setup.md` for permission, matching, persistence, and pending hardware checks.
- Timing/reminder calculations: read `docs/prayer-timing.md` for exact boundaries, pending-state preservation, and expiry rules.
- Notch/window changes: read `docs/notch-prototype.md` for measured geometry and pending hardware checks.
- Build/setup: see `README.md`; run `make help` for commands.

## Implementation

- Prefer native frameworks and existing views. Keep AppKit window management separate from SwiftUI content; keep scheduling/data logic independent of views.
- Fetch current Apple/API documentation through Context7: resolve the library, then query the relevant concept. Use official documentation when coverage is missing. Check availability against the project's compiler and deployment target.
- Use `swiftui-expert-skill`, `write-swift`, and `emil-design-eng` when available and relevant. Translate animation principles to native APIs; browser-specific examples are not SwiftUI rules.
- Derive camera clearance and placement from the selected screen. Preserve its physical silhouette while collapsed; automatic reminders must not take keyboard focus.
- Keep reminder previews visibly labeled; menu bar, notch, and Settings schedules share the live store. Request location only on explicit action; delivery state must persist before showing real reminders; previews never mutate its ledger. A follow-up reminder is not a mosque iqomah time.
- Add Swift source files to the appropriate target in `Nida.xcodeproj`; this project uses explicit file references.

## Verification and delivery

- Run `make test` for logic/geometry changes and `make build` for compile checks. Add focused regression coverage for changed behavior.
- For panel changes, run `make smoke` after tests finish; it terminates only Nida Dev (including its test host). Default `make run` restarts only Dev; keep daily `/Applications/Nida.app` running. Release uses the Stable identity. Read `docs/dev-stable.md` for isolation, opt-in delivery and the remaining #34 stages.
- Review actual glass, fit, motion, and input on hardware. Passing tests or app-view raster caches do not prove visual quality. Record untested fullscreen, accessibility, and display scenarios honestly.
- Keep technical docs, issues, and Conventional Commit messages in English. Product copy follows the selected app language (Indonesian or English). Link the relevant issue and update evidence without closing incomplete acceptance checks.
- Before handing back each task, update the active GitHub issue and parent #1 with current progress, PR/commit/release links, verification evidence, and remaining checks. After merges, reconcile implementation checkboxes and the execution summary. Mark hardware acceptance passed only when observed; a closed issue or merged PR alone is not proof.
