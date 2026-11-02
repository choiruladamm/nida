import AppKit
import Foundation
import ServiceManagement
import Testing
@testable import Nida

@MainActor @Suite struct ReminderPreferencesTests {
    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let name = "nida-preferences-" + UUID().uuidString
        return (try #require(UserDefaults(suiteName: name)), name)
    }

    @Test func defaultsAreTenMinutesAndSilentAndValidChangesSurviveRelaunch() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ReminderPreferences(defaults: defaults)
        #expect(preferences.delayMinutes == 10)
        #expect(!preferences.soundEnabled)
        #expect(preferences.setDelay(" 5 "))
        preferences.soundEnabled = true
        let restored = ReminderPreferences(defaults: defaults)
        #expect(restored.delayMinutes == 5)
        #expect(restored.soundEnabled)
        #expect(preferences.setDelay("60"))
        #expect(ReminderPreferences(defaults: defaults).delayMinutes == 60)
    }

    @Test(arguments: ["", "0", "61", "-5", "1.5", "abc", "١٠", "9999999999999999999999999999"])
    func invalidInputPreservesPreviousPreference(input: String) throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ReminderPreferences(defaults: defaults)
        #expect(preferences.setDelay("5"))
        #expect(!preferences.setDelay(input))
        #expect(preferences.delayMinutes == 5)
        #expect(defaults.integer(forKey: "followUpDelayMinutes") == 5)
        #expect(preferences.delayError != nil)
        #expect(preferences.setDelay("10"))
        #expect(preferences.delayError == nil)
    }

    @Test func invalidStoredTypesAndRangesHaveVisibleRecovery() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        for value: Any in [0, 61, 5.5, true, "5"] {
            defaults.set(value, forKey: "followUpDelayMinutes")
            let preferences = ReminderPreferences(defaults: defaults)
            #expect(preferences.delayMinutes == 10)
            #expect(preferences.delayError != nil)
        }
    }

    @Test func systemSoundIsAvailableWithoutPlayingIt() {
        #expect(NSSound(named: NSSound.Name("Glass")) != nil)
    }

    @Test func soundOffNeverCallsPlaybackAndFailureIsVisible() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ReminderPreferences(defaults: defaults)
        var attempts = 0
        preferences.playSound { attempts += 1; return true }
        #expect(attempts == 0)
        preferences.soundEnabled = true
        preferences.playSound { attempts += 1; return false }
        #expect(attempts == 1)
        #expect(preferences.soundError != nil)
        preferences.playSound { attempts += 1; return true }
        #expect(attempts == 2)
        #expect(preferences.soundError == nil)
    }
}

@MainActor @Suite struct LoginLaunchTests {
    @Test func registrationAndUnregistrationReadActualStatus() async {
        var status = SMAppService.Status.notRegistered
        var updates: [Bool] = []
        let login = LoginLaunch(readStatus: { status }, update: { enabled in
            updates.append(enabled)
            status = enabled ? .enabled : .notRegistered
        })
        #expect(!login.isRegistered)
        await login.setEnabled(true)
        #expect(login.status == .enabled)
        #expect(login.isRegistered)
        await login.setEnabled(false)
        #expect(login.status == .notRegistered)
        #expect(updates == [true, false])
        #expect(!login.isUpdating)
    }

    @Test func approvalIsNotReportedAsActive() async {
        var status = SMAppService.Status.notRegistered
        let login = LoginLaunch(readStatus: { status }, update: { _ in status = .requiresApproval })
        await login.setEnabled(true)
        #expect(login.status == .requiresApproval)
        #expect(login.isRegistered)
        #expect(login.statusText.contains("Menunggu"))
        status = .enabled
        login.refresh()
        #expect(login.status == .enabled)
    }

    @Test func failureKeepsActualStatusAndShowsError() async {
        let login = LoginLaunch(readStatus: { .notRegistered }, update: { _ in throw CocoaError(.fileWriteNoPermission) })
        await login.setEnabled(true)
        #expect(login.status == .notRegistered)
        #expect(!login.isRegistered)
        #expect(login.error != nil)
        #expect(!login.isUpdating)
    }

    @Test func alreadyRegisteredIsNotRegisteredAgainAndExternalChangesRefresh() async {
        var status = SMAppService.Status.enabled
        var attempts = 0
        let login = LoginLaunch(readStatus: { status }, update: { _ in attempts += 1 })
        await login.setEnabled(true)
        #expect(attempts == 0)
        status = .notFound
        login.refresh()
        #expect(!login.isRegistered)
        #expect(login.statusText.contains("belum tersedia"))
    }
}
