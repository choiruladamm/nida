import Foundation
import Testing
@testable import Nida

private let timelineCity = PrayerCity(id: "58a2fc6ed39fd083f55d4182bf88826d", name: "KOTA JAKARTA")
private let timelineDay = PrayerDay(subuh: "04:09", dzuhur: "11:40", ashar: "14:55", maghrib: "17:49", isya: "19:00")
private let timelineNovember = ScheduleMonth(year: 2026, month: 11)

private func instant(_ value: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: value))
}

private func timeline(zone: IndonesianZone = .west, periods: [ScheduleMonth] = [timelineNovember],
                      day: PrayerDay = timelineDay) throws -> PrayerTimeline {
    let province: String
    switch zone { case .west: province = "DKI JAKARTA"; case .central: province = "BALI"; case .east: province = "PAPUA" }
    let location = PrayerLocation(city: timelineCity, province: province, zone: zone)
    let months = try periods.map { period in
        PrayerMonth(provider: PrayerMonth.providerID, location: location, period: period,
                    retrievedAt: Date(timeIntervalSince1970: 0),
                    days: Dictionary(uniqueKeysWithValues: try period.dateKeys().map { ($0, day) }))
    }
    return try PrayerTimeline(location: location, months: months)
}

private func occurrence(_ prayer: PrayerKind = .ashar, date: String = "2026-11-15",
                        in timeline: PrayerTimeline) throws -> PrayerOccurrence {
    let now = try instant(date + "T00:00:00+07:00")
    return try #require(timeline.snapshot(at: now).today.first { $0.id.prayer == prayer })
}

@Suite(.serialized) struct PrayerBoundaryTests {
    @Test(arguments: PrayerKind.allCases, [-1.0, 0.0, 1.0])
    func nextAndElapsedAtEveryPrayerBoundary(prayer: PrayerKind, offset: Double) throws {
        let timeline = try timeline()
        let current = try occurrence(prayer, in: timeline)
        let now = current.startsAt.addingTimeInterval(offset)
        let snapshot = timeline.snapshot(at: now)
        let index = try #require(PrayerKind.allCases.firstIndex(of: prayer))
        let expected = offset < 0 ? prayer : PrayerKind.allCases[(index + 1) % 5]
        #expect(snapshot.next?.id.prayer == expected)
        #expect(snapshot.today.filter { $0.hasStarted(at: now) }.count == index + (offset >= 0 ? 1 : 0))
        #expect(try #require(snapshot.remaining) > 0)
        if offset < 0 { #expect(snapshot.remaining == 1) }
        if prayer == .isya, offset >= 0 { #expect(snapshot.next?.id.dateKey == "2026-11-16") }
    }

    @Test(arguments: [IndonesianZone.west, .central, .east])
    func cityClockProducesExpectedAbsoluteInstants(zone: IndonesianZone) throws {
        let timeline = try timeline(zone: zone)
        let noon = try instant("2026-11-15T00:00:00Z")
        let prayer = try #require(timeline.snapshot(at: noon).today.first { $0.id.prayer == .ashar })
        let expected: String
        switch zone {
        case .west: expected = "2026-11-15T07:55:00Z"
        case .central: expected = "2026-11-15T06:55:00Z"
        case .east: expected = "2026-11-15T05:55:00Z"
        }
        #expect(prayer.startsAt == (try instant(expected)))
    }

    @Test func deviceDefaultZoneDoesNotReinterpretCityTimes() throws {
        let previous = NSTimeZone.default
        defer { NSTimeZone.default = previous }
        let now = try instant("2026-11-15T07:00:00Z")
        for identifier in ["UTC", "America/Los_Angeles", "Asia/Tokyo"] {
            NSTimeZone.default = try #require(TimeZone(identifier: identifier))
            let timeline = try timeline()
            let snapshot = timeline.snapshot(at: now)
            #expect(snapshot.next?.startsAt == (try instant("2026-11-15T07:55:00Z")))
            #expect(snapshot.remaining == 3300)
        }
    }

    @Test(arguments: [
        (ScheduleMonth(year: 2026, month: 11), "2026-11-30", "2026-12-01"),
        (ScheduleMonth(year: 2026, month: 12), "2026-12-31", "2027-01-01"),
        (ScheduleMonth(year: 2024, month: 2), "2024-02-29", "2024-03-01")
    ])
    func afterIshaAndMidnightCrossCalendarBoundaries(sample: (ScheduleMonth, String, String)) throws {
        let timeline = try timeline(periods: [sample.0, sample.0.next])
        let afterIsha = try instant(sample.1 + "T19:01:00+07:00")
        #expect(timeline.snapshot(at: afterIsha).next?.id.dateKey == sample.2)
        #expect(timeline.snapshot(at: afterIsha).next?.id.prayer == .subuh)
        let midnight = try instant(sample.2 + "T00:00:00+07:00")
        #expect(timeline.snapshot(at: midnight).today.allSatisfy { $0.id.dateKey == sample.2 })
        #expect(timeline.snapshot(at: midnight).remaining == 14_940.0)
    }

    @Test func missingTomorrowAndMissingTodayRemainUnavailable() throws {
        let timeline = try timeline()
        let afterIsha = try instant("2026-11-30T19:00:00+07:00")
        #expect(timeline.snapshot(at: afterIsha).hasToday)
        #expect(timeline.snapshot(at: afterIsha).next == nil)
        #expect(timeline.snapshot(at: afterIsha).remaining == nil)
        let missing = try instant("2026-12-01T00:00:00+07:00")
        #expect(!timeline.snapshot(at: missing).hasToday)
        #expect(timeline.snapshot(at: missing).next == nil)
    }

    @Test func boundaryScheduleIncludesMidnightAndEndsAtMissingCoverage() throws {
        let timeline = try timeline()
        let dates = timeline.boundaryDates
        #expect(dates == Array(Set(dates)).sorted())
        #expect(dates.contains(try instant("2026-11-15T00:00:00+07:00")))
        #expect(dates.contains(try instant("2026-11-15T14:55:00+07:00")))
        #expect(dates.last == (try instant("2026-12-01T00:00:00+07:00")))
        #expect(!timeline.snapshot(at: try #require(dates.last)).hasToday)
    }
}

@Suite struct ReminderCalculationTests {
    @Test(arguments: [-1, 0, 61, Int.max]) func rejectsInvalidFollowUpDelay(minutes: Int) {
        #expect(throws: PrayerDataError.invalidData) { try FollowUpDelay(minutes: minutes) }
    }

    @Test func presetsAndAbsoluteEventTimes() throws {
        #expect(FollowUpDelay.standard.minutes == 10)
        #expect(FollowUpDelay.presets.map(\.minutes) == [5, 10])
        let timeline = try timeline()
        let now = try instant("2026-11-15T00:00:00+07:00")
        let prayer = try occurrence(in: timeline)
        let events = timeline.events(at: now)
        let entry = try #require(events.first { $0.id.occurrence == prayer.id && $0.id.stage == .entry })
        let followUp = try #require(events.first { $0.id.occurrence == prayer.id && $0.id.stage == .followUp })
        #expect(entry.firesAt == (try instant("2026-11-15T14:55:00+07:00")))
        #expect(followUp.firesAt == (try instant("2026-11-15T15:05:00+07:00")))
        #expect(followUp.expiresAt == (try instant("2026-11-15T17:49:00+07:00")))
    }

    @Test func delayChangesFreezeStartedOccurrencesAndUpdateFutureOnes() throws {
        let timeline = try timeline()
        let before = try instant("2026-11-15T14:54:00+07:00")
        let after = try instant("2026-11-15T14:56:00+07:00")
        let original = timeline.events(at: before)
        let revised = timeline.events(at: after, delay: try FollowUpDelay(minutes: 5), pending: original)
        for prayer in [PrayerKind.ashar, .maghrib] {
            let id = try occurrence(prayer, in: timeline).id
            let old = try #require(original.first { $0.id.occurrence == id && $0.id.stage == .followUp })
            let new = try #require(revised.first { $0.id == old.id })
            #expect(new.firesAt == old.firesAt.addingTimeInterval(prayer == .ashar ? 0 : -300))
        }
    }

    @Test func snoozeSurvivesDelayChangesAndOnlyLatestRequestRemainsPending() throws {
        let timeline = try timeline()
        let prayer = try occurrence(in: timeline)
        let first = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T15:06:00+07:00")))
        let latest = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T15:07:00+07:00")))
        #expect(first.id != latest.id)
        let plan = timeline.events(at: try instant("2026-11-15T15:08:00+07:00"),
                                   delay: try FollowUpDelay(minutes: 60), pending: [first, latest])
        let snoozes = plan.filter { if case .snooze = $0.id.stage { true } else { false } }
        #expect(snoozes == [latest])
        let restored = try JSONDecoder().decode(PrayerEvent.self, from: JSONEncoder().encode(latest))
        #expect(restored == latest)
    }

    @Test func snoozeExpiresAtNextPrayerIncludingExactBoundary() throws {
        let timeline = try timeline()
        let prayer = try occurrence(in: timeline)
        #expect(timeline.snooze(for: prayer.id, requestedAt: try instant("2026-11-15T17:44:00+07:00")) == nil)
        let valid = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T17:43:59+07:00")))
        let events = timeline.events(at: try instant("2026-11-15T17:49:00+07:00"), pending: [valid])
        #expect(!events.contains { $0.id.occurrence == prayer.id })
    }

    @Test func olderFollowUpCannotCollideWithNewPrayerEntry() throws {
        let narrow = PrayerDay(subuh: "04:09", dzuhur: "11:40", ashar: "11:50", maghrib: "17:49", isya: "19:00")
        let timeline = try timeline(day: narrow)
        let now = try instant("2026-11-15T11:50:00+07:00")
        let events = timeline.events(at: now)
        #expect(!events.contains { $0.id.occurrence.dateKey == "2026-11-15" && $0.id.occurrence.prayer == .dzuhur })
        let selected = try #require(PrayerTimeline.dueEvent(in: events, at: now))
        #expect(selected.id.occurrence.prayer == .ashar)
        #expect(selected.id.stage == .entry)
    }

    @Test func latestHandledEventDoesNotResurrectAnEarlierReminder() throws {
        let timeline = try timeline()
        let now = try instant("2026-11-15T14:57:00+07:00")
        let events = timeline.events(at: now, delay: try FollowUpDelay(minutes: 1))
        let latest = try #require(PrayerTimeline.dueEvent(in: events, at: now))
        #expect(latest.id.stage == .followUp)
        #expect(PrayerTimeline.dueEvent(in: events, at: now, excluding: [latest.id]) == nil)
    }

    @Test func explicitSnoozeWinsSameInstantTie() throws {
        let timeline = try timeline()
        let prayer = try occurrence(in: timeline)
        let snooze = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T15:00:00+07:00")))
        let now = try instant("2026-11-15T15:05:00+07:00")
        let events = timeline.events(at: now, pending: [snooze])
        #expect(PrayerTimeline.dueEvent(in: events, at: now)?.id == snooze.id)
    }

    @Test func missedEventGraceIsInclusiveAndBounded() throws {
        let timeline = try timeline()
        let prayer = try occurrence(.subuh, in: timeline)
        let atLimit = prayer.startsAt.addingTimeInterval(300)
        let beyond = atLimit.addingTimeInterval(0.001)
        #expect(PrayerTimeline.dueEvent(in: timeline.events(at: atLimit), at: atLimit)?.id.stage == .entry)
        #expect(PrayerTimeline.dueEvent(in: timeline.events(at: beyond), at: beyond) == nil)
    }

    @Test func missingTomorrowExpiresIshaAtMidnightAndKnownTomorrowAllowsCrossMidnightSnooze() throws {
        let limited = try timeline()
        let complete = try timeline(periods: [timelineNovember, timelineNovember.next])
        let id = try occurrence(.isya, date: "2026-11-30", in: limited).id
        let requested = try instant("2026-11-30T23:56:00+07:00")
        #expect(limited.snooze(for: id, requestedAt: requested) == nil)
        let snooze = try #require(complete.snooze(for: id, requestedAt: requested))
        let midnight = try instant("2026-12-01T00:00:00+07:00")
        #expect(complete.events(at: midnight, pending: [snooze]).contains(snooze))
        #expect(!limited.events(at: midnight, pending: [snooze]).contains { $0.id.occurrence == id })
    }

    @Test func handlingHistoryPreservesPendingStateAfterClockMovesBackward() throws {
        let timeline = try timeline()
        let prayer = try occurrence(in: timeline)
        let before = try instant("2026-11-15T14:54:00+07:00")
        let plan = timeline.events(at: before)
        let entry = try #require(plan.first { $0.id.occurrence == prayer.id && $0.id.stage == .entry })
        let original = try #require(plan.first { $0.id.occurrence == prayer.id && $0.id.stage == .followUp })
        let snooze = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T15:06:00+07:00")))
        let rewound = timeline.events(at: before, delay: try FollowUpDelay(minutes: 5),
                                      pending: [original, snooze], handled: [entry.id])
        #expect(rewound.contains(original))
        #expect(rewound.contains(snooze))
        let now = try instant("2026-11-15T14:57:00+07:00")
        #expect(PrayerTimeline.dueEvent(in: timeline.events(at: now), at: now, excluding: [original.id]) == nil)
    }

    @Test func olderHandledSnoozeDoesNotSuppressANewExplicitRequest() throws {
        let timeline = try timeline()
        let prayer = try occurrence(in: timeline)
        let first = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T15:06:00+07:00")))
        let second = try #require(timeline.snooze(for: prayer.id, requestedAt: instant("2026-11-15T15:12:00+07:00")))
        let now = second.firesAt
        let events = timeline.events(at: now, pending: [second])
        #expect(PrayerTimeline.dueEvent(in: events, at: now, excluding: [first.id])?.id == second.id)
    }

    @Test func stableIDsIgnoreDelayAndInvalidPendingPayloadsCannotExtendExpiry() throws {
        let timeline = try timeline()
        let before = try instant("2026-11-15T14:54:00+07:00")
        let prayer = try occurrence(in: timeline)
        let old = try #require(timeline.events(at: before).first { $0.id.occurrence == prayer.id && $0.id.stage == .followUp })
        let changed = try #require(timeline.events(at: before, delay: FollowUpDelay(minutes: 5)).first { $0.id == old.id })
        #expect(changed.id == old.id)
        let malformed = PrayerEvent(id: old.id, prayerStartsAt: old.prayerStartsAt,
                                   firesAt: old.prayerStartsAt.addingTimeInterval(7200),
                                   expiresAt: old.expiresAt.addingTimeInterval(86_400))
        let after = try instant("2026-11-15T14:56:00+07:00")
        let revised = try #require(timeline.events(at: after, pending: [malformed]).first { $0.id == old.id })
        #expect(revised.firesAt == old.firesAt)
        #expect(revised.expiresAt == old.expiresAt)
    }
}
