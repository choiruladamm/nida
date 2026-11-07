import AppKit
import CoreFoundation
import ServiceManagement
import SwiftUI
import Observation

@MainActor protocol ReminderSoundPlayback: AnyObject {
    @discardableResult func play() -> Bool
    @discardableResult func stop() -> Bool
}

extension NSSound: ReminderSoundPlayback {}

enum ReminderSound: String, CaseIterable {
    case glass = "Glass"
    case tink = "Tink"
    case ping = "Ping"
}

@MainActor @Observable
final class ReminderPreferences {
    private let defaults: UserDefaults
    private(set) var delayMinutes: Int
    private(set) var entryDisplaySeconds: Double
    private(set) var followUpDisplaySeconds: Double
    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: "appLanguage") }
    }
    var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: "reminderSoundEnabled")
            if !soundEnabled { activeSound?.stop(); activeSound = nil }
        }
    }
    var soundPreset: ReminderSound {
        didSet { defaults.set(soundPreset.rawValue, forKey: "reminderSoundPreset") }
    }
    @ObservationIgnored private var activeSound: (any ReminderSoundPlayback)?
    @ObservationIgnored private let loadSound: (ReminderSound) -> (any ReminderSoundPlayback)?
    private(set) var delayError: LocalizedStringResource?
    private(set) var soundError: LocalizedStringResource?

    init(defaults: UserDefaults = .standard,
         loadSound: @escaping (ReminderSound) -> (any ReminderSoundPlayback)? = { NSSound(named: NSSound.Name($0.rawValue)) }) {
        self.defaults = defaults
        self.loadSound = loadSound
        soundPreset = ReminderSound(rawValue: defaults.string(forKey: "reminderSoundPreset") ?? "") ?? .glass
        entryDisplaySeconds = Self.storedDisplaySeconds(defaults, key: "entryDisplaySeconds", fallback: 10)
        followUpDisplaySeconds = Self.storedDisplaySeconds(defaults, key: "followUpDisplaySeconds", fallback: 20)
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage") ?? "") ?? .indonesian
        let saved = defaults.object(forKey: "followUpDelayMinutes")
        let minutes = defaults.integer(forKey: "followUpDelayMinutes")
        if saved == nil { delayMinutes = FollowUpDelay.standard.minutes }
        else if let number = saved as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                number.doubleValue == Double(minutes), (try? FollowUpDelay(minutes: minutes)) != nil {
            delayMinutes = minutes
        }
        else {
            delayMinutes = FollowUpDelay.standard.minutes
            delayError = "Jeda tersimpan tidak valid. Sementara memakai 10 menit; pilih jeda baru untuk menyimpan."
        }
        soundEnabled = defaults.bool(forKey: "reminderSoundEnabled")
    }

    private static func validDisplaySeconds(_ seconds: Double) -> Bool {
        seconds.isFinite && (5...60).contains(seconds) && seconds.truncatingRemainder(dividingBy: 5) == 0
    }

    private static func storedDisplaySeconds(_ defaults: UserDefaults, key: String, fallback: Double) -> Double {
        guard let number = defaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(), validDisplaySeconds(number.doubleValue) else { return fallback }
        return number.doubleValue
    }

    func setDisplaySeconds(_ seconds: Double, for state: PreviewState) {
        guard state.isReminder, Self.validDisplaySeconds(seconds) else { return }
        if state == .prayer {
            entryDisplaySeconds = seconds
            defaults.set(seconds, forKey: "entryDisplaySeconds")
        } else {
            followUpDisplaySeconds = seconds
            defaults.set(seconds, forKey: "followUpDisplaySeconds")
        }
    }

    func displaySeconds(for state: PreviewState) -> Double? {
        switch state {
        case .prayer: entryDisplaySeconds
        case .followUp: followUpDisplaySeconds
        default: nil
        }
    }

    @discardableResult func setDelay(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }),
              let minutes = Int(value), (try? FollowUpDelay(minutes: minutes)) != nil else {
            delayError = "Masukkan bilangan bulat antara 1 dan 60 menit."
            return false
        }
        delayMinutes = minutes
        defaults.set(minutes, forKey: "followUpDelayMinutes")
        delayError = nil
        return true
    }

    func playSound(audition: Bool = false) {
        guard audition || soundEnabled else { return }
        activeSound?.stop()
        activeSound = loadSound(soundPreset)
        soundError = activeSound?.play() == true ? nil
            : LocalizedStringResource("Suara pengingat belum bisa diputar. Coba lagi atau matikan suara.")
    }
}

@MainActor @Observable
final class LoginLaunch {
    private(set) var status: SMAppService.Status
    private(set) var isUpdating = false
    private(set) var error: LocalizedStringResource?
    private let readStatus: () -> SMAppService.Status
    private let update: (Bool) async throws -> Void

    init(readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         update: @escaping (Bool) async throws -> Void = { enabled in
             if enabled { try SMAppService.mainApp.register() }
             else { try await SMAppService.mainApp.unregister() }
         }) {
        self.readStatus = readStatus
        self.update = update
        status = readStatus()
    }

    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    var statusText: LocalizedStringResource {
        switch status {
        case .enabled: "Aktif"
        case .notRegistered: "Nonaktif"
        case .requiresApproval: "Menunggu persetujuan di Pengaturan Sistem"
        case .notFound: "App belum tersedia untuk login otomatis"
        @unknown default: "Status belum dikenali"
        }
    }

    var statusName: String {
        switch status {
        case .enabled: "enabled"
        case .notRegistered: "notRegistered"
        case .requiresApproval: "requiresApproval"
        case .notFound: "notFound"
        @unknown default: "unknown"
        }
    }

    // Called by local promotion only when the OS recorded the owner's enabled intent.
    func restoreEnabledRegistration() async {
        await setEnabled(false)
        guard error == nil else { return }
        await setEnabled(true)
    }

    func refresh() { status = readStatus() }

    func setEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        refresh()
        guard enabled != isRegistered else { return }
        isUpdating = true
        error = nil
        defer { isUpdating = false; refresh() }
        do { try await update(enabled) }
        catch { self.error = "Login otomatis gagal diperbarui. \(error.localizedDescription)" }
    }
}

struct ReminderPreferencesView: View {
    let controller: NotchPanelController
    @Environment(\.locale) private var locale
    @State private var customDelay = ""
    @State private var login = LoginLaunch()

    var body: some View {
        @Bindable var preferences = controller.preferences
        Section("Durasi tampil") {
            displayDurationSlider("Pengingat pertama", state: .prayer)
            displayDurationSlider("Pengingat lanjutan", state: .followUp)
            Text("Tetap tampil saat Anda bekerja di app lain. Berlaku mulai pengingat berikutnya; pengingat yang ditunda memakai durasi lanjutan.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Pengingat kedua") {
            LabeledContent("Jeda aktif") { Text("\(preferences.delayMinutes) menit") }
            HStack {
                ForEach(FollowUpDelay.presets, id: \.minutes) { delay in
                    Button("\(delay.minutes) menit") {
                        if preferences.setDelay(String(delay.minutes)) { customDelay = String(delay.minutes) }
                    }
                }
            }
            HStack {
                TextField("Jeda khusus (1–60 menit)", text: $customDelay)
                    .onSubmit { saveDelay() }
                Button("Simpan") { saveDelay() }
            }
            if let error = preferences.delayError { Text(error.localized(in: locale)).foregroundStyle(.secondary).font(.callout) }
            Text("Berlaku untuk waktu sholat berikutnya. Jeda yang sudah dimulai dan snooze tetap mengikuti jadwalnya.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { customDelay = String(preferences.delayMinutes) }
        Section("Suara") {
            Toggle("Suara pendek saat pengingat muncul", isOn: $preferences.soundEnabled)
            Picker("Pilihan suara", selection: $preferences.soundPreset) {
                ForEach(ReminderSound.allCases, id: \.self) { preset in
                    Text(verbatim: preset.rawValue).tag(preset)
                }
            }
            Button("Coba suara") { preferences.playSound(audition: true) }
            if let error = preferences.soundError { Text(error.localized(in: locale)).font(.callout).foregroundStyle(.secondary) }
            Text("Default mati. Coba suara tetap berbunyi saat suara otomatis mati. Mengikuti volume dan keluaran audio Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Saat login") {
            #if DEBUG
            Text("Nida Dev tidak dijalankan saat login. Gunakan Nida di Applications untuk pengingat harian.")
                .font(.caption).foregroundStyle(.secondary)
            #else
            Toggle("Buka Nida saat login", isOn: Binding(get: { login.isRegistered }, set: { enabled in
                Task { await login.setEnabled(enabled) }
            }))
            .disabled(login.isUpdating)
            LabeledContent("Status", value: login.statusText.localized(in: locale))
            if login.isUpdating { ProgressView().controlSize(.small) }
            if let error = login.error { Text(error.localized(in: locale)).font(.callout).foregroundStyle(.secondary) }
            if login.status == .requiresApproval {
                Button("Buka Pengaturan Sistem") { SMAppService.openSystemSettingsLoginItems() }
            }
            Text("Pengingat hanya berjalan saat Nida terbuka dan Mac terjaga. Simpan app di lokasi tetap sebelum mengaktifkan login otomatis.")
                .font(.caption).foregroundStyle(.secondary)
            #endif
        }
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }

    private func displayDurationSlider(_ title: LocalizedStringKey, state: PreviewState) -> some View {
        let seconds = controller.preferences.displaySeconds(for: state) ?? 10
        return VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(seconds)) detik").monospacedDigit()
            }
            Slider(value: Binding(
                get: { controller.preferences.displaySeconds(for: state) ?? 10 },
                set: { controller.preferences.setDisplaySeconds($0, for: state) }
            ), in: 5...60, step: 5) {
                EmptyView()
            } minimumValueLabel: {
                Text("5 detik")
            } maximumValueLabel: {
                Text("60 detik")
            }
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text("\(Int(seconds)) detik"))
        }
    }

    private func saveDelay() { _ = controller.preferences.setDelay(customDelay) }
}
