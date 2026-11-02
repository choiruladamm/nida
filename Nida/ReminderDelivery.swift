import AppKit
import CoreGraphics
import Observation

struct ReminderLedger: Codable, Equatable {
    var handled: Set<PrayerEvent.ID> = []
    var closed: Set<PrayerOccurrence.ID> = []
    var pending: [PrayerEvent] = []

    mutating func reconcile(_ timeline: PrayerTimeline, at now: Date, delay: FollowUpDelay) {
        pending = timeline.events(at: now, delay: delay, pending: pending, handled: handled)
            .filter { !closed.contains($0.id.occurrence) }
    }

    mutating func takeDue(at now: Date, available: Bool) -> PrayerEvent? {
        guard available else { return nil }
        let event = PrayerTimeline.dueEvent(in: pending, at: now, excluding: handled)
        // Retire skipped older stages too, so a clock correction cannot replay a recovered stack.
        handled.formUnion(pending.filter { $0.firesAt <= now }.map(\.id))
        return event
    }

    mutating func dismiss(_ event: PrayerEvent) {
        guard event.id.stage != .entry else { return }
        closed.insert(event.id.occurrence)
        pending.removeAll { $0.id.occurrence == event.id.occurrence }
    }

    mutating func snooze(_ event: PrayerEvent, timeline: PrayerTimeline, at now: Date) -> Bool {
        guard event.id.stage != .entry, !closed.contains(event.id.occurrence),
              let request = timeline.snooze(for: event.id.occurrence, requestedAt: now) else { return false }
        pending.removeAll { $0.id.occurrence == event.id.occurrence && $0.id.stage != .entry && $0.id.stage != .followUp }
        pending.append(request)
        return true
    }
}

struct ReminderLedgerFile {
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? URL.applicationSupportDirectory.appending(path: "Nida/reminder-ledger.json")
    }

    func load() throws -> ReminderLedger {
        guard FileManager.default.fileExists(atPath: url.path) else { return ReminderLedger() }
        return try JSONDecoder().decode(ReminderLedger.self, from: Data(contentsOf: url))
    }

    func save(_ ledger: ReminderLedger) throws {
        let data = try JSONEncoder().encode(ledger)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
final class ReminderDelivery: NSObject {
    private let controller: NotchPanelController
    private var store: PrayerDataStore { controller.schedules }
    private let file: ReminderLedgerFile
    private var ledger = ReminderLedger()
    private var timer: Task<Void, Never>?
    private var refresh: Task<Void, Never>?
    private var suspended = false
    private var failedLoad = false
    private var running = false
    private var lastRefreshDay: String?
    private var lastDelayMinutes = UserDefaults.standard.integer(forKey: "followUpDelayMinutes")

    init(controller: NotchPanelController, file: ReminderLedgerFile = ReminderLedgerFile()) {
        self.controller = controller
        self.file = file
        super.init()
    }

    func start() {
        guard !running else { return }
        running = true
        do { ledger = try file.load() }
        catch { failedLoad = true; report(error) }
        controller.onDismissReminder = { [weak self] event in self?.dismiss(event) }
        controller.onSnoozeReminder = { [weak self] event in self?.snooze(event) }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(self, selector: #selector(pause), name: name, object: nil)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(resume), name: name, object: nil)
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(pause), name: .init("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(resume), name: .init("com.apple.screenIsUnlocked"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changed),
            name: .NSSystemClockDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changed),
            name: .NSSystemTimeZoneDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification, object: nil)
        observeSchedules()
        reload()
    }

    private func observeSchedules() {
        withObservationTracking {
            _ = store.location
            _ = store.months
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.running else { return }
                if let event = self.controller.model.reminder,
                   event.id.occurrence.cityID != self.store.location?.city.id {
                    self.controller.hideDeliveredReminder()
                }
                self.observeSchedules()
                self.tick()
            }
        }
    }

    private var canPresent: Bool {
        Self.sessionAllowsDelivery(CGSessionCopyCurrentDictionary() as? [String: Any], suspended: suspended)
    }

    static func sessionAllowsDelivery(_ session: [String: Any]?, suspended: Bool) -> Bool {
        guard !suspended, let session,
              session[kCGSessionOnConsoleKey as String] as? Bool == true else { return false }
        // macOS has no public dedicated lock-state API; combine this session flag with lock notifications.
        return session["CGSSessionScreenIsLocked"] as? Bool != true
    }

    @objc private func pause() {
        suspended = true
        controller.hideDeliveredReminder()
        timer?.cancel()
    }

    @objc private func resume() { suspended = false; reload() }
    @objc private func changed() { reload() }
    @objc private func settingsChanged() {
        let minutes = UserDefaults.standard.integer(forKey: "followUpDelayMinutes")
        guard minutes != lastDelayMinutes else { return }
        lastDelayMinutes = minutes
        tick()
    }

    private func reload() {
        tick()
        if let location = store.location {
            lastRefreshDay = location.city.id + ScheduleMonth.dateKey(Date(), in: location.zone)
        }
        guard refresh == nil else { return }
        refresh = Task { [weak self] in
            guard let self else { return }
            await self.store.restoreAndRefresh()
            self.refresh = nil
            self.tick()
        }
    }

    private func tick() {
        timer?.cancel()
        guard running, !failedLoad else { return }
        let now = Date()
        if let event = controller.model.reminder, event.expiresAt <= now { controller.hideDeliveredReminder() }
        if let timeline = try? store.timeline() {
            let minutes = UserDefaults.standard.integer(forKey: "followUpDelayMinutes")
            let delay = (try? FollowUpDelay(minutes: minutes)) ?? .standard
            var next = ledger
            next.reconcile(timeline, at: now, delay: delay)
            let event = next.takeDue(at: now, available: canPresent)
            if commit(next), let event { controller.present(event) }
        }
        guard !suspended else { return }
        // A one-minute ceiling also rechecks day/clock/session changes when notifications are missed.
        let next = ledger.pending.filter { !ledger.handled.contains($0.id) && $0.firesAt > now }.map(\.firesAt).min()
        let seconds = min(60, max(0.1, next?.timeIntervalSince(now) ?? 60))
        timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self else { return }
            if let location = self.store.location,
               location.city.id + ScheduleMonth.dateKey(Date(), in: location.zone) != self.lastRefreshDay {
                self.reload()
            } else { self.tick() }
        }
    }

    private func commit(_ next: ReminderLedger) -> Bool {
        guard next != ledger else { return true }
        do { try file.save(next); ledger = next; store.deliveryMessage = nil; return true }
        catch { report(error); return false }
    }

    private func dismiss(_ event: PrayerEvent) {
        var next = ledger
        next.dismiss(event)
        _ = commit(next)
        tick()
    }

    private func snooze(_ event: PrayerEvent) {
        guard let timeline = try? store.timeline() else { return }
        var next = ledger
        guard next.snooze(event, timeline: timeline, at: Date()) else {
            controller.model.notice = "Terlalu dekat dengan waktu sholat berikutnya."
            return
        }
        guard commit(next) else { return }
        controller.hideDeliveredReminder()
        tick()
    }

    private func report(_ error: any Error) {
        store.deliveryMessage = "Pengingat tidak dapat disimpan; pengiriman dijeda. \(error.localizedDescription)"
    }

    func stop() {
        running = false
        timer?.cancel()
        refresh?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        controller.onDismissReminder = nil
        controller.onSnoozeReminder = nil
    }
}
