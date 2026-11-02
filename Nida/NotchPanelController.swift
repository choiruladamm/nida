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
    let schedules: PrayerDataStore

    init(schedules: PrayerDataStore = PrayerDataStore()) {
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
        panel.onEscape = { [weak self] in self?.show(.collapsed) }
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
                if event.type == .keyDown, event.keyCode == 53, self?.panel?.isKeyWindow == true {
                    self?.show(.collapsed)
                    return true
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

    func setHovering(_ hovering: Bool) {
        model.isHovering = hovering
        if hovering { dismissal?.cancel() } else { armDismissal() }
    }

    func previewSnooze() {
        dismissal?.cancel()
        model.notice = "Preview saja · Tidak ada pengingat dijadwalkan."
        // shortcut: preview actions never schedule events; real snooze belongs to issue #8.
    }

    private func armDismissal() {
        dismissal?.cancel()
        guard !model.isHovering, let seconds = model.state.autoDismissSeconds else { return }
        dismissal = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
            guard let self else { return }
            self.show(.collapsed)
        }
    }

    private func handlePointer(_ event: NSEvent) {
        guard event.type != .keyDown else { return }
        updatePointerPassthrough()
        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            if !model.geometry.interactiveFrame(for: model.state).contains(NSEvent.mouseLocation) {
                show(.collapsed)
            } else if model.state != .collapsed {
                panel?.allowsKeyboardFocus = true
                panel?.makeKey()
            }
        }
    }

    private func updatePointerPassthrough() {
        let rect = model.geometry.interactiveFrame(for: model.state)
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
            Nida smoke: screen=\(model.geometry.screenFrame), camera=\(model.geometry.cameraWidth)x\(model.geometry.cameraHeight), panelVisible=\(panel?.isVisible == true), preservedFrontmost=\(frontmost == NSWorkspace.shared.frontmostApplication?.processIdentifier), panelIsKey=\(panel?.isKeyWindow == true)
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
