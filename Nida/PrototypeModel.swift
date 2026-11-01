import AppKit
import Observation

// Preview state only: never schedules or persists real prayer reminders.
enum PreviewState: String, CaseIterable {
    case collapsed, prayer, followUp, schedule

    var label: String {
        switch self {
        case .collapsed: "Collapsed"
        case .prayer: "Prayer time"
        case .followUp: "Follow-up"
        case .schedule: "Today's schedule"
        }
    }

    var autoDismissSeconds: Double? {
        switch self {
        case .prayer: 7
        case .followUp: 18
        default: nil
        }
    }
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

    func size(for state: PreviewState) -> CGSize {
        switch state {
        case .collapsed: CGSize(width: max(cameraWidth + 28, 164), height: cameraHeight + 12)
        case .prayer: CGSize(width: 392, height: cameraHeight + 112)
        case .followUp: CGSize(width: 440, height: cameraHeight + 170)
        case .schedule: CGSize(width: 400, height: cameraHeight + 414)
        }
    }

    // Global AppKit coordinates, also used to let clicks outside the panel pass through.
    func interactiveFrame(for state: PreviewState) -> CGRect {
        let size = size(for: state)
        return CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height,
                      width: size.width, height: size.height)
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
    var isHovering = false
    var notice: String?
}
