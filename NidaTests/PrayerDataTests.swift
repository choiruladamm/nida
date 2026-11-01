import Foundation
import Testing
@testable import Nida

private let jakarta = PrayerCity(id: "58a2fc6ed39fd083f55d4182bf88826d", name: "KOTA JAKARTA")
private let denpasar = PrayerCity(id: "6a9aeddfc689c1d0e3b9ccc3ab651bc5", name: "KOTA DENPASAR")
private let november = ScheduleMonth(year: 2026, month: 11)
private let referenceDate = Date(timeIntervalSince1970: 1_793_491_200) // 2026-11-01 00:00 UTC

private func path(_ city: PrayerCity = jakarta, _ month: ScheduleMonth = november) -> String {
    "/v3/sholat/jadwal/\(city.id)/\(month.key)"
}

private func payload(city: PrayerCity = jakarta, month: ScheduleMonth = november,
                     invalid: String? = nil) throws -> Data {
    let valid = ["subuh": "04:09", "dzuhur": "11:40", "ashar": "14:55", "maghrib": "17:49", "isya": "19:00"]
    var days = Dictionary(uniqueKeysWithValues: try month.dateKeys().map { ($0, valid) })
    let first = month.key + "-01"
    switch invalid {
    case "missing-day": days.removeValue(forKey: first)
    case "wrong-date": days["2025-11-01"] = days.removeValue(forKey: first)
    case "invalid-time": days[first]?["subuh"] = "24:90"
    case "loose-time": days[first]?["subuh"] = "4:09"
    case "reversed": days[first]?["ashar"] = "11:30"
    case "equal": days[first]?["ashar"] = "11:40"
    case "missing-time": days[first]?.removeValue(forKey: "isya")
    default: break
    }
    var data: [String: Any] = ["id": city.id, "kabko": city.name,
                              "prov": city == denpasar ? "BALI" : "DKI JAKARTA", "jadwal": days]
    if invalid == "wrong-city" { data["id"] = denpasar.id }
    if invalid == "wrong-name" { data["kabko"] = "KOTA SALAH" }
    if invalid == "unknown-province" { data["prov"] = "UNRECOGNIZED" }
    return try JSONSerialization.data(withJSONObject: ["status": invalid != "false-status", "data": data])
}

private actor TransportStub {
    struct Reply: Sendable {
        let body: Data
        var status = 200
        var headers: [String: String] = [:]
    }
    var replies: [String: Reply] = [:]
    var offline = false
    var requests: [String] = []
    var heldPath: String?
    private var didHold = false
    private var held: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?

    func set(_ path: String, body: Data, status: Int = 200, headers: [String: String] = [:]) {
        replies[path] = Reply(body: body, status: status, headers: headers)
    }
    func setOffline() { offline = true }
    func hold(_ path: String) { heldPath = path }
    func waitUntilHeld() async {
        if didHold { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { held?.resume(); held = nil; heldPath = nil }

    func response(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let url = try #require(request.url)
        requests.append(url.path)
        if url.path == heldPath {
            didHold = true
            observer?.resume(); observer = nil
            await withCheckedContinuation { held = $0 }
        }
        if offline { throw URLError(.notConnectedToInternet) }
        let reply = try #require(replies[url.path])
        let response = try #require(HTTPURLResponse(url: url, statusCode: reply.status,
                                                   httpVersion: nil, headerFields: reply.headers))
        return (reply.body, response)
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "NidaTests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Suite struct ProviderContractTests {
    @Test(arguments: ["missing-day", "wrong-date", "invalid-time", "loose-time", "reversed", "equal",
                      "missing-time", "wrong-city", "wrong-name", "false-status", "unknown-province"])
    func rejectsUntrustedPayloads(reason: String) async throws {
        let stub = TransportStub()
        await stub.set(path(), body: try payload(invalid: reason))
        let api = PrayerAPI(load: { try await stub.response($0) })
        let expected: PrayerDataError = reason == "unknown-province" ? .unsupportedProvince("UNRECOGNIZED") : .invalidData
        await #expect(throws: expected) { try await api.month(city: jakarta, period: november, now: referenceDate) }
    }

    @Test func handlesHTTPFailureAndMalformedJSON() async throws {
        let stub = TransportStub()
        let api = PrayerAPI(load: { try await stub.response($0) })
        await stub.set(path(), body: Data(), status: 503)
        await #expect(throws: PrayerDataError.http(503)) { try await api.month(city: jakarta, period: november, now: referenceDate) }
        await stub.set(path(), body: Data("not-json".utf8))
        await #expect(throws: PrayerDataError.invalidData) { try await api.month(city: jakarta, period: november, now: referenceDate) }
    }

    @Test func validatesCatalogAndRejectsDuplicateIDs() async throws {
        let stub = TransportStub()
        let endpoint = "/v3/sholat/kabkota/semua"
        let api = PrayerAPI(load: { try await stub.response($0) })
        let cities = try JSONSerialization.data(withJSONObject: ["status": true, "data": [
            ["id": jakarta.id, "lokasi": jakarta.name], ["id": jakarta.id, "lokasi": jakarta.name]
        ]])
        await stub.set(endpoint, body: cities)
        await #expect(throws: PrayerDataError.invalidData) { try await api.cities() }
    }

    @Test func mapsProvincesAndUsesCityTimeZoneAtMonthBoundary() throws {
        #expect(try IndonesianZone.forProvince("KALIMANTAN TENGAH") == .west)
        #expect(try IndonesianZone.forProvince("KALIMANTAN TIMUR") == .central)
        #expect(try IndonesianZone.forProvince("PAPUA PEGUNUNGAN") == .east)
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-31T16:00:00Z"))
        #expect(ScheduleMonth.dateKey(instant, in: .west) == "2026-10-31")
        #expect(ScheduleMonth.dateKey(instant, in: .central) == "2026-11-01")
        #expect(ScheduleMonth.dateKey(instant, in: .east) == "2026-11-01")
        #expect(ScheduleMonth(year: 2026, month: 12).next == ScheduleMonth(year: 2027, month: 1))
        #expect(try ScheduleMonth(year: 2024, month: 2).dateKeys().count == 29)
        #expect(try ScheduleMonth(year: 2100, month: 2).dateKeys().count == 28)
    }
}

@Suite struct OfflineStorageTests {
    @Test func roundTripAndOfflineRefreshPreserveExactDates() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = PrayerCache(directory: folder)
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: cache)
        let fetched = try await repo.month(city: jakarta, period: november, now: referenceDate)
        #expect(fetched.month.location.zone == .west)
        #expect(try cache.load(city: jakarta, period: november) == fetched.month)
        await stub.setOffline()
        let offline = try await repo.month(city: jakarta, period: november, force: true, now: referenceDate)
        #expect(offline.issue == .network)
        #expect(offline.month == fetched.month)
        #expect(offline.month.day(at: referenceDate)?.subuh == "04:09")
        let missing = try #require(ISO8601DateFormatter().date(from: "2026-12-01T00:00:00Z"))
        #expect(offline.month.day(at: missing) == nil)
        #expect(try cache.load(city: jakarta, period: november.next) == nil)
    }

    @Test func badRefreshCannotOverwriteKnownGoodCache() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = PrayerCache(directory: folder)
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: cache)
        let good = try await repo.month(city: jakarta, period: november, now: referenceDate).month
        await stub.set(path(), body: try payload(invalid: "wrong-city"))
        let result = try await repo.month(city: jakarta, period: november, force: true, now: referenceDate)
        #expect(result.month == good)
        #expect(result.issue == .invalidData)
        #expect(try cache.load(city: jakarta, period: november) == good)
    }

    @Test func corruptCacheIsRejectedAndCanBeRecovered() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = PrayerCache(directory: folder)
        let directory = folder.appending(path: PrayerMonth.providerID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "\(jakarta.id)-\(november.key).json")
        try Data("broken".utf8).write(to: file)
        #expect(throws: PrayerDataError.cacheRead) { try cache.load(city: jakarta, period: november) }
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: cache)
        let result = try await repo.month(city: jakarta, period: november, now: referenceDate)
        #expect(try cache.load(city: jakarta, period: november) == result.month)
    }

    @Test func corruptOfflineDataNeverBecomesAUsableSchedule() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let directory = folder.appending(path: PrayerMonth.providerID)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: directory.appending(path: "\(jakarta.id)-\(november.key).json"))
        let stub = TransportStub()
        await stub.setOffline()
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: PrayerCache(directory: folder))
        await #expect(throws: PrayerDataError.network) { try await repo.month(city: jakarta, period: november, now: referenceDate) }
    }

    @Test func writeFailureIsVisibleWithoutDestroyingExistingData() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let blocker = folder.appending(path: "blocked")
        let marker = Data("preserve-me".utf8)
        try marker.write(to: blocker)
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: PrayerCache(directory: blocker))
        let result = try await repo.month(city: jakarta, period: november, now: referenceDate)
        #expect(result.issue == .cacheWrite)
        #expect(result.month.days.count == 30)
        #expect(try Data(contentsOf: blocker) == marker)
    }

    @Test func simultaneousRequestsShareOneFetch() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: PrayerCache(directory: folder))
        try await withThrowingTaskGroup(of: PrayerMonth.self) { group in
            for _ in 0..<10 { group.addTask { try await repo.month(city: jakarta, period: november, now: referenceDate).month } }
            for try await month in group { #expect(month.days.count == 30) }
        }
        #expect(await stub.requests.count == 1)
    }

    @Test func rateLimitStopsFurtherMonthlyRequests() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let stub = TransportStub()
        await stub.set(path(), body: Data(), status: 429, headers: ["Retry-After": "120"])
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: PrayerCache(directory: folder))
        await #expect(throws: PrayerDataError.self) { try await repo.month(city: jakarta, period: november) }
        await #expect(throws: PrayerDataError.self) { try await repo.month(city: jakarta, period: november.next) }
        #expect(await stub.requests.count == 1)
    }
}

@MainActor @Suite struct CitySelectionTests {
    @Test func selectionAndCachedSchedulesSurviveRelaunch() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "nida-test-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        await stub.set(path(jakarta, november.next), body: try payload(month: november.next))
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: PrayerCache(directory: folder))
        let first = PrayerDataStore(repository: repo, defaults: defaults)
        await first.select(jakarta, now: referenceDate)
        #expect(first.months.count == 2)
        #expect(first.today(at: referenceDate)?.isya == "19:00")
        await stub.setOffline()
        let restored = PrayerDataStore(repository: repo, defaults: defaults)
        await restored.restoreAndRefresh(now: referenceDate.addingTimeInterval(60))
        #expect(restored.location?.city == jakarta)
        #expect(restored.today(at: referenceDate) == first.today(at: referenceDate))
        #expect(await stub.requests.count == 2)
    }

    @Test(.timeLimit(.minutes(1))) func lateCityResponseCannotReplaceNewerSelection() async throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "nida-test-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let stub = TransportStub()
        await stub.set(path(), body: try payload())
        await stub.hold(path())
        for period in [november, november.next] {
            await stub.set(path(denpasar, period), body: try payload(city: denpasar, month: period))
        }
        let repo = PrayerRepository(api: PrayerAPI(load: { try await stub.response($0) }), cache: PrayerCache(directory: folder))
        let store = PrayerDataStore(repository: repo, defaults: defaults)
        let older = Task { await store.select(jakarta, now: referenceDate) }
        await stub.waitUntilHeld()
        await store.select(denpasar, now: referenceDate)
        await stub.release()
        await older.value
        #expect(store.location?.city == denpasar)
        #expect(store.location?.zone == .central)
        #expect(store.months.values.allSatisfy { $0.location.city == denpasar })
        #expect(!store.isRefreshing)
    }
}
