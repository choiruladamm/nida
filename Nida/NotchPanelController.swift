import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    var onEscape: (() -> Void)?
    var allowsKeyboardFocus = false
    override var canBecomeKey: Bool { allowsKeyboardFocus }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

@MainActor
final class NotchPanelController: NSObject {
    let model = PrototypeModel()
    let preferences: ReminderPreferences
    let schedules: PrayerDataStore
    var scheduleStatusHeight: CGFloat { schedules.message == nil ? 0 : NidaStyle.scheduleStatusHeight }
    var onDismissReminder: ((PrayerEvent) -> Void)?
    var onSnoozeReminder: ((PrayerEvent) -> Void)?

    init(schedules: PrayerDataStore = PrayerDataStore(), preferences: ReminderPreferences = ReminderPreferences()) {
        self.preferences = preferences
        self.schedules = schedules
        super.init()
    }
    private var panel: NotchPanel?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var dismissal: Task<Void, Never>?

    func start() {
        guard panel == nil, let geometry = NotchGeometry.current() else { return }
        model.geometry = geometry
        let panel = NotchPanel(contentRect: geometry.canvasFrame,
                               styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .none
        panel.onEscape = { [weak self] in self?.dismissReminder() }
        panel.contentView = NSHostingView(rootView: NotchView(model: model, controller: self))
        self.panel = panel
        updatePointerPassthrough()
        panel.orderFrontRegardless()

        // Mouse events need no accessibility permission; no global keyboard monitoring.
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.handlePointer(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events.union(.keyDown)) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                if event.type == .keyDown, self?.panel?.isKeyWindow == true {
                    if event.keyCode == 53 {
                        self?.dismissReminder()
                        return true
                    }
                    self?.armDismissal()
                }
                self?.handlePointer(event)
                return false
            }
            return handled ? nil : event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reposition),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(reposition),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    func show(_ state: PreviewState, interactive: Bool = false) {
        start()
        dismissal?.cancel()
        model.notice = nil
        model.reminder = nil
        model.state = state
        panel?.allowsKeyboardFocus = interactive && state != .collapsed
        if interactive && state != .collapsed {
            panel?.makeKey()
        } else {
            panel?.resignKey()
        }
        updatePointerPassthrough()
        armDismissal()
    }

    func present(_ event: PrayerEvent) {
        show(event.id.stage == .entry ? .prayer : .followUp)
        model.reminder = event
        preferences.playSound()
    }

    func hideDeliveredReminder() {
        guard model.reminder != nil else { return }
        show(.collapsed)
    }

    func dismissReminder() {
        if let event = model.reminder { onDismissReminder?(event) }
        show(.collapsed)
    }

    func snoozeReminder() {
        if let event = model.reminder { onSnoozeReminder?(event) }
        else { previewSnooze() }
    }

    func setHovering(_ hovering: Bool) {
        model.isHovering = hovering
        if hovering { dismissal?.cancel() } else { armDismissal() }
    }

    func previewSnooze() {
        dismissal?.cancel()
        model.notice = "Preview saja · Tidak ada pengingat dijadwalkan."
        // Preview actions stay isolated from the delivery ledger.
    }

    private func armDismissal() {
        dismissal?.cancel()
        guard !model.isHovering, let seconds = model.state.autoDismissSeconds else { return }
        dismissal = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self else { return }
            self.dismissReminder()
        }
    }

    private func handlePointer(_ event: NSEvent) {
        guard event.type != .keyDown else { return }
        updatePointerPassthrough()
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            if !model.geometry.interactiveFrame(for: model.state, scheduleStatusHeight: scheduleStatusHeight).contains(NSEvent.mouseLocation) {
                dismissReminder()
            } else if model.state != .collapsed {
                panel?.allowsKeyboardFocus = true
                panel?.makeKey()
            }
        }
    }

    private func updatePointerPassthrough() {
        let rect = model.geometry.interactiveFrame(for: model.state, scheduleStatusHeight: scheduleStatusHeight)
        panel?.ignoresMouseEvents = !rect.contains(NSEvent.mouseLocation)
    }

    @objc private func reposition() {
        guard let geometry = NotchGeometry.current() else { return }
        model.geometry = geometry
        panel?.setFrame(geometry.canvasFrame, display: true)
        updatePointerPassthrough()
    }

    func stop() {
        dismissal?.cancel()
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        panel?.orderOut(nil)
        panel = nil
    }

    #if DEBUG
    // Native smoke check: a real window is presented; this does not simulate user interaction.
    func runSmokeCheck() {
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        show(.prayer)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            let report = """
            Nida smoke: screen=\(model.geometry.screenFrame), camera=\(model.geometry.cameraWidth)x\(model.geometry.cameraHeight), panelVisible=\(panel?.isVisible == true), preservedFrontmost=\(frontmost == NSWorkspace.shared.frontmostApplication?.processIdentifier), panelIsKey=\(panel?.isKeyWindow == true), deliverySessionAvailable=\(ReminderDelivery.sessionAllowsDelivery(CGSessionCopyCurrentDictionary() as? [String: Any], suspended: false))
            """
            print(report)
            show(.followUp)
            try? await Task.sleep(for: .seconds(1))
            show(.schedule)
            try? await Task.sleep(for: .seconds(1))
            show(.collapsed)
            NSApplication.shared.terminate(nil)
        }
    }
    #endif
}
