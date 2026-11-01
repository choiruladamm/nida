import SwiftUI
import Observation

@MainActor @Observable
final class PrayerDataStore {
    var cities: [PrayerCity] = []
    private(set) var location: PrayerLocation?
    private(set) var months: [ScheduleMonth: PrayerMonth] = [:]
    private(set) var pendingCity: PrayerCity?
    private(set) var isRefreshing = false
    private(set) var isLoadingCities = false
    private(set) var cityError: String?
    private(set) var message: String?
    private let repository: PrayerRepository
    private let defaults: UserDefaults
    private var requestID = UUID()

    init(repository: PrayerRepository = PrayerRepository(), defaults: UserDefaults = .standard) {
        self.repository = repository
        self.defaults = defaults
        if let data = defaults.data(forKey: "prayerLocation"),
           let saved = try? JSONDecoder().decode(PrayerLocation.self, from: data),
           (try? saved.validate()) != nil { location = saved }
    }

    func today(at date: Date = Date()) -> PrayerDay? {
        guard let location else { return nil }
        return months[ScheduleMonth(containing: date, in: location.zone)]?.day(at: date)
    }

    func loadCities() async {
        guard !isLoadingCities else { return }
        isLoadingCities = true
        cityError = nil
        defer { isLoadingCities = false }
        do { cities = try await repository.cities().sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        catch { cityError = error.localizedDescription }
    }

    func restoreAndRefresh(now: Date = Date()) async {
        guard !isRefreshing else { return }
        if let location { await load(city: location.city, hint: location, force: false, now: now) }
    }

    func select(_ city: PrayerCity, now: Date = Date()) async {
        await load(city: city, hint: location?.city == city ? location : nil, force: false, now: now)
    }

    func refresh(now: Date = Date()) async {
        guard !isRefreshing, let location else { return }
        await load(city: location.city, hint: location, force: true, now: now)
    }

    private func load(city: PrayerCity, hint: PrayerLocation?, force: Bool, now: Date) async {
        let id = UUID()
        requestID = id
        isRefreshing = true
        pendingCity = city
        message = nil
        defer {
            if requestID == id { isRefreshing = false; pendingCity = nil }
        }

        // Cached metadata supplies the zone on relaunch; new cities resolve it from provider province.
        let anchor = ScheduleMonth(containing: now, in: hint?.zone ?? .west)
        if let hint {
            for period in [anchor, anchor.next] {
                if let cached = try? await repository.cached(city: city, period: period), requestID == id {
                    location = cached.location
                    months[period] = cached
                }
            }
        }
        do {
            let first = try await repository.month(city: city, period: anchor, force: force, now: now)
            guard requestID == id else { return }
            if location?.city != city { months = [:] }
            location = first.month.location
            months[anchor] = first.month
            if let issue = first.issue { message = issue.localizedDescription }
            let selection = try JSONEncoder().encode(first.month.location)
            defaults.set(selection, forKey: "prayerLocation")

            let current = ScheduleMonth(containing: now, in: first.month.location.zone)
            for period in [current, current.next] where period != anchor {
                do {
                    let result = try await repository.month(city: city, period: period, force: force, now: now)
                    guard requestID == id else { return }
                    guard result.month.location == location else { throw PrayerDataError.invalidData }
                    months[period] = result.month
                    if let issue = result.issue { message = issue.localizedDescription }
                } catch {
                    guard requestID == id else { return }
                    message = error.localizedDescription
                }
            }
            guard requestID == id else { return }
            months = months.filter { $0.key == current || $0.key == current.next }
        } catch {
            guard requestID == id else { return }
            message = error.localizedDescription
        }
    }
}

struct PrayerDataSettings: View {
    let store: PrayerDataStore
    @State private var choosingCity = false

    var body: some View {
        Section("Lokasi jadwal") {
            Button {
                choosingCity = true
            } label: {
                HStack {
                    Text(store.location?.city.name.localizedCapitalized ?? "Pilih kota / kabupaten")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $choosingCity) { CitySelectionView(store: store) }
            if let pending = store.pendingCity {
                HStack { ProgressView().controlSize(.small); Text("Memuat \(pending.name.localizedCapitalized)…") }
            }
            if let location = store.location {
                LabeledContent("Zona waktu", value: location.zone.label)
                Button("Perbarui jadwal") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
            }
            if let message = store.message {
                Label(message, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        Section("Jadwal hari ini") {
            if let day = store.today() {
                ForEach(PrayerKind.allCases, id: \.self) { prayer in
                    LabeledContent(prayer.label, value: day.time(for: prayer))
                        .monospacedDigit()
                }
                Text(PrayerMonth.attribution).font(.caption).foregroundStyle(.secondary)
                Text("\(store.months.values.reduce(0) { $0 + $1.days.count }) hari tersimpan untuk offline.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(store.location == nil ? "Pilih wilayah untuk memuat jadwal asli." : "Jadwal tanggal ini belum tersedia. Coba perbarui.")
                    .foregroundStyle(.secondary)
            }
        }
        .task { await store.restoreAndRefresh() }
    }
}

private struct CitySelectionView: View {
    let store: PrayerDataStore
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let error = store.cityError {
                    Text(error).foregroundStyle(.secondary)
                    Button("Coba lagi") { Task { await store.loadCities() } }
                }
                ForEach(store.cities.filter { query.isEmpty || $0.name.localizedStandardContains(query) }) { city in
                    Button {
                        dismiss()
                        Task { await store.select(city) }
                    } label: {
                        HStack {
                            Text(city.name.localizedCapitalized)
                            Spacer()
                            if store.location?.city == city { Image(systemName: "checkmark") }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if store.isLoadingCities { ProgressView("Memuat daftar wilayah…") }
                else if store.cityError == nil, !query.isEmpty,
                        !store.cities.contains(where: { $0.name.localizedStandardContains(query) }) {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Cari kota atau kabupaten")
            .navigationTitle("Pilih wilayah")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Tutup") { dismiss() } } }
        }
        .frame(width: 440, height: 460)
        .task { if store.cities.isEmpty { await store.loadCities() } }
    }
}
