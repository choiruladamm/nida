import AppKit
import Observation

// Panel presentation states; scheduling and persistence belong to the delivery layer.
enum PreviewState: String, CaseIterable {
    case collapsed, prayer, followUp, schedule

    var label: LocalizedStringResource {
        switch self {
        case .collapsed: "Tutup notch"
        case .prayer: "Masuk waktu"
        case .followUp: "Pengingat kedua"
        case .schedule: "Jadwal hari ini"
        }
    }

    var isReminder: Bool { self == .prayer || self == .followUp }
}

struct NotchGeometry: Equatable {
    let screenFrame: CGRect
    let cameraWidth: CGFloat
    let cameraHeight: CGFloat

    static let canvasSize = CGSize(width: 520, height: 480)

    var canvasFrame: CGRect {
        CGRect(x: screenFrame.midX - Self.canvasSize.width / 2,
               y: screenFrame.maxY - Self.canvasSize.height,
               width: Self.canvasSize.width, height: Self.canvasSize.height)
    }

    func size(for state: PreviewState, scheduleStatusHeight: CGFloat = 0) -> CGSize {
        switch state {
        case .collapsed: CGSize(width: cameraWidth > 0 ? cameraWidth : 164, height: cameraHeight + 8)
        case .prayer: CGSize(width: 368, height: expandedHeaderHeight(panelWidth: 368) + 112)
        case .followUp: CGSize(width: 400, height: expandedHeaderHeight(panelWidth: 400) + 170)
        case .schedule: CGSize(width: 384, height: expandedHeaderHeight(panelWidth: 384) + 364 + scheduleStatusHeight)
        }
    }

    func expandedHeaderHeight(panelWidth: CGFloat) -> CGFloat {
        hasCameraWings(panelWidth: panelWidth) ? max(36, cameraHeight) : cameraHeight + 28
    }

    func hasCameraWings(panelWidth: CGFloat) -> Bool {
        (panelWidth - cameraWidth) / 2 - NidaStyle.notchHorizontalInset >= NidaStyle.iconControlSize
    }

    // Global AppKit coordinates, also used to let clicks outside the panel pass through.
    func interactiveFrame(for state: PreviewState, scheduleStatusHeight: CGFloat = 0, contentHeight: CGFloat? = nil) -> CGRect {
        let size = size(for: state, scheduleStatusHeight: scheduleStatusHeight)
        let height = state == .collapsed ? size.height : (contentHeight ?? size.height)
        return CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - height,
                      width: size.width, height: height)
    }

    @MainActor static func current() -> NotchGeometry? {
        let screens = NSScreen.screens
        let screen = screens.first { $0.safeAreaInsets.top > 0 }
            ?? screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        guard let screen else { return nil }
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        let width = if let left, let right { max(0, right.minX - left.maxX) } else { CGFloat.zero }
        return NotchGeometry(screenFrame: screen.frame, cameraWidth: width,
                             cameraHeight: screen.safeAreaInsets.top)
    }
}

@MainActor @Observable
final class PrototypeModel {
    var state: PreviewState = .collapsed
    var geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1280, height: 832),
                                 cameraWidth: 180, cameraHeight: 32)
    var expandedHeight: CGFloat?
    var isHovering = false
    var notice: LocalizedStringResource?
    var reminder: PrayerEvent?
}
