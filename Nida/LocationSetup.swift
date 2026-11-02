import CoreLocation
import MapKit
import Observation

struct DetectedArea: Equatable, Sendable {
    let city: String
    let countryCode: String

    static func match(_ areas: [Self], cities: [PrayerCity]) throws -> PrayerCity {
        guard !areas.isEmpty, areas.allSatisfy({ $0.countryCode == "ID" }) else {
            throw LocationSetupError.unsupported
        }
        // The provider groups these five administrative cities under KOTA JAKARTA.
        let jakartaAreas: Set<String> = [
            "kota administrasi jakarta pusat", "kota administrasi jakarta selatan",
            "kota administrasi jakarta utara", "kota administrasi jakarta barat",
            "kota administrasi jakarta timur"
        ]
        func normalized(_ name: String) -> String {
            let value = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "id_ID"))
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: " ")
            if jakartaAreas.contains(value) { return "kota jakarta" }
            return value.hasPrefix("kab ") ? "kabupaten " + value.dropFirst(4) : value
        }
        func base(_ name: String) -> String {
            for prefix in ["kota ", "kabupaten ", "kab "] where name.hasPrefix(prefix) {
                return String(name.dropFirst(prefix.count))
            }
            return name
        }
        var matches: [String: PrayerCity] = [:]
        for area in areas {
            let name = normalized(area.city)
            guard !name.isEmpty else { throw LocationSetupError.unsupported }
            let exact = cities.filter { normalized($0.name) == name }
            let hasType = name.hasPrefix("kota ") || name.hasPrefix("kabupaten ")
            let candidates = exact.isEmpty && !hasType ? cities.filter { base(normalized($0.name)) == name } : exact
            guard !candidates.isEmpty else { throw LocationSetupError.unsupported }
            for city in candidates { matches[city.id] = city }
        }
        guard matches.count == 1, let city = matches.values.first else { throw LocationSetupError.ambiguous }
        try city.validate()
        return city
    }
}

enum LocationSetupError: Error, LocalizedError, Equatable {
    case denied, unavailable, unsupported, ambiguous

    var errorDescription: String? { message.localized(in: AppLanguage.indonesian.locale) }

    var message: LocalizedStringResource {
        switch self {
        case .denied: "Akses lokasi tidak diizinkan. Pilih kota manual, atau izinkan Nida di Pengaturan Sistem → Privasi & Keamanan → Layanan Lokasi."
        case .unavailable: "Lokasi belum bisa ditemukan. Coba lagi atau pilih kota manual."
        case .unsupported: "Wilayah ini belum cocok dengan daftar jadwal Indonesia. Pilih kota atau kabupaten manual."
        case .ambiguous: "Ada lebih dari satu wilayah yang cocok. Pilih kota atau kabupaten manual agar jadwal tepat."
        }
    }
}

@MainActor @Observable
final class LocationDetection {
    enum State: Equatable {
        case idle, locating, failed(LocationSetupError)
        case found(city: PrayerCity, detectedNames: [String])
    }
    private(set) var state: State = .idle
    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private let lookup: @MainActor () async throws -> [DetectedArea]

    init(lookup: @escaping @MainActor () async throws -> [DetectedArea] = { try await OneShotLocation().lookup() }) {
        self.lookup = lookup
    }

    @discardableResult
    func start(cities: @escaping @MainActor () async throws -> [PrayerCity]) -> Task<Void, Never> {
        cancel()
        let id = requestID
        state = .locating
        let work = Task {
            do {
                let catalog = try await cities()
                try Task.checkCancellation()
                let areas = try await lookup()
                try Task.checkCancellation()
                let city = try DetectedArea.match(areas, cities: catalog)
                guard requestID == id else { return }
                state = .found(city: city, detectedNames: Array(Set(areas.map(\.city))).sorted())
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                state = .failed(error as? LocationSetupError ?? .unavailable)
            }
        }
        task = work
        return work
    }

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        state = .idle
    }
}

@MainActor
private final class OneShotLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<[DetectedArea], any Error>?
    private var timeout: Task<Void, Never>?
    private var geocoder: MKReverseGeocodingRequest?
    private var requested = false
    private var requestedAuthorization = false

    func lookup() async throws -> [DetectedArea] {
        try Task.checkCancellation()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyKilometer
                timeout = Task {
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    finish(.failure(LocationSetupError.unavailable))
                }
                authorize()
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    private func authorize() {
        guard continuation != nil, !requested else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            if !requestedAuthorization {
                requestedAuthorization = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways:
            requested = true
            manager.requestLocation()
        case .denied, .restricted: finish(.failure(LocationSetupError.denied))
        @unknown default: finish(.failure(LocationSetupError.unavailable))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { authorize() }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let denied = (error as? CLError)?.code == .denied
        finish(.failure(denied ? LocationSetupError.denied : .unavailable))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard continuation != nil, geocoder == nil else { return }
        guard let location = locations.last, location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= 10_000, abs(location.timestamp.timeIntervalSinceNow) <= 120,
              let request = MKReverseGeocodingRequest(location: location) else {
            finish(.failure(LocationSetupError.unavailable))
            return
        }
        request.preferredLocale = Locale(identifier: "id_ID")
        geocoder = request
        request.getMapItems { [weak self] items, error in
            guard let self, self.continuation != nil else { return }
            guard error == nil, let items, !items.isEmpty else {
                self.finish(.failure(LocationSetupError.unavailable))
                return
            }
            let areas = items.map {
                DetectedArea(city: $0.addressRepresentations?.cityName ?? "",
                             countryCode: $0.addressRepresentations?.region?.identifier ?? "")
            }
            self.finish(.success(areas))
        }
    }

    private func finish(_ result: Result<[DetectedArea], any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        manager.stopUpdatingLocation()
        manager.delegate = nil
        geocoder?.cancel()
        geocoder = nil
        continuation.resume(with: result)
    }
}
