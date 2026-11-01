import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Nida

struct NotchGeometryTests {
    private let geometry = NotchGeometry(screenFrame: CGRect(x: -1280, y: 200, width: 1280, height: 832),
                                         cameraWidth: 180, cameraHeight: 32)

    @Test(arguments: PreviewState.allCases)
    func panelAnchorsToScreenTopAndFitsCanvas(state: PreviewState) {
        let frame = geometry.interactiveFrame(for: state)
        #expect(frame.midX == geometry.screenFrame.midX)
        #expect(frame.maxY == geometry.screenFrame.maxY)
        #expect(geometry.canvasFrame.contains(frame))
        #expect(frame.height > geometry.cameraHeight)
    }

    @Test func collapsedTriggerDoesNotWidenThePhysicalNotch() {
        let frame = geometry.interactiveFrame(for: .collapsed)
        #expect(frame.width == geometry.cameraWidth)
        #expect(frame.height - geometry.cameraHeight == 8)
        #expect(!frame.contains(CGPoint(x: geometry.screenFrame.minX + 10, y: 500)))
    }

    @Test func expandedShouldersFlareIntoTheScreenEdge() {
        let path = NotchSilhouette().path(in: CGRect(x: 0, y: 0, width: 360, height: 358))
        #expect(path.contains(CGPoint(x: 8, y: 1)))
        #expect(!path.contains(CGPoint(x: 5, y: 20)))
        #expect(path.contains(CGPoint(x: 180, y: 357)))
        #expect(!path.contains(CGPoint(x: 11, y: 357)))
    }

    @Test func unnotchedDisplayKeepsAReachableTrigger() {
        let fallback = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                     cameraWidth: 0, cameraHeight: 0)
        #expect(fallback.size(for: .collapsed) == CGSize(width: 164, height: 8))
        #expect(fallback.canvasFrame.contains(fallback.interactiveFrame(for: .schedule)))
    }
}

@MainActor struct PrototypeTests {
    @Test func compactScheduleFitsBelowTheCamera() {
        let geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                     cameraWidth: 179, cameraHeight: 32)
        let size = geometry.size(for: .schedule)
        let host = NSHostingView(rootView: ScheduleView(onClose: {}).frame(width: size.width))
        #expect(host.fittingSize.height <= size.height - geometry.cameraHeight)
    }

    @Test func previewSnoozeDoesNotCreateAnotherReminder() {
        let controller = NotchPanelController()
        controller.model.state = .followUp
        controller.previewSnooze()
        #expect(controller.model.state == .followUp)
        #expect(controller.model.notice != nil)
        controller.stop()
    }

    @Test func automaticPanelCannotTakeKeyboardFocus() {
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                               backing: .buffered, defer: false)
        #expect(!panel.canBecomeKey)
        panel.allowsKeyboardFocus = true
        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
    }

    @Test func onlyReminderPreviewsAutoDismiss() {
        #expect(PreviewState.prayer.autoDismissSeconds == 7)
        #expect(PreviewState.followUp.autoDismissSeconds == 18)
        #expect(PreviewState.schedule.autoDismissSeconds == nil)
        #expect(PreviewState.collapsed.autoDismissSeconds == nil)
    }
}
