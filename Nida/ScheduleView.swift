import SwiftUI

// Fixtures only: the next-prayer state is intentionally not a live calculation.
struct ScheduleView: View {
    var onClose: (() -> Void)?
    private let prayers: [(name: String, time: String, symbol: String)] = [
        ("Subuh", "04.15", "sun.horizon"),
        ("Dzuhur", "11.40", "sun.max"),
        ("Ashar", "15.12", "sun.haze"),
        ("Maghrib", "17.48", "sunset"),
        ("Isya", "19.00", "moon.stars")
    ]

    private var isNotch: Bool { onClose != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: NidaStyle.groupGap) {
                if isNotch {
                    Text("Jakarta · Hari ini")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NidaStyle.secondaryText)
                } else {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 15, weight: .medium))
                        .accessibilityHidden(true)
                    Text("Nida").font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(.clear)
                    .accessibilityLabel("Tutup jadwal")
                } else {
                    Text("Preview")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NidaStyle.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(NidaStyle.raised, in: .capsule)
                }
            }
            .frame(height: 28)
            .padding(.horizontal, isNotch ? 30 : NidaStyle.panelInset)
            .padding(.top, 12)
            .padding(.bottom, isNotch ? 0 : 12)
            .background(isNotch ? .clear : .white.opacity(0.04))

            if !isNotch { NidaStyle.hairline.frame(height: 0.5) }

            VStack(alignment: .leading, spacing: isNotch ? 12 : NidaStyle.sectionGap) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ashar").font(.system(size: isNotch ? 21 : 26, weight: .semibold))
                        Text(isNotch ? "Sholat berikutnya" : "Berikutnya · Jakarta")
                            .font(.system(size: 12))
                            .foregroundStyle(NidaStyle.secondaryText)
                    }
                    Spacer()
                    Text("15.12").font(.system(size: isNotch ? 26 : 30, weight: .light))
                        .monospacedDigit()
                }

                VStack(spacing: 4) {
                    ForEach(prayers, id: \.name) { prayer in
                        HStack(spacing: NidaStyle.groupGap) {
                            Image(systemName: prayer.symbol).frame(width: 18)
                                .foregroundStyle(NidaStyle.secondaryText)
                                .accessibilityHidden(true)
                            Text(prayer.name)
                            Spacer()
                            Text(prayer.time).monospacedDigit()
                            Circle()
                                .fill(prayer.name == "Ashar" ? NidaStyle.accent : .clear)
                                .frame(width: 4, height: 4)
                                .accessibilityHidden(true)
                        }
                        .font(.system(size: isNotch ? 12 : 13, weight: prayer.name == "Ashar" ? .medium : .regular))
                        .padding(.horizontal, 12)
                        .frame(height: isNotch ? 28 : 34)
                        .background(prayer.name == "Ashar" ? .black.opacity(0.12) : .clear,
                                    in: .rect(cornerRadius: NidaStyle.rowRadius))
                        .accessibilityElement(children: .combine)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if isNotch {
                        Text("Data contoh · Jadwal belum aktif")
                    } else {
                        Text("Minggu, 1 November · Data contoh")
                        Text("Belum terhubung ke jadwal asli.")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(NidaStyle.secondaryText)
            }
            .padding(.horizontal, isNotch ? 30 : NidaStyle.panelInset)
            .padding(.vertical, isNotch ? 20 : NidaStyle.panelInset)
        }
        .foregroundStyle(NidaStyle.text)
    }
}
