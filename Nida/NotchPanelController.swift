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
    private(set) var dismissalDeadline: ContinuousClock.Instant?
    private var hoverTransition: Task<Void, Never>?
    private var openedByHover = false

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
        panel.contentView = NSHostingView(rootView: NotchView(model: model, controller: self).appLanguage(preferences))
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
        hoverTransition?.cancel()
        openedByHover = false
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
        guard model.isHovering != hovering else { return }
        model.isHovering = hovering
        hoverTransition?.cancel()
        if hovering {
            guard model.state == .collapsed else { return }
            hoverTransition = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
                guard let self, self.model.isHovering, self.model.state == .collapsed else { return }
                self.show(.schedule)
                self.openedByHover = true
            }
        } else {
            guard openedByHover else { return }
            hoverTransition = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                guard let self, !self.model.isHovering, self.openedByHover else { return }
                self.show(.collapsed)
            }
        }
    }

    func previewSnooze() {
        model.notice = "Preview saja · Tidak ada pengingat dijadwalkan."
        // Preview actions stay isolated from the delivery ledger.
    }

    private func armDismissal() {
        dismissal?.cancel()
        dismissalDeadline = nil
        guard let seconds = preferences.displaySeconds(for: model.state) else { return }
        let deadline = ContinuousClock.now.advanced(by: .seconds(seconds))
        dismissalDeadline = deadline
        dismissal = Task { [weak self] in
            do { try await Task.sleep(until: deadline, clock: .continuous) } catch { return }
            guard let self else { return }
            self.dismissReminder()
        }
    }

    private func handlePointer(_ event: NSEvent) {
        guard event.type != .keyDown else { return }
        updatePointerPassthrough()
        if event.type == .mouseMoved {
            let frame = model.geometry.interactiveFrame(for: model.state,
                scheduleStatusHeight: scheduleStatusHeight, contentHeight: model.expandedHeight)
            setHovering(frame.contains(NSEvent.mouseLocation))
        }
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            handleClick(inside: model.geometry.interactiveFrame(for: model.state,
                scheduleStatusHeight: scheduleStatusHeight, contentHeight: model.expandedHeight).contains(NSEvent.mouseLocation))
        }
    }

    func handleClick(inside: Bool) {
        if !inside {
            if !model.state.isReminder { dismissReminder() }
        } else if model.state != .collapsed {
            openedByHover = false
            hoverTransition?.cancel()
            panel?.allowsKeyboardFocus = true
            panel?.makeKey()
        }
    }

    func updatePanelHeight(_ height: CGFloat) {
        guard model.state != .collapsed else { return }
        model.expandedHeight = height
        updatePointerPassthrough()
    }

    private func updatePointerPassthrough() {
        let rect = model.geometry.interactiveFrame(for: model.state, scheduleStatusHeight: scheduleStatusHeight, contentHeight: model.expandedHeight)
        panel?.ignoresMouseEvents = !rect.contains(NSEvent.mouseLocation)
    }

    @objc private func reposition() {
        guard let geometry = NotchGeometry.current() else { return }
        model.geometry = geometry
        panel?.setFrame(geometry.canvasFrame, display: true)
        updatePointerPassthrough()
    }

    func stop() {
        dismissalDeadline = nil
        hoverTransition?.cancel()
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
