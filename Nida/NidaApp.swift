import SwiftUI
import Darwin

enum AppVariant {
    #if DEBUG
    static let isDevelopment = true
    #else
    static let isDevelopment = false
    #endif

    static var name: String { isDevelopment ? "Nida Dev" : "Nida" }

    static func allowsAutomaticDelivery(arguments: [String]) -> Bool {
        !isDevelopment || arguments.contains("--enable-development-reminders")
    }

    static var developmentNotice: LocalizedStringResource {
        allowsAutomaticDelivery(arguments: ProcessInfo.processInfo.arguments)
            ? "Nida Dev · Pengingat otomatis aktif."
            : "Nida Dev · Preview saja. Pengingat otomatis nonaktif."
    }
}

@main
struct NidaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra(AppVariant.name, systemImage: AppVariant.isDevelopment ? "hammer" : "moon.stars") {
            MenuContent(controller: delegate.controller)
                .appLanguage(delegate.controller.preferences)
        }
        .menuBarExtraStyle(.window)
        Settings {
            NidaSettings(controller: delegate.controller, schedules: delegate.schedules)
                .appLanguage(delegate.controller.preferences)
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
            showReviewWindow(NSHostingView(rootView: NidaSettings(controller: controller, schedules: schedules).appLanguage(controller.preferences)), titled: true)
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--review-menu") {
            showReviewWindow(NSHostingView(rootView: MenuContent(controller: controller).appLanguage(controller.preferences)), titled: false)
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
        if AppVariant.allowsAutomaticDelivery(arguments: ProcessInfo.processInfo.arguments) {
            delivery.start()
        } else {
            Task { await schedules.restoreAndRefresh() }
        }
        if !schedules.onboardingComplete { showLocationSetup() }
    }

    #if DEBUG
    private func showReviewWindow(_ host: NSView, titled: Bool) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: titled ? [.titled, .closable] : [.borderless], backing: .buffered, defer: false)
        window.title = AppVariant.name + " · Design review"
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
        window.title = LocalizedStringResource("Selamat datang di Nida").localized(in: controller.preferences.language.locale)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LocationOnboardingView(store: schedules) { [weak window] in
            window?.close()
        }.appLanguage(controller.preferences)
            .onChange(of: controller.preferences.language) { [weak window] _, language in
                window?.title = LocalizedStringResource("Selamat datang di Nida").localized(in: language.locale)
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
            #if DEBUG
            Text(AppVariant.developmentNotice.localized(in: controller.preferences.language.locale))
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.top, 10)
            #endif
            ScheduleView(store: controller.schedules, onOpenNotch: { preview(.schedule) })
                .fixedSize(horizontal: false, vertical: true)
            NidaStyle.hairline.frame(height: 0.5).padding(.horizontal, 16)
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button { previewExpanded.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.badge")
                                .font(.system(size: 12))
                            Text("Coba pengingat")
                            Image(systemName: previewExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .frame(minHeight: NidaStyle.iconControlSize)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(Text(previewExpanded ? LocalizedStringKey("Terbuka") : LocalizedStringKey("Tertutup")))
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Button { Task { await controller.schedules.refresh() } } label: {
                            Group {
                                if controller.schedules.isRefreshing { ProgressView().controlSize(.mini) }
                                else { Image(systemName: "arrow.clockwise") }
                            }
                            .frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
                        }
                        .disabled(controller.schedules.location == nil || controller.schedules.isRefreshing)
                        .accessibilityLabel("Perbarui jadwal").help("Perbarui jadwal")
                        Button {
                            NSApplication.shared.keyWindow?.close()
                            controller.dismissReminder()
                            NSApplication.shared.activate()
                            openSettings()
                        } label: {
                            Image(systemName: "gearshape")
                                .frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
                        }
                        .accessibilityLabel("Pengaturan").help("Pengaturan")
                        Button { NSApplication.shared.terminate(nil) } label: {
                            Image(systemName: "power")
                                .frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
                        }
                        .accessibilityLabel("Keluar").help("Keluar dari Nida")
                    }
                    .font(.system(size: 12)).buttonStyle(NidaButtonStyle())
                }
                .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                if previewExpanded {
                    HStack(spacing: 8) {
                        Button { preview(.prayer) } label: {
                            Text("Masuk waktu").frame(maxWidth: .infinity, minHeight: NidaStyle.controlHeight)
                        }
                        Button { preview(.followUp) } label: {
                            Text("Pengingat kedua").frame(maxWidth: .infinity, minHeight: NidaStyle.controlHeight)
                        }
                    }
                    .font(.system(size: 12)).buttonStyle(NidaButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 16)
        }
        .frame(width: 340)
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
    @Environment(\.locale) private var locale
    @State private var isScrolled = false

    var body: some View {
        @Bindable var preferences = controller.preferences
        Form {
            Section("Bahasa") {
                Picker("Bahasa aplikasi", selection: $preferences.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(verbatim: language.name).tag(language)
                    }
                }
            }
            Section(AppVariant.name) {
                Text("Ambil jeda, kembali tenang.").font(.headline)
                #if DEBUG
                Text(AppVariant.developmentNotice.localized(in: locale))
                    .foregroundStyle(.secondary)
                #else
                Text("Jadwal asli tersedia di menu bar dan notch. Pengingat otomatis aktif saat Nida berjalan dan Mac terjaga. Tombol coba pengingat memakai data contoh.")
                    .foregroundStyle(.secondary)
                #endif
            }
            ReminderPreferencesView(controller: controller)
            PrayerDataSettings(store: schedules)
            Section("Coba tampilan notch") {
                ForEach(PreviewState.allCases, id: \.self) { state in
                    Button(state.label.localized(in: locale)) { controller.show(state) }
                }
                Text("Klik garis kecil di bawah kamera untuk membuka jadwal. Escape atau klik di luar panel untuk menutup.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("Tentang Nida") {
                LabeledContent("Versi", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                LabeledContent("Minimum macOS", value: "26.0")
                LabeledContent("Pengingat") {
                    #if DEBUG
                    Text(AppVariant.developmentNotice.localized(in: locale))
                    #else
                    Text("Aktif · Jeda \(controller.preferences.delayMinutes) menit")
                    #endif
                }
                Text("Preview tunda hanya menampilkan konfirmasi; tidak menjadwalkan pengingat.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 1
        } action: { _, scrolled in
            isScrolled = scrolled
        }
        .scrollContentBackground(.hidden)
        .frame(width: 520, height: 660)
        .background { NidaGlassBackground(shape: Rectangle(), cornerRadius: 0).ignoresSafeArea() }
        .toolbarBackground(.black.opacity(0.25), for: .windowToolbar)
        .toolbarBackgroundVisibility(isScrolled ? .visible : .hidden, for: .windowToolbar)
        .containerBackground(.clear, for: .window)
        .preferredColorScheme(.dark)
    }
}
