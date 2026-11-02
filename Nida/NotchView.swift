import SwiftUI

struct NotchView: View {
    let model: PrototypeModel
    let controller: NotchPanelController
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = model.geometry.size(for: model.state, scheduleStatusHeight: controller.scheduleStatusHeight)
        VStack(spacing: 0) {
            Group {
                if model.state == .collapsed {
                    Button {
                        controller.show(.schedule, interactive: true)
                    } label: {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: model.geometry.cameraHeight)
                            Capsule().fill(NidaStyle.text.opacity(model.isHovering ? 0.65 : 0))
                                .frame(width: 20, height: 2)
                                .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Buka jadwal Nida")
                    .help("Buka jadwal")
                    .accessibilityHint("Membuka jadwal sholat hari ini di bawah kamera")
                } else {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: model.geometry.cameraHeight)
                        if model.state == .schedule {
                            ScheduleView(store: controller.schedules, onClose: { controller.show(.collapsed) })
                        } else {
                            reminder
                                .padding(.horizontal, 30)
                                .padding(.top, 20)
                        }
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background { surface }
        .clipShape(NotchSilhouette())
        .shadow(color: .black.opacity(model.state == .collapsed ? 0 : 0.14), radius: 16, x: 0, y: 8)
        .onHover { controller.setHovering($0) }
        .animation(reduceMotion ? nil : .spring(duration: 0.26, bounce: 0.08),
                   value: model.state)
        .frame(width: NotchGeometry.canvasSize.width, height: NotchGeometry.canvasSize.height,
               alignment: .top)
        .preferredColorScheme(.dark)
        .foregroundStyle(NidaStyle.text)
        .tint(NidaStyle.text)
    }

    @ViewBuilder private var surface: some View {
        if model.state == .collapsed { Color.clear }
        else { NidaGlassBackground(shape: NotchSilhouette(), cornerRadius: 0) }
    }

    private var reminderSubtitle: LocalizedStringResource {
        guard let event = model.reminder else {
            return model.state == .prayer ? "15.12 · Saatnya ambil jeda" : "\(controller.preferences.delayMinutes) menit sejak masuk waktu \(PrayerKind.ashar.label.localized(in: locale))"
        }
        if event.id.stage == .entry {
            let time = event.prayerStartsAt.formatted(Date.FormatStyle(
                locale: locale, timeZone: controller.schedules.location?.zone.timeZone ?? .gmt)
                .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            return "\(time) · Saatnya ambil jeda"
        }
        if case .snooze = event.id.stage { return "Pengingat tunda · \(event.id.occurrence.prayer.label.localized(in: locale))" }
        let minutes = Int(event.firesAt.timeIntervalSince(event.prayerStartsAt) / 60)
        return "\(minutes) menit sejak masuk waktu \(event.id.occurrence.prayer.label.localized(in: locale))"
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: NidaStyle.groupGap) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(NidaStyle.text)
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08), in: .circle)
                    .overlay { Circle().strokeBorder(NidaStyle.hairline, lineWidth: 0.5) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text((model.state == .prayer ? LocalizedStringResource("Waktunya \((model.reminder?.id.occurrence.prayer ?? .ashar).label.localized(in: locale))") : LocalizedStringResource("Yuk, sholat dulu")).localized(in: locale))
                        .font(.system(size: 18, weight: .semibold))
                    Text(reminderSubtitle.localized(in: locale))
                        .font(.system(size: 12))
                        .foregroundStyle(NidaStyle.secondaryText)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 0)
                Button { controller.show(.schedule, interactive: true) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        .frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
                }
                .buttonStyle(NidaButtonStyle())
                .help("Lihat jadwal")
                .accessibilityLabel("Lihat jadwal")
            }
            if model.state == .followUp {
                HStack(spacing: NidaStyle.groupGap) {
                    Button { controller.dismissReminder() } label: {
                        Text("Tutup")
                            .frame(maxWidth: .infinity, minHeight: NidaStyle.controlHeight)
                    }
                    .buttonStyle(NidaButtonStyle())
                    .help("Tutup pengingat ini")
                    Button { controller.snoozeReminder() } label: {
                        Text("Ingatkan 5 menit lagi")
                            .frame(maxWidth: .infinity, minHeight: NidaStyle.controlHeight)
                    }
                    .buttonStyle(NidaButtonStyle(prominent: true))
                    .help("Ingatkan satu kali lagi setelah 5 menit")
                }
                .controlSize(.regular)
                .buttonBorderShape(.capsule)
                .font(.system(size: 12, weight: .medium))
            }
            Text((model.notice ?? (model.reminder == nil ? LocalizedStringResource("Preview · Data contoh") : LocalizedStringResource("Pengingat pribadi · Bukan jadwal iqomah masjid"))).localized(in: locale))
                .font(.system(size: 11))
                .foregroundStyle(NidaStyle.secondaryText)
                .accessibilityLabel((model.notice ?? (model.reminder == nil ? LocalizedStringResource("Preview dengan data contoh, bukan jadwal sebenarnya") : LocalizedStringResource("Pengingat pribadi"))).localized(in: locale))
        }
    }
}

// AppKit's glass view samples the desktop directly, without stacking a popover blur beneath it.
struct DesktopGlass: NSViewRepresentable {
    var cornerRadius: CGFloat = 26
    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.style = .regular
        view.cornerRadius = cornerRadius
        view.tintColor = NSColor.white.withAlphaComponent(0.08)
        view.contentView = NSView()
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) { nsView.cornerRadius = cornerRadius }
}

struct NidaGlassBackground<S: Shape>: View {
    let shape: S
    var cornerRadius: CGFloat = 26
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        if reduceTransparency || contrast == .increased {
            shape.fill(NidaStyle.opaqueGlass).allowsHitTesting(false).accessibilityHidden(true)
        } else {
            DesktopGlass(cornerRadius: cornerRadius).clipShape(shape)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}
