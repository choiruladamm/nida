import SwiftUI

// Fixed fixtures make it impossible to mistake a live calculation for a validated schedule.
struct ScheduleView: View {
    var onClose: (() -> Void)?
    private let prayers: [(name: String, time: String, symbol: String)] = [
        ("Subuh", "04.15", "sun.horizon"),
        ("Dzuhur", "11.40", "sun.max"),
        ("Ashar", "15.12", "sun.haze"),
        ("Maghrib", "17.48", "sunset"),
        ("Isya", "19.00", "moon.stars")
    ]
    private let sage = Color(red: 0.75, green: 0.82, blue: 0.67)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nida").font(.system(size: 17, weight: .semibold))
                    Text("Jakarta · Minggu, 1 November")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Tutup jadwal")
                }
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SHOLAT BERIKUTNYA").font(.system(size: 9, weight: .medium)).tracking(1.5)
                        .foregroundStyle(.secondary)
                    Text("Ashar").font(.system(size: 27, weight: .semibold))
                }
                Spacer()
                Text("15.12").font(.system(size: 31, weight: .light, design: .rounded))
                    .monospacedDigit().foregroundStyle(sage)
            }
            Divider()
            VStack(spacing: 3) {
                ForEach(prayers, id: \.name) { prayer in
                    HStack(spacing: 12) {
                        Image(systemName: prayer.symbol).frame(width: 18)
                            .accessibilityHidden(true)
                        Text(prayer.name)
                        Spacer()
                        Text(prayer.time).monospacedDigit()
                        if prayer.name == "Ashar" {
                            Circle().fill(sage).frame(width: 4, height: 4)
                                .accessibilityHidden(true)
                        } else {
                            Color.clear.frame(width: 4, height: 4)
                        }
                    }
                    .font(.system(size: 12, weight: prayer.name == "Ashar" ? .semibold : .regular))
                    .foregroundStyle(prayer.name == "Ashar" ? sage : .white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .frame(height: 31)
                    .background(prayer.name == "Ashar" ? sage.opacity(0.1) : .clear,
                                in: .rect(cornerRadius: 8))
                    .accessibilityElement(children: .combine)
                }
            }
            Label("Data contoh · Belum terhubung ke jadwal asli", systemImage: "info.circle")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}
