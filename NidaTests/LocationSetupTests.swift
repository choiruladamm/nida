import Foundation
import Testing
@testable import Nida

private let denpasarCity = PrayerCity(id: "6a9aeddfc689c1d0e3b9ccc3ab651bc5", name: "KOTA DENPASAR")
private let bandungCity = PrayerCity(id: String(repeating: "a", count: 32), name: "KOTA BANDUNG")
private let bandungRegency = PrayerCity(id: String(repeating: "b", count: 32), name: "KAB. BANDUNG")

@Suite struct CityMatchingTests {
    @Test(arguments: ["Denpasar", "Kota Denpasar", "  KOTA   DÉNPASAR  "])
    func matchesVerifiedCatalogWithoutFuzzyGuessing(name: String) throws {
        #expect(try DetectedArea.match([DetectedArea(city: name, countryCode: "ID")],
                                       cities: [denpasarCity]) == denpasarCity)
    }

    @Test(arguments: ["Pusat", "Selatan", "Utara", "Barat", "Timur"])
    func jakartaAdministrativeCitiesUseProviderJakarta(name: String) throws {
        let jakarta = PrayerCity(id: "58a2fc6ed39fd083f55d4182bf88826d", name: "KOTA JAKARTA")
        let detected = DetectedArea(city: "Kota Administrasi Jakarta " + name, countryCode: "ID")
        #expect(try DetectedArea.match([detected], cities: [jakarta, denpasarCity]) == jakarta)
    }

    @Test func jakartaChoicesKeepProviderIdentityAndShortDisplayNames() {
        let jakarta = PrayerCity(id: "58a2fc6ed39fd083f55d4182bf88826d", name: "KOTA JAKARTA")
        let choices = PrayerCityChoice.choices(for: [jakarta, denpasarCity])
        #expect(Set(choices.map(\.id)).count == choices.count)
        #expect(!choices.contains(where: { $0.name == "Kota Jakarta" }))
        for name in PrayerCityChoice.jakartaDistricts {
            #expect(choices.first(where: { $0.name == name })?.city == jakarta)
            #expect(PrayerCityChoice.displayName("Kota Administrasi " + name) == name)
        }
        #expect(PrayerCityChoice.displayName("Kota Denpasar") == "Kota Denpasar")
        #expect(choices.first(where: { $0.city == denpasarCity })?.name == "Kota Denpasar")
    }

    @Test func jakartaMappingDoesNotAbsorbOtherAdministrativeAreas() throws {
        let jakarta = PrayerCity(id: "58a2fc6ed39fd083f55d4182bf88826d", name: "KOTA JAKARTA")
        let islands = PrayerCity(id: "cfecdb276f634854f3ef915e2e980c31", name: "KAB. KEPULAUAN SERIBU")
        #expect(try DetectedArea.match([DetectedArea(city: "Kabupaten Kepulauan Seribu", countryCode: "ID")],
                                       cities: [jakarta, islands]) == islands)
        #expect(throws: LocationSetupError.unsupported) {
            try DetectedArea.match([DetectedArea(city: "Kota Administrasi Jakarta Lain", countryCode: "ID")],
                                  cities: [jakarta, islands])
        }
        #expect(throws: LocationSetupError.unsupported) {
            try DetectedArea.match([DetectedArea(city: "Kota Administrasi Jakarta Pusat", countryCode: "MY")],
                                  cities: [jakarta])
        }
    }

    @Test func distinguishesCityAndRegency() throws {
        let catalog = [bandungCity, bandungRegency]
        #expect(try DetectedArea.match([DetectedArea(city: "Kabupaten Bandung", countryCode: "ID")],
                                       cities: catalog) == bandungRegency)
        #expect(try DetectedArea.match([DetectedArea(city: "Kota Bandung", countryCode: "ID")],
                                       cities: catalog) == bandungCity)
        #expect(throws: LocationSetupError.ambiguous) {
            try DetectedArea.match([DetectedArea(city: "Bandung", countryCode: "ID")], cities: catalog)
        }
    }

    @Test func rejectsConflictingGeocoderResults() {
        #expect(throws: LocationSetupError.ambiguous) {
            try DetectedArea.match([DetectedArea(city: "Kota Bandung", countryCode: "ID"),
                                    DetectedArea(city: "Kabupaten Bandung", countryCode: "ID")],
                                   cities: [bandungCity, bandungRegency])
        }
    }

    @Test(arguments: ["", "Denpasar Selatan", "Dnpasar", "Kabupaten Denpasar"])
    func rejectsMissingUnsupportedAndMisspelledCities(name: String) {
        #expect(throws: LocationSetupError.unsupported) {
            try DetectedArea.match([DetectedArea(city: name, countryCode: "ID")], cities: [denpasarCity])
        }
    }

    @Test(arguments: ["", "US", "MY"])
    func requiresIndonesianCountryCode(country: String) {
        #expect(throws: LocationSetupError.unsupported) {
            try DetectedArea.match([DetectedArea(city: "Denpasar", countryCode: country)], cities: [denpasarCity])
        }
    }

    @Test func rejectsEmptyAndInvalidCatalog() {
        #expect(throws: LocationSetupError.unsupported) { try DetectedArea.match([], cities: [denpasarCity]) }
        #expect(throws: LocationSetupError.unsupported) {
            try DetectedArea.match([DetectedArea(city: "Denpasar", countryCode: "ID")], cities: [])
        }
        #expect(throws: PrayerDataError.invalidData) {
            try DetectedArea.match([DetectedArea(city: "Denpasar", countryCode: "ID")],
                                  cities: [PrayerCity(id: "invalid", name: "KOTA DENPASAR")])
        }
    }
}

@MainActor private final class HeldLookup {
    private var reply: CheckedContinuation<[DetectedArea], any Error>?
    private var observer: CheckedContinuation<Void, Never>?
    private var started = false

    func lookup() async throws -> [DetectedArea] {
        try await withCheckedThrowingContinuation { continuation in
            reply = continuation
            started = true
            observer?.resume()
            observer = nil
        }
    }
    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }
    func finish() {
        reply?.resume(returning: [DetectedArea(city: "Denpasar", countryCode: "ID")])
        reply = nil
    }
}

@MainActor @Suite struct LocationDetectionTests {
    @Test func doesNotRequestLocationUntilStartedAndOnlyOffersCandidate() async {
        var lookups = 0
        let detection = LocationDetection(lookup: {
            lookups += 1
            return [DetectedArea(city: "Denpasar", countryCode: "ID")]
        })
        #expect(detection.state == .idle)
        #expect(lookups == 0)
        await detection.start { [denpasarCity] }.value
        #expect(lookups == 1)
        #expect(detection.state == .found(city: denpasarCity, detectedNames: ["Denpasar"]))
    }

    @Test(arguments: ["Pusat", "Selatan", "Utara", "Barat", "Timur"])
    func preservesDetectedAreaSeparatelyFromScheduleCity(name: String) async {
        let jakarta = PrayerCity(id: "58a2fc6ed39fd083f55d4182bf88826d", name: "KOTA JAKARTA")
        let area = "Kota Administrasi Jakarta " + name
        let detection = LocationDetection(lookup: {
            [DetectedArea(city: area, countryCode: "ID"), DetectedArea(city: area, countryCode: "ID")]
        })
        await detection.start { [jakarta] }.value
        #expect(detection.state == .found(city: jakarta, detectedNames: [area]))
    }

    @Test(arguments: [LocationSetupError.denied, .unavailable, .unsupported, .ambiguous])
    func exposesRecoverableErrors(error: LocationSetupError) async {
        let detection = LocationDetection(lookup: { throw error })
        await detection.start { [denpasarCity] }.value
        #expect(detection.state == .failed(error))
    }

    @Test func catalogFailureNeverRequestsPermission() async {
        var lookups = 0
        let detection = LocationDetection(lookup: { lookups += 1; return [] })
        await detection.start { throw LocationSetupError.unavailable }.value
        #expect(lookups == 0)
        #expect(detection.state == .failed(.unavailable))
    }

    @Test(.timeLimit(.minutes(1))) func manualSelectionOrDismissalInvalidatesLateDetection() async {
        let held = HeldLookup()
        let detection = LocationDetection(lookup: { try await held.lookup() })
        let work = detection.start { [denpasarCity] }
        await held.waitUntilStarted()
        detection.cancel()
        held.finish()
        await work.value
        #expect(detection.state == .idle)
    }

    @Test(.timeLimit(.minutes(1))) func retryKeepsNewerResultWhenOldLookupFinishes() async {
        let held = HeldLookup()
        var calls = 0
        let detection = LocationDetection(lookup: {
            calls += 1
            if calls == 1 { return try await held.lookup() }
            return [DetectedArea(city: "Kota Bandung", countryCode: "ID")]
        })
        let older = detection.start { [denpasarCity] }
        await held.waitUntilStarted()
        await detection.start { [bandungCity] }.value
        held.finish()
        await older.value
        #expect(detection.state == .found(city: bandungCity, detectedNames: ["Kota Bandung"]))
    }

    @Test(.timeLimit(.minutes(1))) func cancellationWhileLoadingCatalogNeverRequestsLocation() async {
        let held = HeldLookup()
        var lookups = 0
        let detection = LocationDetection(lookup: { lookups += 1; return [] })
        let work = detection.start { _ = try await held.lookup(); return [denpasarCity] }
        await held.waitUntilStarted()
        detection.cancel()
        held.finish()
        await work.value
        #expect(lookups == 0)
        #expect(detection.state == .idle)
    }
}
