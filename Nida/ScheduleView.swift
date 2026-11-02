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
    var onClose: (() -> Void)?
    var onOpenNotch: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.colorSchemeContrast) private var contrast
    private var isNotch: Bool { onClose != nil }

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
        .frame(height: isNotch ? 364 + (store.message == nil ? 0 : NidaStyle.scheduleStatusHeight) : nil, alignment: .top)
        .foregroundStyle(NidaStyle.text)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            Task { await store.restoreAndRefresh() }
        }
    }

    private func content(at date: Date, timeline: PrayerTimeline?) -> some View {
        let snapshot = timeline?.snapshot(at: date)
        let zone = store.location?.zone ?? .west
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(store.location?.city.name.localizedCapitalized ?? "Nida")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1).layoutPriority(1)
                Spacer(minLength: 4)
                Text(date.formatted(Date.FormatStyle(locale: locale, timeZone: zone.timeZone)
                    .day().month(.abbreviated)))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(NidaStyle.secondaryText).fixedSize()
                if let onClose {
                    Button(action: onClose) { Image(systemName: "xmark").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                        .accessibilityLabel("Tutup jadwal").help("Tutup jadwal · Escape")
                } else if let onOpenNotch {
                    Button(action: onOpenNotch) { Image(systemName: "arrow.up.right").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                        .accessibilityLabel("Buka jadwal di notch").help("Buka jadwal di notch")
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                if let next = snapshot?.next {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Berikutnya").font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NidaStyle.secondaryText)
                        HStack(alignment: .firstTextBaseline) {
                            let tomorrow = next.id.dateKey != ScheduleMonth.dateKey(date, in: zone)
                            Text((tomorrow ? LocalizedStringResource("\(next.id.prayer.label.localized(in: locale)) · besok") : next.id.prayer.label).localized(in: locale))
                                .font(.system(size: 24, weight: .semibold))
                            Spacer()
                            Text(next.wallTime).monospacedDigit()
                                .font(.system(size: 28, weight: .regular))
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "clock").font(.system(size: 10)).accessibilityHidden(true)
                            Text("Dalam")
                            Text(next.startsAt, style: .timer).monospacedDigit()
                                .accessibilityLabel("Sisa waktu menuju sholat berikutnya")
                                .accessibilityValue(Text(next.startsAt, style: .timer))
                        }
                        .font(.system(size: 12)).foregroundStyle(NidaStyle.secondaryText)
                    }
                } else if snapshot?.hasToday == true {
                    Text("Jadwal Subuh besok belum tersedia.").font(.callout)
                }
                if let snapshot, snapshot.hasToday {
                    VStack(spacing: 2) {
                        ForEach(snapshot.today) { prayer in
                            let selected = snapshot.next?.id == prayer.id
                            HStack {
                                Text(prayer.id.prayer.label.localized(in: locale))
                                Spacer()
                                Text(prayer.wallTime).monospacedDigit()
                            }
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .foregroundStyle(prayer.hasStarted(at: date) && contrast != .increased ? NidaStyle.secondaryText : NidaStyle.text)
                            .frame(height: 30)
                            .background {
                                RoundedRectangle(cornerRadius: NidaStyle.rowRadius)
                                    .fill(selected ? .white.opacity(0.08) : .clear)
                                    .padding(.horizontal, -10)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: NidaStyle.rowRadius)
                                    .strokeBorder(selected && contrast == .increased ? NidaStyle.text : .clear, lineWidth: 1)
                                    .padding(.horizontal, -10)
                            }
                            .overlay(alignment: .trailing) {
                                Circle().fill(selected ? NidaStyle.accent : .clear)
                                    .frame(width: 4, height: 4).offset(x: 12)
                                    .accessibilityHidden(true)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityValue(Text(selected ? LocalizedStringKey("Berikutnya") : prayer.hasStarted(at: date) ? LocalizedStringKey("Sudah lewat") : LocalizedStringKey("")))
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
            HStack {
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
                Spacer(minLength: 8)
                Text(PrayerMonth.attribution + " · " + zone.label)
                    .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                    .lineLimit(1)
                if isNotch {
                    Spacer(minLength: 8)
                    SettingsLink { Image(systemName: "gearshape").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                        .simultaneousGesture(TapGesture().onEnded { NSApplication.shared.activate() })
                        .accessibilityLabel("Pengaturan dan pilihan kota").help("Pengaturan dan pilihan kota")
                }
            }
            .font(.system(size: 12))
        }
        .buttonStyle(NidaButtonStyle()).tint(.clear)
        .padding(.horizontal, 30).padding(.vertical, 20)
        .task(id: ScheduleMonth.dateKey(date, in: zone)) { await store.restoreAndRefresh() }
    }
}
