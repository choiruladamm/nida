import SwiftUI

@main
struct NidaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Nida", systemImage: "moon.stars") {
            MenuContent(controller: delegate.controller)
        }
        .menuBarExtraStyle(.window)
        Settings {
            PrototypeSettings(controller: delegate.controller)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = NotchPanelController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests use the app host without adding a panel to the user's desktop.
        let environment = ProcessInfo.processInfo.environment
        guard environment["XCTestConfigurationFilePath"] == nil,
              environment["XCTestBundlePath"] == nil else { return }
        controller.start()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            controller.runSmokeCheck()
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}

struct MenuContent: View {
    let controller: NotchPanelController
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScheduleView()
            Divider()
            Text("NOTCH PREVIEW").font(.system(size: 9, weight: .medium))
                .tracking(1.5).foregroundStyle(.secondary)
            HStack {
                Button("Masuk waktu") { preview(.prayer) }
                Button("Pengingat kedua") { preview(.followUp) }
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            Button("Buka di notch", systemImage: "rectangle.topthird.inset.filled") {
                preview(.schedule)
            }
            HStack {
                Button("Pengaturan", systemImage: "gearshape") {
                    NSApplication.shared.activate()
                    openSettings()
                }
                Spacer()
                Button("Keluar") { NSApplication.shared.terminate(nil) }
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 368)
    }

    private func preview(_ state: PreviewState) {
        NSApplication.shared.keyWindow?.close()
        controller.show(state, interactive: state == .schedule)
    }
}

struct PrototypeSettings: View {
    let controller: NotchPanelController

    var body: some View {
        Form {
            Section("Nida · Notch prototype") {
                Text("Ambil jeda, kembali tenang.").font(.headline)
                Text("Semua jadwal adalah data contoh. Pengingat asli, lokasi, dan suara belum aktif.")
                    .foregroundStyle(.secondary)
            }
            Section("Coba tampilan notch") {
                ForEach(PreviewState.allCases, id: \.self) { state in
                    Button(state.label) { controller.show(state) }
                }
                Text("Klik garis kecil di bawah kamera untuk membuka jadwal. Escape atau klik di luar panel untuk menutup.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Tentang prototipe") {
                LabeledContent("Minimum macOS", value: "26.0")
                LabeledContent("Data", value: "Contoh · Tidak dijadwalkan")
                Text("Preview tunda hanya menampilkan konfirmasi; tidak menjadwalkan pengingat.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 510)
    }
}
