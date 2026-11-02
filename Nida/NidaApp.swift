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
            NidaSettings(controller: delegate.controller, schedules: delegate.schedules)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)

    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = NotchPanelController()
    var schedules: PrayerDataStore { controller.schedules }
    private lazy var delivery = ReminderDelivery(controller: controller)
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--review-settings") {
            showReviewWindow(NSHostingView(rootView: NidaSettings(controller: controller, schedules: schedules)), titled: true)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--review-menu") {
            showReviewWindow(NSHostingView(rootView: MenuContent(controller: controller)), titled: false)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--review-refresh-error") {
            controller.show(.schedule, interactive: true)
            Task {
                await schedules.restoreAndRefresh()
                schedules.showRefreshFailureForReview()
            }
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--review-notch") {
            controller.show(.schedule, interactive: true)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--review-follow-up") {
            controller.show(.followUp, interactive: true)
            return
        }
        #endif
        delivery.start()
        if !schedules.onboardingComplete { showLocationSetup() }
    }

    #if DEBUG
    private func showReviewWindow(_ host: NSView, titled: Bool) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: titled ? [.titled, .closable] : [.borderless], backing: .buffered, defer: false)
        window.title = "Nida · Design review"
        if titled {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.toolbarStyle = .unified
        }
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isReleasedWhenClosed = false
        window.contentView = host
        setupWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }
    #endif

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

    func applicationWillTerminate(_ notification: Notification) { delivery.stop(); controller.stop() }
}

struct MenuContent: View {
    let controller: NotchPanelController
    @Environment(\.openSettings) private var openSettings
    @State private var previewExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            ScheduleView(store: controller.schedules, onOpenNotch: { preview(.schedule) })
                .frame(height: 344 + controller.scheduleStatusHeight)
            NidaStyle.hairline.frame(height: 0.5)
            VStack(alignment: .leading, spacing: 14) {
                DisclosureGroup("Coba pengingat", isExpanded: $previewExpanded) {
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Button("Masuk waktu") { preview(.prayer) }
                            Button("Pengingat kedua") { preview(.followUp) }
                        }
                        .buttonStyle(.glass).buttonBorderShape(.capsule)
                        .controlSize(.regular).tint(.clear)
                        .padding(.top, 8)
                    }
                }
                .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                HStack {
                    Button("Pengaturan", systemImage: "gearshape") {
                        NSApplication.shared.activate()
                        openSettings()
                    }
                    Spacer()
                    Button("Keluar") { NSApplication.shared.terminate(nil) }
                }
                .font(.system(size: 12)).buttonStyle(.plain)
                .foregroundStyle(NidaStyle.secondaryText)
            }
            .padding(.horizontal, 30).padding(.vertical, 16)
        }
        .frame(width: 384)
        .background { NidaGlassBackground(shape: Rectangle(), cornerRadius: 0) }
        .foregroundStyle(NidaStyle.text)
        .tint(NidaStyle.text)
        .preferredColorScheme(.dark)
    }

    private func preview(_ state: PreviewState) {
        NSApplication.shared.keyWindow?.close()
        controller.show(state, interactive: state == .schedule)
    }
}

struct NidaSettings: View {
    let controller: NotchPanelController
    let schedules: PrayerDataStore

    var body: some View {
        Form {
            Section("Nida") {
                Text("Ambil jeda, kembali tenang.").font(.headline)
                Text("Jadwal asli tersedia di menu bar dan notch. Pengingat otomatis aktif saat Nida berjalan dan Mac terjaga. Tombol coba pengingat memakai data contoh.")
                    .foregroundStyle(.secondary)
            }
            ReminderPreferencesView(controller: controller)
            PrayerDataSettings(store: schedules)
            Section("Coba tampilan notch") {
                ForEach(PreviewState.allCases, id: \.self) { state in
                    Button(state.label) { controller.show(state) }
                }
                Text("Klik garis kecil di bawah kamera untuk membuka jadwal. Escape atau klik di luar panel untuk menutup.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Tentang Nida") {
                LabeledContent("Minimum macOS", value: "26.0")
                LabeledContent("Pengingat", value: "Aktif · Jeda \(controller.preferences.delayMinutes) menit")
                Text("Preview tunda hanya menampilkan konfirmasi; tidak menjadwalkan pengingat.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 520, height: 660)
        .background { NidaGlassBackground(shape: Rectangle(), cornerRadius: 0).ignoresSafeArea() }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .containerBackground(.clear, for: .window)
        .tint(NidaStyle.text)
        .preferredColorScheme(.dark)
    }
}
