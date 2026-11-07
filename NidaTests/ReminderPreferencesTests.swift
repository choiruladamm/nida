import AppKit
import Foundation
import ServiceManagement
import Testing
import Observation
import os
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

    @Test func displayDurationsValidatePersistAndSelectTheCorrectStage() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ReminderPreferences(defaults: defaults)
        #expect(preferences.displaySeconds(for: .prayer) == 10)
        #expect(preferences.displaySeconds(for: .followUp) == 20)
        #expect(preferences.displaySeconds(for: .schedule) == nil)
        #expect(preferences.displaySeconds(for: .collapsed) == nil)
        for seconds in stride(from: 5.0, through: 60, by: 5) {
            preferences.setDisplaySeconds(seconds, for: .prayer)
            preferences.setDisplaySeconds(65 - seconds, for: .followUp)
            let restored = ReminderPreferences(defaults: defaults)
            #expect(restored.entryDisplaySeconds == seconds)
            #expect(restored.followUpDisplaySeconds == 65 - seconds)
        }
        for seconds in [0, 4, 7, 61, 10.5, Double.infinity, Double.nan] {
            preferences.setDisplaySeconds(seconds, for: .prayer)
            #expect(preferences.entryDisplaySeconds == 60)
        }
        for key in ["entryDisplaySeconds", "followUpDisplaySeconds"] {
            for value: Any in [0, 61, 7, 5.5, true, "5"] {
                defaults.set(value, forKey: key)
                let restored = ReminderPreferences(defaults: defaults)
                #expect(restored.displaySeconds(for: key == "entryDisplaySeconds" ? .prayer : .followUp)
                    == (key == "entryDisplaySeconds" ? 10 : 20))
            }
        }
    }

    @Test func systemSoundsAreAvailableWithoutPlayingThem() {
        for preset in ReminderSound.allCases {
            #expect(NSSound(named: NSSound.Name(preset.rawValue)) != nil)
        }
    }

    @Test func soundSelectionPersistsAndInvalidValuesRecoverWithoutWrites() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ReminderPreferences(defaults: defaults).soundPreset == .glass)
        #expect(defaults.object(forKey: "reminderSoundPreset") == nil)
        for invalid: Any in ["unknown", true, 42, ["Ping"]] {
            defaults.set(invalid, forKey: "reminderSoundPreset")
            let before = defaults.dictionaryRepresentation() as NSDictionary
            #expect(ReminderPreferences(defaults: defaults).soundPreset == .glass)
            #expect(defaults.dictionaryRepresentation() as NSDictionary == before)
        }
        let preferences = ReminderPreferences(defaults: defaults)
        preferences.soundEnabled = true
        for preset in ReminderSound.allCases {
            let before = defaults.dictionaryRepresentation().filter { $0.key != "reminderSoundPreset" } as NSDictionary
            preferences.soundPreset = preset
            let restored = ReminderPreferences(defaults: defaults)
            #expect(restored.soundPreset == preset)
            #expect(restored.soundEnabled)
            #expect(defaults.dictionaryRepresentation().filter { $0.key != "reminderSoundPreset" } as NSDictionary == before)
        }
    }

    @Test func soundGatingAuditionReplacementAndFailureRecovery() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let sound = TestSound()
        var requested: [ReminderSound] = []
        var available = true
        let preferences = ReminderPreferences(defaults: defaults) { preset in
            requested.append(preset)
            return available ? sound : nil
        }
        preferences.playSound()
        preferences.soundPreset = .tink
        #expect(requested.isEmpty)
        preferences.playSound(audition: true)
        #expect(requested == [.tink])
        #expect(!preferences.soundEnabled)
        #expect(sound.plays == 1)
        preferences.playSound(audition: true)
        #expect(sound.plays == 2)
        #expect(sound.stops == 1)
        #expect(preferences.soundError == nil)
        preferences.soundPreset = .ping
        #expect(sound.plays == 2)
        preferences.soundEnabled = true
        preferences.playSound()
        #expect(requested.last == .ping)
        #expect(sound.stops == 2)
        preferences.soundEnabled = false
        #expect(sound.stops == 3)
        preferences.playSound()
        #expect(sound.plays == 3)
        available = false
        preferences.playSound(audition: true)
        #expect(preferences.soundError != nil)
        #expect(preferences.soundPreset == .ping)
        available = true
        sound.starts = false
        preferences.playSound(audition: true)
        #expect(preferences.soundError != nil)
        sound.starts = true
        preferences.playSound(audition: true)
        #expect(preferences.soundError == nil)
        #expect(!preferences.soundEnabled)
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

    @Test func installedRegistrationRepairRefreshesEnabledServiceAndStopsOnFailure() async {
        var status = SMAppService.Status.enabled
        var updates: [Bool] = []
        let login = LoginLaunch(readStatus: { status }, update: { enabled in
            updates.append(enabled)
            status = enabled ? .enabled : .notRegistered
        })
        await login.restoreEnabledRegistration()
        #expect(updates == [false, true])
        #expect(login.statusName == "enabled")
        var attempts = 0
        let failed = LoginLaunch(readStatus: { .enabled }, update: { _ in
            attempts += 1
            throw CocoaError(.fileWriteNoPermission)
        })
        await failed.restoreEnabledRegistration()
        #expect(attempts == 1)
        #expect(failed.error != nil)
    }

    @Test func approvalIsNotReportedAsActive() async {
        var status = SMAppService.Status.notRegistered
        let login = LoginLaunch(readStatus: { status }, update: { _ in status = .requiresApproval })
        await login.setEnabled(true)
        #expect(login.status == .requiresApproval)
        #expect(login.isRegistered)
        #expect(login.statusText.localized(in: AppLanguage.indonesian.locale).contains("Menunggu"))
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
        #expect(login.statusText.localized(in: AppLanguage.indonesian.locale).contains("belum tersedia"))
    }
}

@MainActor @Suite struct AppLanguageTests {
    @Test func defaultsFallbackPersistenceAndOtherPreferencesArePreserved() throws {
        let suite = "nida-language-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for value: Any in ["", "fr", 7, true] {
            defaults.set(value, forKey: "appLanguage")
            #expect(ReminderPreferences(defaults: defaults).language == .indonesian)
        }
        defaults.removeObject(forKey: "appLanguage")
        let preferences = ReminderPreferences(defaults: defaults)
        #expect(preferences.language == .indonesian)
        #expect(preferences.setDelay("5"))
        preferences.soundEnabled = true
        let saved = defaults.dictionaryRepresentation().filter { $0.key != "appLanguage" }
        preferences.language = .english
        #expect(ReminderPreferences(defaults: defaults).language == .english)
        #expect(defaults.dictionaryRepresentation().filter { $0.key != "appLanguage" } as NSDictionary == saved as NSDictionary)
    }

    @Test func retainedMessagesResolveAgainWithoutRecreatingTheirSource() throws {
        let suite = "nida-language-message-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ReminderPreferences(defaults: defaults)
        #expect(!preferences.setDelay("0"))
        let message = try #require(preferences.delayError)
        #expect(message.localized(in: preferences.language.locale) == "Masukkan bilangan bulat antara 1 dan 60 menit.")
        let invalidated = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            _ = message.localized(in: preferences.language.locale)
        } onChange: { invalidated.withLock { $0 = true } }
        preferences.language = .english
        #expect(invalidated.withLock { $0 })
        #expect(message.localized(in: preferences.language.locale) == "Enter a whole number from 1 to 60 minutes.")
        #expect(PrayerDataError.network.message.localized(in: preferences.language.locale)
            == "Cannot reach the schedule service. Check your internet connection.")
        #expect(LocationSetupError.denied.message.localized(in: preferences.language.locale).hasPrefix("Location access is denied."))
    }

    @Test func prayerNamesAndPluralsUseTheSelectedLocale() {
        let english = AppLanguage.english.locale
        #expect(PrayerKind.allCases.map { $0.label.localized(in: english) } == ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"])
        #expect(PrayerKind.allCases.map { $0.label.localized(in: AppLanguage.indonesian.locale) } == ["Subuh", "Dzuhur", "Ashar", "Maghrib", "Isya"])
        for count in [1, 5] {
            let minutes: LocalizedStringResource = "\(count) menit"
            let days: LocalizedStringResource = "\(count) hari tersimpan untuk offline."
            let followUp: LocalizedStringResource = "\(count) menit sejak masuk waktu \(PrayerKind.ashar.label.localized(in: english))"
            #expect(minutes.localized(in: english) == (count == 1 ? "1 minute" : "5 minutes"))
            #expect(days.localized(in: english) == (count == 1 ? "1 day saved for offline use." : "5 days saved for offline use."))
            #expect(followUp.localized(in: english) == (count == 1 ? "1 minute since Asr began" : "5 minutes since Asr began"))
            #expect(minutes.localized(in: AppLanguage.indonesian.locale) == "\(count) menit")
        }
    }

    @Test func bothLanguagesShipTheSameCatalogKeys() throws {
        let resources = try #require(Bundle.main.resourceURL)
        for table in ["Localizable", "InfoPlist"] {
            var languageKeys: [Set<String>] = []
            for language in AppLanguage.allCases {
                var keys: Set<String> = []
                for ext in ["strings", "stringsdict"] {
                    let file = resources.appending(path: "\(language.rawValue).lproj/\(table).\(ext)")
                    guard FileManager.default.fileExists(atPath: file.path) else { continue }
                    let data = try Data(contentsOf: file)
                    let entries = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
                    keys.formUnion(entries.keys)
                }
                #expect(!keys.isEmpty, "Missing \(language) \(table)")
                languageKeys.append(keys)
            }
            #expect(languageKeys[0] == languageKeys[1], "Language coverage differs in \(table)")
        }
    }
}

// Avoid emitting audio while exercising the actual playback ownership path.
@MainActor private final class TestSound: ReminderSoundPlayback {
    var plays = 0
    var stops = 0
    var starts = true
    func play() -> Bool { plays += 1; return starts }
    func stop() -> Bool { stops += 1; return true }
}
