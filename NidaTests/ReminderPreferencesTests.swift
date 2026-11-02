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
