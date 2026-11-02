import SwiftUI
import Darwin

@main
struct NidaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Nida", systemImage: "moon.stars") {
            MenuContent(controller: delegate.controller)
        }
        .menuBarExtraStyle(.window)
        Settings {
            PrototypeSettings(controller: delegate.controller, schedules: delegate.schedules)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = NotchPanelController()
    let schedules = PrayerDataStore()
    private var setupWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests use the app host without adding a panel to the user's desktop.
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] == nil,
              environment["XCTestBundlePath"] == nil else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--data-smoke") {
            Task {
                do {
                    print(try await PrayerRepository.liveSmokeCheck())
                    exit(EXIT_SUCCESS)
                } catch {
                    FileHandle.standardError.write(Data("Nida data smoke failed: \(error.localizedDescription)\n".utf8))
                    exit(EXIT_FAILURE)
                }
            }
            return
        }
        #endif
        controller.start()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            controller.runSmokeCheck()
            return
        }
        #endif
        if !schedules.onboardingComplete { showLocationSetup() }
    }

    private func showLocationSetup() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Selamat datang di Nida"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LocationOnboardingView(store: schedules) { [weak window] in
            window?.close()
        })
        setupWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}

struct MenuContent: View {
    let controller: NotchPanelController
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(spacing: 0) {
            ScheduleView()
            NidaStyle.hairline.frame(height: 0.5)
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Coba pengingat")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Button { preview(.schedule) } label: {
                        Image(systemName: "arrow.up.right")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(.clear)
                    .accessibilityLabel("Buka jadwal di notch")
                }
                HStack(spacing: NidaStyle.groupGap) {
                    Button("Masuk waktu") { preview(.prayer) }
                    Button("Pengingat kedua") { preview(.followUp) }
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .tint(.clear)
                .controlSize(.large)
                .font(.system(size: 12))
                HStack {
                    Button("Pengaturan", systemImage: "gearshape") {
                        NSApplication.shared.activate()
                        openSettings()
                    }
                    Spacer()
                    Button("Keluar") { NSApplication.shared.terminate(nil) }
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
                .foregroundStyle(NidaStyle.secondaryText)
            }
            .padding(NidaStyle.panelInset)
        }
        .frame(width: 368)
        .background {
            if reduceTransparency || contrast == .increased {
                NidaStyle.opaqueGlass
            } else {
                Color.white.opacity(0.08).background { DesktopMaterial() }
            }
        }
        .foregroundStyle(NidaStyle.text)
        .tint(NidaStyle.text)
        .preferredColorScheme(.dark)
    }

    private func preview(_ state: PreviewState) {
        NSApplication.shared.keyWindow?.close()
        controller.show(state, interactive: state == .schedule)
    }
}

struct PrototypeSettings: View {
    let controller: NotchPanelController
    let schedules: PrayerDataStore

    var body: some View {
        Form {
            Section("Nida") {
                Text("Ambil jeda, kembali tenang.").font(.headline)
                Text("Jadwal asli tersedia di bawah. Preview notch masih data contoh; pengingat otomatis belum aktif.")
                    .foregroundStyle(.secondary)
            }
            PrayerDataSettings(store: schedules)
            Section("Coba tampilan notch") {
                ForEach(PreviewState.allCases, id: \.self) { state in
                    Button(state.label) { controller.show(state) }
                }
                Text("Klik garis kecil di bawah kamera untuk membuka jadwal. Escape atau klik di luar panel untuk menutup.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Tentang prototipe") {
                LabeledContent("Minimum macOS", value: "26.0")
                LabeledContent("Pengingat", value: "Preview · Tidak dijadwalkan")
                Text("Preview tunda hanya menampilkan konfirmasi; tidak menjadwalkan pengingat.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 660)
        .tint(NidaStyle.text)
        .preferredColorScheme(.dark)
    }
}
