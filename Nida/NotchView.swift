import SwiftUI

struct NotchView: View {
    let model: PrototypeModel
    let controller: NotchPanelController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    private let sage = Color(red: 0.75, green: 0.82, blue: 0.67)

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
                            Capsule().fill(sage.opacity(model.isHovering ? 1 : 0.55))
                                .frame(width: 22, height: 3)
                                .frame(height: 12)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Buka jadwal contoh Nida")
                    .help("Buka jadwal contoh")
                } else {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: model.geometry.cameraHeight + 14)
                        if model.state == .schedule {
                            ScheduleView(onClose: { controller.show(.collapsed) })
                                .padding(.horizontal, 24)
                        } else {
                            reminder
                                .padding(.horizontal, 24)
                        }
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background { surface }
        .clipShape(.rect(topLeadingRadius: 10, bottomLeadingRadius: 28,
                         bottomTrailingRadius: 28, topTrailingRadius: 10))
        .overlay(alignment: .top) {
            if model.geometry.cameraHeight > 0 {
                Color.black.frame(height: model.geometry.cameraHeight)
                    .allowsHitTesting(false)
            }
        }
        .onHover { controller.setHovering($0) }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.28, bounce: 0.12),
                   value: model.state)
        .frame(width: NotchGeometry.canvasSize.width, height: NotchGeometry.canvasSize.height,
               alignment: .top)
        .preferredColorScheme(.dark)
        .tint(sage)
    }

    @ViewBuilder private var surface: some View {
        if reduceTransparency || contrast == .increased || model.state == .collapsed {
            Color.black
        } else {
            Rectangle()
                .fill(.black.opacity(0.25))
                .background { DesktopMaterial() }
                .glassEffect(.regular.tint(.black.opacity(0.45)),
                             in: .rect(topLeadingRadius: 10, bottomLeadingRadius: 28,
                                       bottomTrailingRadius: 28, topTrailingRadius: 10))
        }
    }

    private var reminder: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(sage)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.state == .prayer ? "Waktunya Ashar" : "Yuk, sholat dulu")
                        .font(.system(size: 19, weight: .semibold))
                    Text(model.state == .prayer
                         ? "15.12 · Saatnya ambil jeda"
                         : "10 menit sejak masuk waktu Ashar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button { controller.show(.schedule, interactive: true) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Lihat jadwal contoh")
            }
            if model.state == .followUp {
                HStack(spacing: 10) {
                    Button("Tutup") { controller.show(.collapsed) }
                        .buttonStyle(.glass)
                    Button("Ingatkan 5 menit lagi") { controller.previewSnooze() }
                        .buttonStyle(.glassProminent)
                }
                .controlSize(.large)
                .buttonSizing(.flexible)
            }
            Text(model.notice ?? "PREVIEW · DATA CONTOH")
                .font(.system(size: 9, weight: .medium))
                .tracking(model.notice == nil ? 1.3 : 0)
                .foregroundStyle(.secondary)
                .accessibilityLabel(model.notice ?? "Preview dengan data contoh, bukan jadwal sebenarnya")
        }
    }
}

// SwiftUI glass samples the view hierarchy; this material also blurs the desktop behind our window.
private struct DesktopMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
