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
        .frame(height: isNotch ? 326 : nil)
        .foregroundStyle(NidaStyle.text)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            Task { await store.restoreAndRefresh() }
        }
    }

    private func content(at date: Date, timeline: PrayerTimeline?) -> some View {
        let snapshot = timeline?.snapshot(at: date)
        let zone = store.location?.zone ?? .west
        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.location?.city.name.localizedCapitalized ?? "Nida")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(date.formatted(Date.FormatStyle(locale: Locale(identifier: "id_ID"), timeZone: zone.timeZone)
                        .weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) { Image(systemName: "xmark").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                        .accessibilityLabel("Tutup jadwal").help("Tutup jadwal · Escape")
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let next = snapshot?.next {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                let tomorrow = next.id.dateKey != ScheduleMonth.dateKey(date, in: zone)
                                Text(next.id.prayer.label + (tomorrow ? " · besok" : ""))
                                    .font(.system(size: isNotch ? 21 : 26, weight: .semibold))
                                Text(next.startsAt, style: .timer).monospacedDigit()
                                    .font(.system(size: 12)).foregroundStyle(NidaStyle.secondaryText)
                                    .accessibilityLabel("Sisa waktu menuju sholat berikutnya")
                                    .accessibilityValue(Text(next.startsAt, style: .timer))
                            }
                            Spacer()
                            Text(next.wallTime).monospacedDigit()
                                .font(.system(size: isNotch ? 26 : 30, weight: .light))
                        }
                    } else if snapshot?.hasToday == true {
                        Text("Jadwal Subuh besok belum tersedia.").font(.callout)
                    }
                    if let snapshot, snapshot.hasToday {
                        VStack(spacing: 3) {
                            ForEach(snapshot.today) { prayer in
                                let selected = snapshot.next?.id == prayer.id
                                HStack {
                                    Text(prayer.id.prayer.label)
                                    Spacer()
                                    Text(prayer.wallTime).monospacedDigit()
                                    Circle().fill(selected ? NidaStyle.accent : .clear)
                                        .frame(width: 4, height: 4).accessibilityHidden(true)
                                }
                                .font(.system(size: isNotch ? 12 : 13, weight: selected ? .semibold : .regular))
                                .foregroundStyle(prayer.hasStarted(at: date) && contrast != .increased ? NidaStyle.secondaryText : NidaStyle.text)
                                .padding(.horizontal, 10).frame(height: isNotch ? 26 : 30)
                                .background(selected ? .black.opacity(0.12) : .clear,
                                            in: .rect(cornerRadius: NidaStyle.rowRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: NidaStyle.rowRadius)
                                        .strokeBorder(selected && contrast == .increased ? NidaStyle.text : .clear, lineWidth: 1)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityValue(selected ? "Berikutnya" : prayer.hasStarted(at: date) ? "Sudah lewat" : "")
                            }
                        }
                        Text(PrayerMonth.attribution + " · " + zone.label)
                            .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                    } else if store.isRefreshing {
                        ProgressView("Memuat jadwal…").controlSize(.small)
                    } else {
                        Text(store.location == nil ? "Pilih kota di Pengaturan untuk mulai." : "Jadwal tanggal ini belum tersedia. Coba perbarui.")
                            .font(.callout).foregroundStyle(NidaStyle.secondaryText)
                    }
                    if let message = store.message {
                        Text((snapshot?.hasToday == true ? "Jadwal tetap ditampilkan · " : "") + message)
                            .font(.system(size: 11)).foregroundStyle(NidaStyle.secondaryText)
                    }
                }
            }
            .scrollIndicators(.hidden)
            HStack {
                if store.isRefreshing { ProgressView().controlSize(.mini) }
                else {
                    Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                        .disabled(store.location == nil).accessibilityLabel("Perbarui jadwal").help("Perbarui jadwal")
                }
                Spacer()
                SettingsLink { Image(systemName: "gearshape").frame(width: NidaStyle.iconControlSize, height: NidaStyle.iconControlSize) }
                    .simultaneousGesture(TapGesture().onEnded { NSApplication.shared.activate() })
                    .accessibilityLabel("Pengaturan dan pilihan kota").help("Pengaturan dan pilihan kota")
            }
            .font(.system(size: 12))
        }
        .buttonStyle(NidaButtonStyle()).tint(.clear)
        .padding(.horizontal, isNotch ? 30 : 24).padding(.vertical, 12)
        .task(id: ScheduleMonth.dateKey(date, in: zone)) { await store.restoreAndRefresh() }
    }
}
