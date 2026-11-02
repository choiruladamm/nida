import Foundation

enum PrayerDataError: Error, LocalizedError, Equatable {
    case invalidData
    case unsupportedProvince(String)
    case http(Int)
    case rateLimited(Date)
    case network
    case cacheRead
    case cacheWrite

    var errorDescription: String? { message.localized(in: AppLanguage.indonesian.locale) }

    var message: LocalizedStringResource {
        switch self {
        case .invalidData: "Data jadwal tidak valid. Coba perbarui lagi."
        case .unsupportedProvince: "Zona waktu wilayah ini belum dikenali. Pilih wilayah lain."
        case .http: "Layanan jadwal belum tersedia. Coba lagi nanti."
        case .rateLimited: "Batas permintaan tercapai. Tunggu sebentar sebelum memperbarui."
        case .network: "Tidak dapat menghubungi layanan jadwal. Periksa koneksi internet."
        case .cacheRead: "Jadwal tersimpan tidak dapat dibaca. Sambungkan internet untuk memperbarui."
        case .cacheWrite: "Jadwal terunduh, tetapi belum dapat disimpan untuk offline."
        }
    }
}

struct PrayerCity: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    enum CodingKeys: String, CodingKey { case id; case name = "lokasi" }

    func validate() throws {
        guard id.count == 32, id.allSatisfy({ "0123456789abcdef".contains($0) }),
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PrayerDataError.invalidData
        }
    }
}

// Display aliases keep provider IDs and names intact for requests and cache validation.
struct PrayerCityChoice: Identifiable {
    let city: PrayerCity
    let name: String
    var id: String { city.id + ":" + name }

    static let jakartaDistricts = ["Jakarta Barat", "Jakarta Pusat", "Jakarta Selatan", "Jakarta Timur", "Jakarta Utara"]

    static func displayName(_ name: String) -> String {
        jakartaDistricts.first { district in
            [district, "Kota " + district, "Kota Administrasi " + district]
                .contains { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }
        } ?? name
    }

    static func choices(for cities: [PrayerCity]) -> [Self] {
        cities.flatMap { city in
            let names = city.name == "KOTA JAKARTA"
                ? jakartaDistricts : [city.name.localizedCapitalized]
            return names.map { Self(city: city, name: $0) }
        }
    }
}

enum IndonesianZone: String, Codable, Sendable {
    case west = "Asia/Jakarta", central = "Asia/Makassar", east = "Asia/Jayapura"

    var timeZone: TimeZone {
        guard let zone = TimeZone(identifier: rawValue) else {
            preconditionFailure("The system must support Indonesian IANA time zones.")
        }
        return zone
    }

    var label: String {
        switch self { case .west: "WIB"; case .central: "WITA"; case .east: "WIT" }
    }

    static func forProvince(_ province: String) throws -> Self {
        switch province.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "ACEH", "SUMATERA UTARA", "SUMATERA BARAT", "RIAU", "KEPULAUAN RIAU", "JAMBI",
             "BENGKULU", "SUMATERA SELATAN", "KEPULAUAN BANGKA BELITUNG", "BANGKA BELITUNG",
             "LAMPUNG", "BANTEN", "DKI JAKARTA", "JAWA BARAT", "JAWA TENGAH", "DI YOGYAKARTA",
             "DAERAH ISTIMEWA YOGYAKARTA", "JAWA TIMUR", "KALIMANTAN BARAT", "KALIMANTAN TENGAH": .west
        case "BALI", "NUSA TENGGARA BARAT", "NUSA TENGGARA TIMUR", "KALIMANTAN SELATAN",
             "KALIMANTAN TIMUR", "KALIMANTAN UTARA", "SULAWESI UTARA", "SULAWESI TENGAH",
             "SULAWESI BARAT", "SULAWESI SELATAN", "SULAWESI TENGGARA", "GORONTALO": .central
        case "MALUKU", "MALUKU UTARA", "PAPUA", "PAPUA BARAT", "PAPUA BARAT DAYA",
             "PAPUA SELATAN", "PAPUA TENGAH", "PAPUA PEGUNUNGAN": .east
        default: throw PrayerDataError.unsupportedProvince(province)
        }
    }
}

struct PrayerLocation: Codable, Equatable, Sendable {
    let city: PrayerCity
    let province: String
    let zone: IndonesianZone

    func validate() throws {
        try city.validate()
        guard try zone == IndonesianZone.forProvince(province) else { throw PrayerDataError.invalidData }
    }
}

struct ScheduleMonth: Codable, Equatable, Hashable, Sendable {
    let year: Int
    let month: Int
    var key: String { String(format: "%04d-%02d", year, month) }
    var next: Self { month == 12 ? Self(year: year + 1, month: 1) : Self(year: year, month: month + 1) }

    init(year: Int, month: Int) { self.year = year; self.month = month }

    init(containing date: Date, in zone: IndonesianZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone.timeZone
        year = calendar.component(.year, from: date)
        month = calendar.component(.month, from: date)
    }

    func dateKeys() throws -> Set<String> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard (1...9999).contains(year), (1...12).contains(month),
              let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = calendar.range(of: .day, in: .month, for: first) else {
            throw PrayerDataError.invalidData
        }
        return Set(days.map { key + String(format: "-%02d", $0) })
    }

    static func dateKey(_ date: Date, in zone: IndonesianZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone.timeZone
        return Self(containing: date, in: zone).key + String(format: "-%02d", calendar.component(.day, from: date))
    }
}

enum PrayerKind: String, CaseIterable, Codable, Sendable {
    case subuh, dzuhur, ashar, maghrib, isya
    var label: LocalizedStringResource {
        switch self {
        case .subuh: "Subuh"
        case .dzuhur: "Dzuhur"
        case .ashar: "Ashar"
        case .maghrib: "Maghrib"
        case .isya: "Isya"
        }
    }
}

struct PrayerDay: Codable, Equatable, Sendable {
    let subuh: String
    let dzuhur: String
    let ashar: String
    let maghrib: String
    let isya: String

    var times: [String] { PrayerKind.allCases.map { time(for: $0) } }

    func time(for prayer: PrayerKind) -> String {
        switch prayer {
        case .subuh: subuh
        case .dzuhur: dzuhur
        case .ashar: ashar
        case .maghrib: maghrib
        case .isya: isya
        }
    }

    func validate() throws {
        let minutes = try times.map { time -> Int in
            let bytes = Array(time.utf8)
            guard bytes.count == 5, bytes[2] == 58,
                  [0, 1, 3, 4].allSatisfy({ (48...57).contains(bytes[$0]) }) else {
                throw PrayerDataError.invalidData
            }
            let hour = Int(bytes[0] - 48) * 10 + Int(bytes[1] - 48)
            let minute = Int(bytes[3] - 48) * 10 + Int(bytes[4] - 48)
            guard hour < 24, minute < 60 else { throw PrayerDataError.invalidData }
            return hour * 60 + minute
        }
        guard zip(minutes, minutes.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw PrayerDataError.invalidData
        }
    }
}

struct PrayerMonth: Codable, Equatable, Sendable {
    static let providerID = "myquran-v3"
    static let attribution = "Kemenag via myQuran"
    let provider: String
    let location: PrayerLocation
    let period: ScheduleMonth
    let retrievedAt: Date
    let days: [String: PrayerDay]

    func validate(city: PrayerCity, period: ScheduleMonth) throws {
        try location.validate()
        guard provider == Self.providerID, location.city == city, self.period == period,
              Set(days.keys) == (try period.dateKeys()) else { throw PrayerDataError.invalidData }
        for day in days.values { try day.validate() }
    }

    func day(at date: Date) -> PrayerDay? {
        days[ScheduleMonth.dateKey(date, in: location.zone)]
    }
}
