import SwiftUI

struct NotchView: View {
    let model: PrototypeModel
    let controller: NotchPanelController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let size = model.geometry.size(for: model.state)
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
                } else {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: model.geometry.cameraHeight)
                        if model.state == .schedule {
                            ScheduleView(store: controller.schedules, onClose: { controller.show(.collapsed) })
                        } else {
                            reminder
                                .padding(.horizontal, NidaStyle.panelInset + 10)
                                .padding(.top, 16)
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
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.28, bounce: 0.12),
                   value: model.state)
        .frame(width: NotchGeometry.canvasSize.width, height: NotchGeometry.canvasSize.height,
               alignment: .top)
        .preferredColorScheme(.dark)
        .foregroundStyle(NidaStyle.text)
        .tint(NidaStyle.text)
    }

    @ViewBuilder private var surface: some View {
        if model.state == .collapsed {
            Color.clear
        } else if reduceTransparency || contrast == .increased {
            NidaStyle.opaqueGlass
        } else {
            Color.white.opacity(0.08)
                .background { DesktopMaterial() }
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: NotchSilhouette())
        }
    }

    private var reminderSubtitle: String {
        guard let event = model.reminder else {
            return model.state == .prayer ? "15.12 · Saatnya ambil jeda" : "10 menit sejak masuk waktu Ashar"
        }
        if event.id.stage == .entry {
            let format = Date.FormatStyle(date: .omitted, time: .shortened,
                locale: Locale(identifier: "id_ID"), timeZone: controller.schedules.location?.zone.timeZone ?? .gmt)
            return event.prayerStartsAt.formatted(format) + " · Saatnya ambil jeda"
        }
        if case .snooze = event.id.stage { return "Pengingat tunda · \(event.id.occurrence.prayer.label)" }
        let minutes = Int(event.firesAt.timeIntervalSince(event.prayerStartsAt) / 60)
        return "\(minutes) menit sejak masuk waktu \(event.id.occurrence.prayer.label)"
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: NidaStyle.groupGap) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(NidaStyle.text)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: .circle)
                    .overlay { Circle().strokeBorder(NidaStyle.hairline, lineWidth: 0.5) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.state == .prayer ? "Waktunya \(model.reminder?.id.occurrence.prayer.label ?? "Ashar")" : "Yuk, sholat dulu")
                        .font(.system(size: 18, weight: .medium))
                    Text(reminderSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(NidaStyle.secondaryText)
                }
                Spacer(minLength: 0)
                Button { controller.show(.schedule, interactive: true) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(.clear)
                .foregroundStyle(NidaStyle.secondaryText)
                .accessibilityLabel("Lihat jadwal")
            }
            if model.state == .followUp {
                HStack(spacing: NidaStyle.groupGap) {
                    Button { controller.dismissReminder() } label: {
                        Text("Tutup")
                            .foregroundStyle(NidaStyle.text)
                            .frame(maxWidth: .infinity, minHeight: NidaStyle.controlHeight)
                            .background(.white.opacity(0.10), in: .capsule)
                            .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    Button { controller.snoozeReminder() } label: {
                        Text("Ingatkan 5 menit lagi")
                            .foregroundStyle(NidaStyle.surface)
                            .frame(maxWidth: .infinity, minHeight: NidaStyle.controlHeight)
                            .background(NidaStyle.text, in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
                .controlSize(.regular)
                .buttonBorderShape(.capsule)
                .font(.system(size: 12, weight: .medium))
            }
            Text(model.notice ?? (model.reminder == nil ? "Preview · Data contoh" : "Pengingat pribadi · Bukan jadwal iqomah masjid"))
                .font(.system(size: 10))
                .foregroundStyle(NidaStyle.secondaryText)
                .accessibilityLabel(model.notice ?? (model.reminder == nil ? "Preview dengan data contoh, bukan jadwal sebenarnya" : "Pengingat pribadi"))
        }
    }
}

// SwiftUI glass samples the view hierarchy; this material also blurs the desktop behind our window.
struct DesktopMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
