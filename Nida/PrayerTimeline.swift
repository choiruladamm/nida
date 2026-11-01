import Foundation

struct FollowUpDelay: Equatable, Sendable {
    let minutes: Int
    static let standard = Self(validatedMinutes: 10)
    static let presets = [Self(validatedMinutes: 5), standard]

    init(minutes: Int) throws {
        guard (1...60).contains(minutes) else { throw PrayerDataError.invalidData }
        self.minutes = minutes
    }
    private init(validatedMinutes: Int) { minutes = validatedMinutes }
}

struct PrayerOccurrence: Equatable, Sendable, Identifiable {
    struct ID: Codable, Hashable, Sendable {
        let cityID: String
        let dateKey: String
        let prayer: PrayerKind
    }
    let id: ID
    let startsAt: Date
    let wallTime: String
    func hasStarted(at date: Date) -> Bool { startsAt <= date }
}

struct PrayerEvent: Codable, Equatable, Sendable, Identifiable {
    enum Stage: Codable, Hashable, Sendable {
        case entry, followUp
        case snooze(requestedAt: Date)
    }
    struct ID: Codable, Hashable, Sendable {
        let occurrence: PrayerOccurrence.ID
        let stage: Stage
    }
    let id: ID
    let prayerStartsAt: Date
    let firesAt: Date
    let expiresAt: Date
}

struct PrayerTimeline: Sendable {
    struct Snapshot: Sendable {
        let today: [PrayerOccurrence]
        let next: PrayerOccurrence?
        let remaining: TimeInterval?
        var hasToday: Bool { !today.isEmpty }
    }
    private struct Day: Sendable {
        let startsAt: Date
        let endsAt: Date
        let prayers: [PrayerOccurrence]
    }
    let location: PrayerLocation
    private let calendar: Calendar
    private let days: [String: Day]

    init(location: PrayerLocation, months: [PrayerMonth]) throws {
        try location.validate()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.zone.timeZone
        var days: [String: Day] = [:]
        for month in months {
            try month.validate(city: location.city, period: month.period)
            guard month.location == location else { throw PrayerDataError.invalidData }
            for (key, timetable) in month.days {
                guard days[key] == nil else { throw PrayerDataError.invalidData }
                let dateParts = key.split(separator: "-").compactMap { Int($0) }
                guard dateParts.count == 3,
                      let start = calendar.date(from: DateComponents(year: dateParts[0], month: dateParts[1], day: dateParts[2])),
                      let end = calendar.date(byAdding: .day, value: 1, to: start) else { throw PrayerDataError.invalidData }
                let prayers = try PrayerKind.allCases.map { prayer in
                    let time = timetable.time(for: prayer)
                    let parts = time.split(separator: ":").compactMap { Int($0) }
                    guard parts.count == 2,
                          let instant = calendar.date(from: DateComponents(year: dateParts[0], month: dateParts[1],
                              day: dateParts[2], hour: parts[0], minute: parts[1])),
                          ScheduleMonth.dateKey(instant, in: location.zone) == key,
                          calendar.component(.hour, from: instant) == parts[0],
                          calendar.component(.minute, from: instant) == parts[1] else { throw PrayerDataError.invalidData }
                    return PrayerOccurrence(id: .init(cityID: location.city.id, dateKey: key, prayer: prayer),
                                            startsAt: instant, wallTime: time)
                }
                days[key] = Day(startsAt: start, endsAt: end, prayers: prayers)
            }
        }
        self.location = location
        self.calendar = calendar
        self.days = days
    }

    var boundaryDates: [Date] {
        Array(Set(days.values.flatMap { [$0.startsAt, $0.endsAt] + $0.prayers.map(\.startsAt) })).sorted()
    }

    func snapshot(at now: Date) -> Snapshot {
        let key = ScheduleMonth.dateKey(now, in: location.zone)
        guard let day = days[key] else { return Snapshot(today: [], next: nil, remaining: nil) }
        let tomorrow = days[ScheduleMonth.dateKey(day.endsAt, in: location.zone)]
        let next = day.prayers.first { $0.startsAt > now } ?? tomorrow?.prayers.first
        return Snapshot(today: day.prayers, next: next, remaining: next.map { $0.startsAt.timeIntervalSince(now) })
    }

    func events(at now: Date, delay: FollowUpDelay = .standard, pending: [PrayerEvent] = [],
                handled: Set<PrayerEvent.ID> = []) -> [PrayerEvent] {
        // Handling history preserves started state even when the system clock moves backward.
        let started = Set(handled.map(\.occurrence))
        let start = calendar.startOfDay(for: now)
        let dates = [-1, 0, 1].compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        var result: [PrayerEvent] = []
        for date in dates {
            guard let day = days[ScheduleMonth.dateKey(date, in: location.zone)] else { continue }
            for prayer in day.prayers {
                let expiry = expiresAt(for: prayer, in: day)
                guard expiry > now else { continue }
                result.append(event(for: prayer, stage: .entry, at: prayer.startsAt, expiry: expiry))
                let preserved = pending.filter {
                    $0.id.occurrence == prayer.id && $0.prayerStartsAt == prayer.startsAt &&
                    $0.id.stage == .followUp && validFollowUp($0)
                }.min { $0.firesAt < $1.firesAt }
                let followUp = (prayer.hasStarted(at: now) || started.contains(prayer.id)) ? preserved?.firesAt : nil
                let fire = followUp ?? prayer.startsAt.addingTimeInterval(Double(delay.minutes * 60))
                if fire < expiry {
                    result.append(event(for: prayer, stage: .followUp, at: fire, expiry: expiry))
                }
                let snoozes = pending.filter {
                    guard case .snooze(let requested) = $0.id.stage else { return false }
                    return $0.id.occurrence == prayer.id && $0.prayerStartsAt == prayer.startsAt &&
                        requested >= prayer.startsAt && (requested <= now || started.contains(prayer.id)) &&
                        $0.firesAt == requested.addingTimeInterval(300) && $0.firesAt < expiry
                }
                if let snooze = snoozes.max(by: { $0.firesAt < $1.firesAt }) {
                    result.append(event(for: prayer, stage: snooze.id.stage, at: snooze.firesAt, expiry: expiry))
                }
            }
        }
        return result.sorted { $0.firesAt < $1.firesAt || ($0.firesAt == $1.firesAt && Self.priority($0.id.stage) > Self.priority($1.id.stage)) }
    }

    func snooze(for id: PrayerOccurrence.ID, requestedAt: Date) -> PrayerEvent? {
        guard id.cityID == location.city.id, let day = days[id.dateKey],
              let prayer = day.prayers.first(where: { $0.id == id }), prayer.startsAt <= requestedAt else { return nil }
        let expiry = expiresAt(for: prayer, in: day)
        let fire = requestedAt.addingTimeInterval(300)
        guard fire < expiry else { return nil }
        return event(for: prayer, stage: .snooze(requestedAt: requestedAt), at: fire, expiry: expiry)
    }

    static func dueEvent(in events: [PrayerEvent], at now: Date,
                         excluding handled: Set<PrayerEvent.ID> = []) -> PrayerEvent? {
        let latest = events.filter {
            $0.prayerStartsAt <= $0.firesAt &&
            $0.firesAt <= now && now.timeIntervalSince($0.firesAt) <= 300 && $0.expiresAt > now
        }.max {
            if $0.prayerStartsAt != $1.prayerStartsAt { return $0.prayerStartsAt < $1.prayerStartsAt }
            if $0.firesAt != $1.firesAt { return $0.firesAt < $1.firesAt }
            return priority($0.id.stage) < priority($1.id.stage)
        }
        guard let latest else { return nil }
        let superseded = handled.contains { id in
            guard id.occurrence == latest.id.occurrence else { return false }
            if case .snooze(let handledAt) = id.stage,
               case .snooze(let requestedAt) = latest.id.stage { return handledAt >= requestedAt }
            return priority(id.stage) >= priority(latest.id.stage)
        }
        return superseded ? nil : latest
    }

    private func expiresAt(for prayer: PrayerOccurrence, in day: Day) -> Date {
        day.prayers.first { $0.startsAt > prayer.startsAt }?.startsAt
            ?? days[ScheduleMonth.dateKey(day.endsAt, in: location.zone)]?.prayers.first?.startsAt
            ?? day.endsAt
    }

    private func event(for prayer: PrayerOccurrence, stage: PrayerEvent.Stage, at fire: Date, expiry: Date) -> PrayerEvent {
        PrayerEvent(id: .init(occurrence: prayer.id, stage: stage), prayerStartsAt: prayer.startsAt,
                    firesAt: fire, expiresAt: expiry)
    }

    private func validFollowUp(_ event: PrayerEvent) -> Bool {
        let seconds = event.firesAt.timeIntervalSince(event.prayerStartsAt)
        return (60...3600).contains(seconds) && seconds.truncatingRemainder(dividingBy: 60) == 0
    }

    private static func priority(_ stage: PrayerEvent.Stage) -> Int {
        switch stage { case .entry: 0; case .followUp: 1; case .snooze: 2 }
    }
}
