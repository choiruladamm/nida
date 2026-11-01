import Foundation

struct PrayerAPI: Sendable {
    var load: @Sendable (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }

    private struct Envelope<Value: Decodable>: Decodable {
        let status: Bool
        let data: Value?
    }

    private struct MonthPayload: Decodable {
        let id: String
        let kabko: String
        let prov: String
        let jadwal: [String: PrayerDay]
    }

    func cities() async throws -> [PrayerCity] {
        let cities: [PrayerCity] = try await get("sholat/kabkota/semua")
        try validateCities(cities)
        return cities
    }

    func month(city: PrayerCity, period: ScheduleMonth, now: Date) async throws -> PrayerMonth {
        try city.validate()
        _ = try period.dateKeys()
        let payload: MonthPayload = try await get("sholat/jadwal/\(city.id)/\(period.key)")
        guard payload.id == city.id, payload.kabko == city.name else { throw PrayerDataError.invalidData }
        let location = PrayerLocation(city: city, province: payload.prov,
                                      zone: try IndonesianZone.forProvince(payload.prov))
        let month = PrayerMonth(provider: PrayerMonth.providerID, location: location,
                                period: period, retrievedAt: now, days: payload.jadwal)
        try month.validate(city: city, period: period)
        return month
    }

    private func get<Value: Decodable>(_ path: String) async throws -> Value {
        let url = URL(string: "https://api.myquran.com/v3/")!.appending(path: path)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Nida/0.1 (+https://github.com/choiruladamm/nida)", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do { (data, response) = try await load(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw PrayerDataError.network }
        guard let http = response as? HTTPURLResponse else { throw PrayerDataError.invalidData }
        if http.statusCode == 429 {
            let retry = http.value(forHTTPHeaderField: "Retry-After")
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            let until = retry.flatMap(Double.init).flatMap { seconds in
                seconds.isFinite && seconds >= 0 ? Date().addingTimeInterval(max(1, seconds)) : nil
            }
                ?? retry.flatMap { formatter.date(from: $0) } ?? Date().addingTimeInterval(60)
            throw PrayerDataError.rateLimited(until)
        }
        guard (200...299).contains(http.statusCode) else { throw PrayerDataError.http(http.statusCode) }
        do {
            let envelope = try JSONDecoder().decode(Envelope<Value>.self, from: data)
            guard envelope.status, let value = envelope.data else { throw PrayerDataError.invalidData }
            return value
        } catch { throw PrayerDataError.invalidData }
    }
}

private func validateCities(_ cities: [PrayerCity]) throws {
    guard !cities.isEmpty, Set(cities.map(\.id)).count == cities.count else { throw PrayerDataError.invalidData }
    for city in cities { try city.validate() }
}

struct PrayerCache: Sendable {
    var directory: URL = .applicationSupportDirectory.appending(path: "Nida/PrayerSchedules")

    struct Catalog: Codable, Sendable {
        let provider: String
        let retrievedAt: Date
        let cities: [PrayerCity]
    }

    func loadCities() throws -> Catalog? {
        guard let data = try read("cities.json") else { return nil }
        do {
            let catalog = try JSONDecoder().decode(Catalog.self, from: data)
            guard catalog.provider == PrayerMonth.providerID else { throw PrayerDataError.invalidData }
            try validateCities(catalog.cities)
            return catalog
        } catch { throw PrayerDataError.cacheRead }
    }

    func saveCities(_ catalog: Catalog) throws {
        guard catalog.provider == PrayerMonth.providerID else { throw PrayerDataError.invalidData }
        try validateCities(catalog.cities)
        try write(JSONEncoder().encode(catalog), name: "cities.json")
    }

    func load(city: PrayerCity, period: ScheduleMonth) throws -> PrayerMonth? {
        try city.validate()
        _ = try period.dateKeys()
        guard let data = try read("\(city.id)-\(period.key).json") else { return nil }
        do {
            let month = try JSONDecoder().decode(PrayerMonth.self, from: data)
            try month.validate(city: city, period: period)
            return month
        } catch { throw PrayerDataError.cacheRead }
    }

    func save(_ month: PrayerMonth) throws {
        try month.validate(city: month.location.city, period: month.period)
        try write(JSONEncoder().encode(month), name: "\(month.location.city.id)-\(month.period.key).json")
    }

    private func read(_ name: String) throws -> Data? {
        do { return try Data(contentsOf: directory.appending(path: PrayerMonth.providerID).appending(path: name)) }
        catch CocoaError.fileReadNoSuchFile { return nil }
        catch { throw PrayerDataError.cacheRead }
    }

    private func write(_ data: Data, name: String) throws {
        do {
            let folder = directory.appending(path: PrayerMonth.providerID)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appending(path: name), options: .atomic)
        } catch { throw PrayerDataError.cacheWrite }
    }
}

actor PrayerRepository {
    struct MonthResult: Sendable {
        let month: PrayerMonth
        var issue: PrayerDataError?
    }

    private let api: PrayerAPI
    private let cache: PrayerCache
    private var flights: [String: Task<MonthResult, Error>] = [:]
    private var citiesFlight: Task<[PrayerCity], Error>?
    private var blockedUntil: Date?

    init(api: PrayerAPI = PrayerAPI(), cache: PrayerCache = PrayerCache()) {
        self.api = api
        self.cache = cache
    }

    func cities(now: Date = Date()) async throws -> [PrayerCity] {
        if let citiesFlight { return try await citiesFlight.value }
        let saved = try? cache.loadCities()
        if let saved, (0..<86_400).contains(now.timeIntervalSince(saved.retrievedAt)) { return saved.cities }
        let flight = Task { [api, cache] in
            do {
                let cities = try await api.cities()
                // The catalog is recoverable; month writes separately report lost offline availability.
                try? cache.saveCities(.init(provider: PrayerMonth.providerID, retrievedAt: now, cities: cities))
                return cities
            } catch {
                if let saved { return saved.cities }
                throw error
            }
        }
        citiesFlight = flight
        defer { citiesFlight = nil }
        return try await flight.value
    }

    func cached(city: PrayerCity, period: ScheduleMonth) throws -> PrayerMonth? {
        try cache.load(city: city, period: period)
    }

    func month(city: PrayerCity, period: ScheduleMonth, force: Bool = false, now: Date = Date()) async throws -> MonthResult {
        try city.validate()
        _ = try period.dateKeys()
        let key = city.id + "-" + period.key
        if let flight = flights[key] { return try await flight.value }
        let saved = try? cache.load(city: city, period: period)
        if !force, let saved,
           ScheduleMonth.dateKey(saved.retrievedAt, in: saved.location.zone) == ScheduleMonth.dateKey(now, in: saved.location.zone) {
            return MonthResult(month: saved)
        }
        if let blockedUntil, blockedUntil > now {
            if let saved { return MonthResult(month: saved, issue: .rateLimited(blockedUntil)) }
            throw PrayerDataError.rateLimited(blockedUntil)
        }
        let flight = Task { [api, cache] in
            do {
                let remote = try await api.month(city: city, period: period, now: now)
                do { try cache.save(remote) }
                catch { return MonthResult(month: remote, issue: .cacheWrite) }
                return MonthResult(month: remote)
            } catch {
                if case PrayerDataError.rateLimited(let until) = error { self.blockedUntil = until }
                if let saved { return MonthResult(month: saved, issue: (error as? PrayerDataError) ?? .network) }
                throw error
            }
        }
        flights[key] = flight
        defer { flights[key] = nil }
        return try await flight.value
    }
}

#if DEBUG
extension PrayerRepository {
    static func liveSmokeCheck() async throws -> String {
        let directory = FileManager.default.temporaryDirectory.appending(path: "NidaDataSmoke-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let api = PrayerAPI()
        let cities = try await api.cities()
        guard let city = cities.first(where: { $0.name == "KOTA JAKARTA" }) else { throw PrayerDataError.invalidData }
        let cache = PrayerCache(directory: directory)
        let online = PrayerRepository(api: api, cache: cache)
        let now = Date()
        let current = ScheduleMonth(containing: now, in: .west)
        let offline = PrayerRepository(api: PrayerAPI(load: { _ in throw URLError(.notConnectedToInternet) }), cache: cache)
        var count = 0
        for period in [current, current.next] {
            let fetched = try await online.month(city: city, period: period, now: now)
            let restored = try await offline.month(city: city, period: period, force: true, now: now)
            guard fetched.issue == nil, restored.issue == .network, restored.month == fetched.month else {
                throw PrayerDataError.invalidData
            }
            count += restored.month.days.count
        }
        return "Nida data smoke: \(cities.count) cities, \(count) validated days, two months restored offline, \(PrayerMonth.attribution). Temporary cache removed; selected city unchanged."
    }
}
#endif
