import SwiftUI

struct NotchView: View {
    let model: PrototypeModel
    let controller: NotchPanelController
    @State private var contentHeights: [PreviewState: CGFloat] = [:]
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        fittedPanel
        .frame(width: NotchGeometry.canvasSize.width, height: NotchGeometry.canvasSize.height,
               alignment: .top)
        .preferredColorScheme(.dark)
        .foregroundStyle(NidaStyle.text)
        .tint(NidaStyle.text)
    }

    var fittedPanel: some View {
        let size = model.geometry.size(for: model.state, scheduleStatusHeight: controller.scheduleStatusHeight)
        return VStack(spacing: 0) {
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
                    expandedPanel
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                            guard model.state != .collapsed else { return }
                            contentHeights[model.state] = height
                        }
                        .transition(NotchMotion.contentTransition(reduceMotion: reduceMotion))
                }
            }
        }
        .frame(width: size.width, height: model.state == .collapsed ? size.height : contentHeights[model.state], alignment: .top)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
            controller.updatePanelHeight(height)
        }
        .background { surface.opacity(model.state == .collapsed ? 0 : 1) }
        .clipShape(NotchSilhouette())
        .overlay {
            if model.state != .collapsed {
                NotchSilhouette().stroke(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.4),
                        .init(color: .white.opacity(contrast == .increased ? 0.5 : 0.18), location: 1)
                    ], startPoint: .top, endPoint: .bottom), lineWidth: 0.75)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .shadow(color: .black.opacity(model.state == .collapsed ? 0 : 0.14), radius: 16, x: 0, y: 8)
        .onHover { controller.setHovering($0) }
        .animation(NotchMotion.panelAnimation(isCollapsed: model.state == .collapsed,
                                              reduceMotion: reduceMotion), value: model.state)
    }

    @ViewBuilder private var surface: some View {
        if reduceTransparency || contrast == .increased { Color.black }
        else {
            ZStack {
                NidaGlassBackground(shape: NotchSilhouette(), cornerRadius: 0)
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.5),
                    .init(color: .black.opacity(0.88), location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var reminderTime: String {
        guard let event = model.reminder else { return "15:12" }
        return event.prayerStartsAt.formatted(Date.FormatStyle(
            locale: locale, timeZone: controller.schedules.location?.zone.timeZone ?? .gmt)
            .hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    private var reminderSubtitle: LocalizedStringResource {
        guard let event = model.reminder else {
            return model.state == .prayer ? "Saatnya ambil jeda" : "\(controller.preferences.delayMinutes) menit sejak masuk waktu \(PrayerKind.ashar.label.localized(in: locale))"
        }
        if event.id.stage == .entry { return "Saatnya ambil jeda" }
        if case .snooze = event.id.stage { return "Pengingat tunda · \(event.id.occurrence.prayer.label.localized(in: locale))" }
        let minutes = Int(event.firesAt.timeIntervalSince(event.prayerStartsAt) / 60)
        return "\(minutes) menit sejak masuk waktu \(event.id.occurrence.prayer.label.localized(in: locale))"
    }

    // Keep the camera lane empty; narrow wings fall back to a toolbar below it.
    var expandedPanel: some View {
        let width = model.geometry.size(for: model.state).width
        let besideCamera = model.geometry.hasCameraWings(panelWidth: width)
        return VStack(spacing: 0) {
            if !besideCamera {
                Color.clear.frame(height: model.geometry.cameraHeight)
            }
            HStack(spacing: 0) {
                Image(systemName: model.state == .schedule ? "calendar" : "moon.stars.fill")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 28, height: 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
                Color.clear.frame(width: besideCamera ? model.geometry.cameraWidth : 0)
                Group {
                    if model.state == .schedule {
                        Text(Date().formatted(Date.FormatStyle(locale: locale,
                            timeZone: controller.schedules.location?.zone.timeZone ?? .gmt)
                            .day().month(.abbreviated)))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NidaStyle.secondaryText)
                    } else if model.state == .prayer {
                        Button { controller.dismissReminder() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help("Tutup pengingat ini")
                        .accessibilityLabel("Tutup pengingat ini")
                    } else {
                        Button { controller.show(.schedule, interactive: true) } label: {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .help("Lihat jadwal")
                        .accessibilityLabel("Lihat jadwal")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: besideCamera ? max(36, model.geometry.cameraHeight) : 28)
            .padding(.horizontal, NidaStyle.notchHorizontalInset)
            if model.state == .schedule {
                ScheduleView(store: controller.schedules, isNotch: true, onOpenSettings: { controller.dismissReminder() })
            } else {
                reminder
                    .padding(.horizontal, NidaStyle.notchHorizontalInset)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
        }
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.state.label.localized(in: locale))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NidaStyle.secondaryText)
                HStack(alignment: .firstTextBaseline) {
                    Text((model.reminder?.id.occurrence.prayer ?? .ashar).label.localized(in: locale))
                        .font(.system(size: 26, weight: .semibold))
                    Spacer(minLength: 12)
                    Text(verbatim: reminderTime)
                        .font(.system(size: 32, weight: .regular))
                        .monospacedDigit()
                }
                Text(reminderSubtitle.localized(in: locale))
                    .font(.system(size: 12))
                    .foregroundStyle(NidaStyle.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if model.state == .followUp {
                HStack(spacing: NidaStyle.groupGap) {
                    Button { controller.dismissReminder() } label: {
                        Text("Tutup")
                            .padding(.horizontal, 16)
                            .frame(minHeight: 30)
                    }
                    .buttonStyle(NidaButtonStyle(flat: true))
                    .help("Tutup pengingat ini")
                    Button { controller.snoozeReminder() } label: {
                        Label("Ingatkan 5 menit lagi", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 30)
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

private enum NotchMotion {
    static func panelAnimation(isCollapsed: Bool, reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        return isCollapsed ? .smooth(duration: 0.24) : .spring(response: 0.4, dampingFraction: 0.82)
    }

    static func contentTransition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.18).delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.1))
        )
    }
}
