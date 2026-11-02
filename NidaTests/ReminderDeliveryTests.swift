import CoreGraphics
import Foundation
import Testing
@testable import Nida

private func deliveryDate(_ clock: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: "2026-11-02T" + clock + "+07:00"))
}

private func deliveryTimeline(cityID: String = String(repeating: "a", count: 32)) throws -> PrayerTimeline {
    let location = PrayerLocation(city: PrayerCity(id: cityID, name: "KOTA JAKARTA"), province: "DKI JAKARTA", zone: .west)
    let period = ScheduleMonth(year: 2026, month: 11)
    let day = PrayerDay(subuh: "04:10", dzuhur: "11:40", ashar: "15:00", maghrib: "18:00", isya: "19:00")
    return try PrayerTimeline(location: location, months: [PrayerMonth(provider: PrayerMonth.providerID,
        location: location, period: period, retrievedAt: try deliveryDate("00:00:00"),
        days: Dictionary(uniqueKeysWithValues: try period.dateKeys().map { ($0, day) }))])
}

@Suite struct ReminderDeliveryTests {
    @Test func entryDismissalPreservesFollowUpAndDeliveryIsDeduplicated() throws {
        let timeline = try deliveryTimeline()
        var ledger = ReminderLedger()
        let entryTime = try deliveryDate("11:40:00")
        ledger.reconcile(timeline, at: entryTime, delay: .standard)
        let result1 = ledger.takeDue(at: entryTime, available: true)
        let entry = try #require(result1)
        #expect(entry.id.stage == .entry)
        ledger.dismiss(entry)
        ledger.reconcile(timeline, at: entryTime, delay: .standard)
        let result2 = ledger.takeDue(at: entryTime, available: true)
        #expect(result2 == nil)
        let result3 = try ledger.takeDue(at: deliveryDate("11:50:00"), available: true)
        let followUp = try #require(result3)
        #expect(followUp.id.stage == .followUp)
        ledger.dismiss(followUp)
        ledger.reconcile(timeline, at: try deliveryDate("11:51:00"), delay: .standard)
        #expect(!ledger.pending.contains { $0.id.occurrence == followUp.id.occurrence })
    }

    @Test func explicitSnoozeFiresOnceAndSurvivesReconciliation() throws {
        let timeline = try deliveryTimeline()
        var ledger = ReminderLedger()
        ledger.reconcile(timeline, at: try deliveryDate("11:50:00"), delay: .standard)
        let result4 = try ledger.takeDue(at: deliveryDate("11:50:00"), available: true)
        let followUp = try #require(result4)
        let requested = try deliveryDate("11:50:20")
        let result5 = ledger.snooze(followUp, timeline: timeline, at: requested)
        #expect(result5)
        ledger.reconcile(timeline, at: requested, delay: try FollowUpDelay(minutes: 5))
        let result6 = ledger.takeDue(at: requested.addingTimeInterval(299), available: true)
        #expect(result6 == nil)
        let result7 = ledger.takeDue(at: requested.addingTimeInterval(300), available: true)
        let snooze = try #require(result7)
        #expect(snooze.id.stage == .snooze(requestedAt: requested))
        let result8 = ledger.takeDue(at: requested.addingTimeInterval(300), available: true)
        #expect(result8 == nil)
        ledger.dismiss(snooze)
        let result9 = ledger.snooze(snooze, timeline: timeline, at: requested.addingTimeInterval(301))
        #expect(!result9)
    }

    @Test func snoozeCannotCrossNextPrayer() throws {
        let timeline = try deliveryTimeline()
        var ledger = ReminderLedger()
        ledger.reconcile(timeline, at: try deliveryDate("11:50:00"), delay: .standard)
        let result10 = try ledger.takeDue(at: deliveryDate("11:50:00"), available: true)
        let event = try #require(result10)
        let result11 = try ledger.snooze(event, timeline: timeline, at: try deliveryDate("14:55:00"))
        #expect(!result11)
    }

    @Test func recoveryChoosesLatestOnlyAndLockDoesNotConsumeIt() throws {
        let timeline = try deliveryTimeline()
        var ledger = ReminderLedger()
        let now = try deliveryDate("11:45:00")
        ledger.reconcile(timeline, at: now, delay: try FollowUpDelay(minutes: 5))
        let result12 = ledger.takeDue(at: now, available: false)
        #expect(result12 == nil)
        #expect(ledger.handled.isEmpty)
        let result13 = ledger.takeDue(at: now, available: true)
        let event = try #require(result13)
        #expect(event.id.stage == .followUp)
        let result14 = ledger.takeDue(at: now, available: true)
        #expect(result14 == nil)
        let result15 = try ledger.takeDue(at: deliveryDate("11:40:00"), available: true)
        #expect(result15 == nil)
    }

    @Test func staleRecoveryDoesNotReplay() throws {
        let timeline = try deliveryTimeline()
        var ledger = ReminderLedger()
        let now = try deliveryDate("12:00:00")
        ledger.reconcile(timeline, at: now, delay: .standard)
        let result16 = ledger.takeDue(at: now, available: true)
        #expect(result16 == nil)
        let result17 = try ledger.takeDue(at: deliveryDate("11:50:00"), available: true)
        #expect(result17 == nil)
    }

    @Test func cityChangeDropsOldSnoozesAndUsesNewCity() throws {
        let first = try deliveryTimeline()
        let second = try deliveryTimeline(cityID: String(repeating: "b", count: 32))
        var ledger = ReminderLedger()
        let now = try deliveryDate("11:50:00")
        ledger.reconcile(first, at: now, delay: .standard)
        let result18 = ledger.takeDue(at: now, available: true)
        let event = try #require(result18)
        let result19 = ledger.snooze(event, timeline: first, at: now)
        #expect(result19)
        ledger.reconcile(second, at: now, delay: .standard)
        #expect(ledger.pending.allSatisfy { $0.id.occurrence.cityID == second.location.city.id })
        #expect(ledger.pending.allSatisfy { if case .snooze = $0.id.stage { return false }; return true })
    }

    @Test func relaunchRetainsHandledAndExplicitPendingSnooze() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ReminderLedgerFile(url: directory.appending(path: "ledger.json"))
        let timeline = try deliveryTimeline()
        var ledger = try file.load()
        let now = try deliveryDate("11:50:00")
        ledger.reconcile(timeline, at: now, delay: .standard)
        let result20 = ledger.takeDue(at: now, available: true)
        let event = try #require(result20)
        let result21 = ledger.snooze(event, timeline: timeline, at: now)
        #expect(result21)
        try file.save(ledger)
        var restored = try file.load()
        #expect(restored == ledger)
        restored.reconcile(timeline, at: now, delay: .standard)
        let result22 = restored.takeDue(at: now, available: true)
        #expect(result22 == nil)
        let result23 = restored.takeDue(at: now.addingTimeInterval(300), available: true)
        #expect(try #require(result23).id.stage == .snooze(requestedAt: now))
    }

    @Test func delayChangesPreserveStartedFollowUpButUpdateFuturePrayers() throws {
        let timeline = try deliveryTimeline()
        var ledger = ReminderLedger()
        ledger.reconcile(timeline, at: try deliveryDate("11:30:00"), delay: .standard)
        ledger.reconcile(timeline, at: try deliveryDate("11:41:00"), delay: try FollowUpDelay(minutes: 5))
        let dhuhr = try #require(ledger.pending.first { $0.id.occurrence.prayer == .dzuhur && $0.id.stage == .followUp })
        let ashar = try #require(ledger.pending.first { $0.id.occurrence.prayer == .ashar && $0.id.stage == .followUp })
        #expect(dhuhr.firesAt == (try deliveryDate("11:50:00")))
        #expect(ashar.firesAt == (try deliveryDate("15:05:00")))
    }

    @MainActor @Test func unavailableSessionAndLockBlockPresentation() {
        let console = kCGSessionOnConsoleKey as String
        #expect(!ReminderDelivery.sessionAllowsDelivery(nil, suspended: false))
        #expect(!ReminderDelivery.sessionAllowsDelivery([console: false], suspended: false))
        #expect(!ReminderDelivery.sessionAllowsDelivery([console: true], suspended: true))
        #expect(!ReminderDelivery.sessionAllowsDelivery([console: true, "CGSSessionScreenIsLocked": true], suspended: false))
        #expect(ReminderDelivery.sessionAllowsDelivery([console: true, "CGSSessionScreenIsLocked": false], suspended: false))
    }

    @Test func corruptLedgerAndWriteFailureAreVisible() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "ledger.json")
        let marker = Data("broken".utf8)
        try marker.write(to: url)
        #expect(throws: (any Error).self) { try ReminderLedgerFile(url: url).load() }
        #expect(throws: (any Error).self) { try ReminderLedgerFile(url: url.appending(path: "blocked")).save(ReminderLedger()) }
        #expect(try Data(contentsOf: url) == marker)
    }
}
