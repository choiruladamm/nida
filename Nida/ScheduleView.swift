import SwiftUI

// Always emit the requested current instant before future prayer boundaries.
struct PrayerDisplaySchedule: TimelineSchedule {
    let boundaries: [Date]

    func entries(from startDate: Date, mode: Mode) -> [Date] {
        [startDate] + boundaries.filter { $0 > startDate }
    }
}

struct ScheduleView: View {
    let store: PrayerDataStore
    var isNotch = false
    var onOpenNotch: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    @Environment(\.openSettings) private var openSettings
    @Environment(\.locale) private var locale
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let timeline = try? store.timeline()
        let now = Date()
        let boundaries = (timeline?.boundaryDates ?? []).filter { $0 > now }
        Group {
            if boundaries.isEmpty { content(at: now, timeline: timeline) }
            else {
                TimelineView(PrayerDisplaySchedule(boundaries: boundaries)) { context in
                    content(at: context.date, timeline: timeline)
                }
            }
        }
        .foregroundStyle(NidaStyle.text)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            Task { await store.restoreAndRefresh() }
        }
    }

    private func content(at date: Date, timeline: PrayerTimeline?) -> some View {
        let snapshot = timeline?.snapshot(at: date)
        let zone = store.location?.zone ?? .west
        return VStack(spacing: isNotch ? 12 : 8) {
            HStack(spacing: 12) {
                Text(store.displayCityName ?? "Nida")
                    .font(.system(size: isNotch ? 11 : 12, weight: .medium))
                    .foregroundStyle(isNotch ? NidaStyle.secondaryText : NidaStyle.text)
                    .lineLimit(1).layoutPriority(1)
                Spacer(minLength: 4)
                if !isNotch {
                    Text(date.formatted(Date.FormatStyle(locale: locale, timeZone: zone.timeZone)
                        .day().month(.abbreviated)))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(NidaStyle.secondaryText).fixedSize()
                }
                if let onOpenNotch {
                    Button(action: onOpenNotch) { Image(systemName: "arrow.up.right").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                        .accessibilityLabel("Buka jadwal di notch").help("Buka jadwal di notch")
                }
            }
            VStack(alignment: .leading, spacing: isNotch ? 14 : 10) {
                if let next = snapshot?.next {
                    let countdown = HStack(spacing: 5) {
                        Image(systemName: "clock").font(.system(size: 10)).accessibilityHidden(true)
                        Text("Dalam")
                        Text(next.startsAt, style: .timer).monospacedDigit()
                            .accessibilityLabel("Sisa waktu menuju sholat berikutnya")
                            .accessibilityValue(Text(next.startsAt, style: .timer))
                    }
                    .font(.system(size: isNotch ? 12 : 11)).foregroundStyle(NidaStyle.secondaryText)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Berikutnya").font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NidaStyle.secondaryText)
                            if !isNotch {
                                Spacer()
                                countdown
                            }
                        }
                        HStack(alignment: .firstTextBaseline) {
                            let tomorrow = next.id.dateKey != ScheduleMonth.dateKey(date, in: zone)
                            Text((tomorrow ? LocalizedStringResource("\(next.id.prayer.label.localized(in: locale)) · besok") : next.id.prayer.label).localized(in: locale))
                                .font(.system(size: isNotch ? 26 : 22, weight: .semibold))
                            Spacer()
                            Text(next.wallTime).monospacedDigit()
                                .font(.system(size: isNotch ? 32 : 30, weight: .regular))
                        }
                        if isNotch { countdown }
                    }
                    .padding(.vertical, isNotch ? 0 : 2)
                } else if snapshot?.hasToday == true {
                    Text("Jadwal Subuh besok belum tersedia.").font(.callout)
                }
                if let snapshot, snapshot.hasToday {
                    let layout = isNotch ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(spacing: 2))
                    layout {
                        ForEach(snapshot.today) { prayer in
                            let selected = snapshot.next?.id == prayer.id
                            Group {
                                if isNotch {
                                    VStack(spacing: 6) {
                                        Text(prayer.id.prayer.label.localized(in: locale))
                                            .font(.system(size: 11, weight: selected ? .semibold : .regular))
                                        Text(prayer.wallTime).monospacedDigit()
                                            .font(.system(size: 14, weight: selected ? .semibold : .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                } else {
                                    HStack(spacing: 10) {
                                        Image(systemName: prayerSymbol(prayer.id.prayer))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(selected ? NidaStyle.accent : NidaStyle.secondaryText)
                                            .frame(width: 22)
                                            .accessibilityHidden(true)
                                        Text(prayer.id.prayer.label.localized(in: locale))
                                        Spacer()
                                        Text(prayer.wallTime).monospacedDigit()
                                    }
                                    .padding(.horizontal, 12)
                                }
                            }
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .foregroundStyle(prayer.hasStarted(at: date) && contrast != .increased ? NidaStyle.secondaryText : NidaStyle.text)
                            .frame(height: isNotch ? 62 : 29)
                            .background {
                                RoundedRectangle(cornerRadius: isNotch ? 12 : NidaStyle.rowRadius)
                                    .fill(selected ? (isNotch ? Color.white.opacity(0.08) : NidaStyle.accent.opacity(0.13)) : .clear)
                                    .padding(.horizontal, 0)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: isNotch ? 12 : NidaStyle.rowRadius)
                                    .strokeBorder(selected && contrast == .increased ? NidaStyle.text : .clear, lineWidth: 1)
                                    .padding(.horizontal, 0)
                            }
                            .overlay(alignment: isNotch ? .bottom : .trailing) {
                                Circle().fill(selected && isNotch ? NidaStyle.accent : .clear)
                                    .frame(width: 4, height: 4)
                                    .offset(x: isNotch ? 0 : 12, y: isNotch ? -5 : 0)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(Text(selected ? LocalizedStringKey("Berikutnya") : prayer.hasStarted(at: date) ? LocalizedStringKey("Sudah lewat") : LocalizedStringKey("")))
                        }
                    }
                    .padding(isNotch ? 0 : 4)
                    .background {
                        if !isNotch {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.black.opacity(0.12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(.white.opacity(contrast == .increased ? 0.5 : 0.07), lineWidth: 1)
                                }
                        }
                    }
                } else if store.isRefreshing {
                    ProgressView("Memuat jadwal…").controlSize(.small)
                } else {
                    Text(store.location == nil ? LocalizedStringKey("Pilih kota di Pengaturan untuk mulai.") : LocalizedStringKey("Jadwal tanggal ini belum tersedia. Coba perbarui."))
                        .font(.callout).foregroundStyle(NidaStyle.secondaryText)
                }

            }
            .fixedSize(horizontal: false, vertical: true)
            if let message = store.message {
                Text((snapshot?.hasToday == true ? LocalizedStringResource("Jadwal tetap ditampilkan · \(message.localized(in: locale))") : message).localized(in: locale))
                    .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(message.localized(in: locale))
            }
            HStack(spacing: 8) {
                Text(PrayerMonth.attribution + " · " + zone.label)
                    .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                    .lineLimit(1)
                if isNotch {
                    Spacer(minLength: 8)
                    refreshButton
                    Button {
                        onOpenSettings?()
                        NSApplication.shared.activate()
                        openSettings()
                    } label: {
                        Image(systemName: "gearshape").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
                    }
                    .accessibilityLabel("Pengaturan dan pilihan kota").help("Pengaturan dan pilihan kota")
                }
            }
            .font(.system(size: 12))
        }
        .buttonStyle(NidaButtonStyle(flat: isNotch)).tint(.clear)
        .padding(.horizontal, isNotch ? NidaStyle.notchHorizontalInset : 16)
        .padding(.top, isNotch ? 12 : 10).padding(.bottom, isNotch ? 20 : 6)
        .task(id: ScheduleMonth.dateKey(date, in: zone)) { await store.restoreAndRefresh() }
    }

    private func prayerSymbol(_ prayer: PrayerKind) -> String {
        switch prayer {
        case .subuh: "sunrise"
        case .dzuhur: "sun.max"
        case .ashar: "sun.haze"
        case .maghrib: "sunset"
        case .isya: "moon.stars"
        }
    }

    private var refreshButton: some View {
        Button { Task { await store.refresh() } } label: {
            Group {
                if store.isRefreshing { ProgressView().controlSize(.mini) }
                else { Image(systemName: "arrow.clockwise") }
            }
            .frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize)
        }
        .disabled(store.location == nil || store.isRefreshing)
        .accessibilityLabel(Text(store.isRefreshing ? LocalizedStringKey("Memperbarui jadwal") : LocalizedStringKey("Perbarui jadwal")))
        .help("Perbarui jadwal")
    }
}
