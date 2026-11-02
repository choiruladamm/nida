import AppKit
import CoreFoundation
import ServiceManagement
import SwiftUI
import Observation

@MainActor @Observable
final class ReminderPreferences {
    private let defaults: UserDefaults
    private(set) var delayMinutes: Int
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: "reminderSoundEnabled") }
    }
    private(set) var delayError: String?
    private(set) var soundError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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

    func playSound(using play: () -> Bool = { NSSound(named: NSSound.Name("Glass"))?.play() ?? false }) {
        guard soundEnabled else { return }
        soundError = play() ? nil : "Suara pengingat belum bisa diputar. Coba lagi atau matikan suara."
    }
}

@MainActor @Observable
final class LoginLaunch {
    private(set) var status: SMAppService.Status
    private(set) var isUpdating = false
    private(set) var error: String?
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

    var statusText: String {
        switch status {
        case .enabled: "Aktif"
        case .notRegistered: "Nonaktif"
        case .requiresApproval: "Menunggu persetujuan di Pengaturan Sistem"
        case .notFound: "App belum tersedia untuk login otomatis"
        @unknown default: "Status belum dikenali"
        }
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
    @State private var customDelay = ""
    @State private var login = LoginLaunch()

    var body: some View {
        @Bindable var preferences = controller.preferences
        Section("Pengingat kedua") {
            LabeledContent("Jeda aktif", value: "\(preferences.delayMinutes) menit")
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
            if let error = preferences.delayError { Text(error).foregroundStyle(.secondary).font(.callout) }
            Text("Berlaku untuk waktu sholat berikutnya. Jeda yang sudah dimulai dan snooze tetap mengikuti jadwalnya.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { customDelay = String(preferences.delayMinutes) }
        Section("Suara") {
            Toggle("Suara pendek saat pengingat muncul", isOn: $preferences.soundEnabled)
            Button("Coba suara") { preferences.playSound() }.disabled(!preferences.soundEnabled)
            if let error = preferences.soundError { Text(error).font(.callout).foregroundStyle(.secondary) }
            Text("Suara sistem Glass · Default mati. Mengikuti volume dan keluaran audio Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("Saat login") {
            Toggle("Buka Nida saat login", isOn: Binding(get: { login.isRegistered }, set: { enabled in
                Task { await login.setEnabled(enabled) }
            }))
            .disabled(login.isUpdating)
            LabeledContent("Status", value: login.statusText)
            if login.isUpdating { ProgressView().controlSize(.small) }
            if let error = login.error { Text(error).font(.callout).foregroundStyle(.secondary) }
            if login.status == .requiresApproval {
                Button("Buka Pengaturan Sistem") { SMAppService.openSystemSettingsLoginItems() }
            }
            Text("Pengingat hanya berjalan saat Nida terbuka dan Mac terjaga. Simpan app di lokasi tetap sebelum mengaktifkan login otomatis.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }

    private func saveDelay() { _ = controller.preferences.setDelay(customDelay) }
}
