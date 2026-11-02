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

    @Test(arguments: [PreviewState.prayer, .followUp, .schedule])
    func hitRegionFollowsFittedContent(state: PreviewState) {
        let height: CGFloat = 137
        let frame = geometry.interactiveFrame(for: state, contentHeight: height)
        #expect(frame.height == height)
        #expect(frame.maxY == geometry.screenFrame.maxY)
        #expect(!frame.contains(CGPoint(x: frame.midX, y: frame.minY - 1)))
        #expect(geometry.interactiveFrame(for: .collapsed, contentHeight: height)
            == geometry.interactiveFrame(for: .collapsed))
    }

    @Test func scheduleStatusAddsSpaceWithoutChangingOtherStates() {
        let extra = NidaStyle.scheduleStatusHeight
        let normal = geometry.interactiveFrame(for: .schedule)
        let expanded = geometry.interactiveFrame(for: .schedule, scheduleStatusHeight: extra)
        #expect(expanded.height == normal.height + extra)
        #expect(expanded.maxY == normal.maxY)
        #expect(geometry.canvasFrame.contains(expanded))
        #expect(expanded.contains(CGPoint(x: expanded.midX, y: expanded.minY + 14)))
        for state in [PreviewState.collapsed, .prayer, .followUp] {
            #expect(geometry.size(for: state, scheduleStatusHeight: extra) == geometry.size(for: state))
        }
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
    @Test(arguments: AppLanguage.allCases, [PreviewState.prayer, .followUp, .schedule])
    func redesignedNotchContentFits(language: AppLanguage, state: PreviewState) {
        let controller = NotchPanelController()
        for camera in [CGSize(width: 179, height: 32), .zero, CGSize(width: 280, height: 40)] {
            let model = PrototypeModel()
            model.state = state
            model.geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                cameraWidth: camera.width, cameraHeight: camera.height)
            let size = model.geometry.size(for: state)
            let host = NSHostingView(rootView: NotchView(model: model, controller: controller).expandedPanel
                .frame(width: size.width).fixedSize(horizontal: false, vertical: true)
                .environment(\.locale, language.locale))
            #expect(host.fittingSize.height <= NotchGeometry.canvasSize.height)
            let fitted = NSHostingView(rootView: NotchView(model: model, controller: controller).fittedPanel
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.locale, language.locale))
            #expect(abs(fitted.fittingSize.height - host.fittingSize.height) < 0.5)

        }
    }

    @Test(arguments: AppLanguage.allCases)
    func fullScheduleAndRefreshErrorFitWithoutScrolling(language: AppLanguage) async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "nida-full-fit-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let city = PrayerCity(id: String(repeating: "a", count: 32), name: "KOTA JAKARTA")
        let location = PrayerLocation(city: city, province: "DKI JAKARTA", zone: .west)
        let period = ScheduleMonth(containing: now, in: .west)
        let cache = PrayerCache(directory: folder)
        for month in [period, period.next] {
            try cache.save(PrayerMonth(provider: PrayerMonth.providerID, location: location,
                period: month, retrievedAt: now,
                days: Dictionary(uniqueKeysWithValues: try month.dateKeys().map {
                    ($0, PrayerDay(subuh: "04:00", dzuhur: "11:40", ashar: "14:55", maghrib: "17:49", isya: "23:59"))
                })))
        }
        defaults.set(try JSONEncoder().encode(location), forKey: "prayerLocation")
        let store = PrayerDataStore(repository: PrayerRepository(cache: cache), defaults: defaults)
        await store.restoreAndRefresh(now: now)
        #expect(store.today(at: now) != nil)
        #expect(store.message == nil)
        let geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                     cameraWidth: 179, cameraHeight: 32)
        let host = NSHostingView(rootView: ScheduleView(store: store, onOpenNotch: {})
            .fixedSize(horizontal: false, vertical: true).frame(width: 384)
            .environment(\.locale, language.locale))
        let normalHeight = host.fittingSize.height
        #expect(normalHeight > 300)
        #expect(normalHeight <= geometry.size(for: .schedule).height - geometry.cameraHeight)
        let controller = NotchPanelController(schedules: store)
        let model = PrototypeModel()
        model.state = .schedule
        model.geometry = geometry
        func notchContentHeight() -> CGFloat {
            let view = NotchView(model: model, controller: controller)
            let content = NSHostingView(rootView: view.expandedPanel
                .frame(width: 384).fixedSize(horizontal: false, vertical: true)
                .environment(\.locale, language.locale)).fittingSize.height
            let fitted = NSHostingView(rootView: view.fittedPanel
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.locale, language.locale)).fittingSize.height
            #expect(abs(fitted - content) < 0.5)
            return fitted
        }
        #expect(notchContentHeight() <= geometry.size(for: .schedule).height)
        store.showRefreshFailureForReview()
        let errorHost = NSHostingView(rootView: ScheduleView(store: store, onOpenNotch: {})
            .fixedSize(horizontal: false, vertical: true).frame(width: 384)
            .environment(\.locale, language.locale))
        #expect(notchContentHeight() <= geometry.size(for: .schedule,
            scheduleStatusHeight: NidaStyle.scheduleStatusHeight).height)
        #expect(errorHost.fittingSize.height > normalHeight)
        #expect(errorHost.fittingSize.height <= geometry.size(for: .schedule,
            scheduleStatusHeight: NidaStyle.scheduleStatusHeight).height - geometry.cameraHeight)
    }

    @Test(arguments: [false, true])
    func compactScheduleFitsBelowTheCamera(highContrastAppearance: Bool) {
        let geometry = NotchGeometry(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                     cameraWidth: 179, cameraHeight: 32)
        let size = geometry.size(for: .schedule)
        let suite = "nida-fit-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let host = NSHostingView(rootView: ScheduleView(store: PrayerDataStore(defaults: defaults), isNotch: true)
            .frame(width: size.width))
        host.appearance = NSAppearance(named: highContrastAppearance ? .accessibilityHighContrastDarkAqua : .darkAqua)
        #expect(host.fittingSize.height <= size.height - geometry.cameraHeight)
    }

    @Test func panelUsesTheSharedScheduleStore() {
        let store = PrayerDataStore()
        let controller = NotchPanelController(schedules: store)
        #expect(controller.schedules === store)
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

@MainActor struct ContrastTests {
    private func luminance(_ color: Color) throws -> Double {
        let rgb = try #require(NSColor(color).usingColorSpace(.sRGB))
        func linear(_ value: CGFloat) -> Double {
            let component = Double(value)
            return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
    }

    @Test func opaqueButtonAndAccessibilitySurfaceHaveReadableText() throws {
        let main = try luminance(NidaStyle.text)
        let ink = try luminance(NidaStyle.surface)
        let fallback = try luminance(NidaStyle.opaqueGlass)
        let supporting = try luminance(NidaStyle.secondaryText)
        #expect((main + 0.05) / (ink + 0.05) >= 7)
        #expect((main + 0.05) / (fallback + 0.05) >= 4.5)
        #expect((supporting + 0.05) / (fallback + 0.05) >= 4.5)
    }

    @Test(arguments: [false, true], [false, true])
    func iconButtonKeepsItsTargetWithAccessibleStyles(prominent: Bool, highContrastAppearance: Bool) {
        let host = NSHostingView(rootView: Button(action: {}) {
            Image(systemName: "xmark").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
        }
        .buttonStyle(NidaButtonStyle(prominent: prominent)))
        host.appearance = NSAppearance(named: highContrastAppearance ? .accessibilityHighContrastDarkAqua : .darkAqua)
        #expect(host.fittingSize.width >= 28)
        #expect(host.fittingSize.height >= 28)
    }
}
