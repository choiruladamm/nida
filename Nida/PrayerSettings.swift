import SwiftUI
import Observation

@MainActor @Observable
final class PrayerDataStore {
    var cities: [PrayerCity] = []
    var deliveryMessage: LocalizedStringResource?
    let detection: LocationDetection
    private(set) var onboardingComplete = false
    private(set) var location: PrayerLocation?
    private(set) var displayCityName: String?
    private(set) var months: [ScheduleMonth: PrayerMonth] = [:]
    private(set) var pendingCity: PrayerCity?
    private(set) var isRefreshing = false
    private(set) var isLoadingCities = false
    private(set) var cityError: LocalizedStringResource?
    private(set) var message: LocalizedStringResource?
    private let repository: PrayerRepository
    private let defaults: UserDefaults
    private var requestID = UUID()

    init(repository: PrayerRepository = PrayerRepository(), defaults: UserDefaults = .standard,
         detection: LocationDetection = LocationDetection()) {
        self.detection = detection
        self.repository = repository
        self.defaults = defaults
        if let data = defaults.data(forKey: "prayerLocation"),
           let saved = try? JSONDecoder().decode(PrayerLocation.self, from: data),
           (try? saved.validate()) != nil {
            location = saved
            displayCityName = PrayerCityChoice.displayName(defaults.string(forKey: "prayerDisplayCityName") ?? saved.city.name.localizedCapitalized)
            onboardingComplete = true
            defaults.set(true, forKey: "locationOnboardingComplete")
        }
    }

    #if DEBUG
    func showRefreshFailureForReview() {
        message = PrayerDataError.rateLimited(Date().addingTimeInterval(120)).message
    }
    #endif

    func today(at date: Date = Date()) -> PrayerDay? {
        guard let location else { return nil }
        return months[ScheduleMonth(containing: date, in: location.zone)]?.day(at: date)
    }

    func timeline() throws -> PrayerTimeline? {
        guard let location else { return nil }
        return try PrayerTimeline(location: location, months: Array(months.values))
    }

    func loadCities() async {
        guard !isLoadingCities else { return }
        isLoadingCities = true
        cityError = nil
        defer { isLoadingCities = false }
        do { cities = try await repository.cities().sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
        catch { cityError = appErrorMessage(error) }
    }

    func restoreAndRefresh(now: Date = Date()) async {
        guard !isRefreshing else { return }
        if let location { await load(city: location.city, hint: location, force: false, now: now, displayName: displayCityName) }
    }

    func select(_ city: PrayerCity, now: Date = Date(), displayName: String? = nil) async {
        detection.cancel()
        await load(city: city, hint: location?.city == city ? location : nil, force: false, now: now, displayName: displayName)
    }

    func refresh(now: Date = Date()) async {
        guard !isRefreshing, let location else { return }
        await load(city: location.city, hint: location, force: true, now: now, displayName: displayCityName)
    }

    private func load(city: PrayerCity, hint: PrayerLocation?, force: Bool, now: Date, displayName: String? = nil) async {
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
        if hint != nil {
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
            if let issue = first.issue { message = issue.message }
            let selection = try JSONEncoder().encode(first.month.location)
            defaults.set(selection, forKey: "prayerLocation")
            displayCityName = PrayerCityChoice.displayName(displayName ?? first.month.location.city.name.localizedCapitalized)
            defaults.set(displayCityName, forKey: "prayerDisplayCityName")
            onboardingComplete = true
            defaults.set(true, forKey: "locationOnboardingComplete")

            let current = ScheduleMonth(containing: now, in: first.month.location.zone)
            for period in [current, current.next] where period != anchor {
                do {
                    let result = try await repository.month(city: city, period: period, force: force, now: now)
                    guard requestID == id else { return }
                    guard result.month.location == location else { throw PrayerDataError.invalidData }
                    months[period] = result.month
                    if let issue = result.issue { message = issue.message }
                } catch {
                    guard requestID == id else { return }
                    message = appErrorMessage(error)
                }
            }
            guard requestID == id else { return }
            months = months.filter { $0.key == current || $0.key == current.next }
        } catch {
            guard requestID == id else { return }
            message = appErrorMessage(error)
        }
    }
}

struct PrayerDataSettings: View {
    @Environment(\.locale) private var locale
    let store: PrayerDataStore
    @State private var choosingCity = false

    var body: some View {
        if let message = store.deliveryMessage {
            Section("Pengingat") { Text(message.localized(in: locale)).foregroundStyle(.secondary) }
        }
        Section("Lokasi jadwal") {
            Button {
                store.detection.cancel()
                choosingCity = true
            } label: {
                HStack {
                    if let name = store.displayCityName { Text(name) }
                    else { Text("Pilih kota / kabupaten") }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $choosingCity) { CitySelectionView(store: store) }
            LocationDetectionControls(store: store) { choosingCity = true }
            if let pending = store.pendingCity {
                HStack { ProgressView().controlSize(.small); Text("Memuat \(pending.name.localizedCapitalized)…") }
            }
            if let location = store.location {
                LabeledContent("Zona waktu", value: location.zone.label)
                Button("Perbarui jadwal") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
            }
            if let message = store.message {
                Label(message.localized(in: locale), systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        Section("Jadwal hari ini") {
            if let timeline = try? store.timeline() {
                NextPrayerSummary(timeline: timeline)
            }
            if let day = store.today() {
                ForEach(PrayerKind.allCases, id: \.self) { prayer in
                    LabeledContent(prayer.label.localized(in: locale), value: day.time(for: prayer))
                        .monospacedDigit()
                }
                Text(PrayerMonth.attribution).font(.caption).foregroundStyle(.secondary)
                Text("\(store.months.values.reduce(0) { $0 + $1.days.count }) hari tersimpan untuk offline.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(store.location == nil ? LocalizedStringKey("Pilih wilayah untuk memuat jadwal asli.") : LocalizedStringKey("Jadwal tanggal ini belum tersedia. Coba perbarui."))
                    .foregroundStyle(.secondary)
            }
        }
        .task { await store.restoreAndRefresh() }
        .onDisappear { store.detection.cancel() }
    }
}

struct CitySelectionView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let store: PrayerDataStore
    @State private var query = ""
    @State private var selectedChoiceID: String?
    @FocusState private var searchFocused: Bool

    private var filteredChoices: [PrayerCityChoice] {
        PrayerCityChoice.choices(for: store.cities).filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pilih wilayah")
                .font(.title2.weight(.semibold))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("Cari kota atau kabupaten", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityLabel("Cari kota atau kabupaten")
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(searchFocused ? Color.accentColor : .clear, lineWidth: 2)
            }
            List(selection: $selectedChoiceID) {
                ForEach(filteredChoices) { choice in
                    HStack {
                        Text(choice.name)
                        Spacer()
                        if store.location?.city == choice.city, store.displayCityName == choice.name {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Jadwal yang digunakan")
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(choice.id)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                if store.isLoadingCities { ProgressView("Memuat daftar wilayah…") }
                else if store.cityError == nil, !query.isEmpty, filteredChoices.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .disabled(store.isRefreshing)
            if let error = store.cityError {
                HStack {
                    Text(error.localized(in: locale)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Coba lagi") { Task { await store.loadCities() } }
                }
            }
            if let message = store.message {
                Text(message.localized(in: locale)).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                if let pending = store.pendingCity {
                    ProgressView().controlSize(.small)
                    Text("Memuat \(pending.name.localizedCapitalized)…")
                        .font(.callout).lineLimit(1)
                }
                Spacer()
                Button("Batal") { dismiss() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button("Gunakan kota ini") {
                    guard let choice = filteredChoices.first(where: { $0.id == selectedChoiceID }) else { return }
                    store.detection.cancel()
                    Task {
                        await store.select(choice.city, displayName: choice.name)
                        if store.location?.city == choice.city, store.displayCityName == choice.name { dismiss() }
                    }
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(store.isRefreshing || !filteredChoices.contains(where: { $0.id == selectedChoiceID }))
            }
            .controlSize(.large)
            .buttonBorderShape(.capsule)
        }
        .padding(20)
        .frame(width: 440, height: 460)
        .background { NidaGlassBackground(shape: Rectangle(), cornerRadius: 0).ignoresSafeArea() }
        .presentationBackground(.clear)
        .preferredColorScheme(.dark)
        .task {
            if store.cities.isEmpty { await store.loadCities() }
            selectedChoiceID = PrayerCityChoice.choices(for: store.cities).first {
                $0.city == store.location?.city && $0.name == store.displayCityName
            }?.id
        }
    }
}

private struct NextPrayerSummary: View {
    @Environment(\.locale) private var locale
    let timeline: PrayerTimeline

    var body: some View {
        let now = Date()
        let updates = timeline.boundaryDates.filter { $0 > now }
        if updates.isEmpty {
            summary(at: now)
        } else {
            TimelineView(PrayerDisplaySchedule(boundaries: updates)) { context in summary(at: context.date) }
        }
    }

    @ViewBuilder private func summary(at date: Date) -> some View {
        let snapshot = timeline.snapshot(at: date)
        if let next = snapshot.next {
            let tomorrow = next.id.dateKey != ScheduleMonth.dateKey(date, in: timeline.location.zone)
            LabeledContent("Berikutnya") {
                if tomorrow { Text("\(next.id.prayer.label.localized(in: locale)) · besok") }
                else { Text(next.id.prayer.label.localized(in: locale)) }
            }
            LabeledContent("Waktu", value: "\(next.wallTime) \(timeline.location.zone.label)")
            HStack {
                Text("Sisa waktu")
                Spacer()
                Text(next.startsAt, style: .timer).monospacedDigit()
            }
        } else if snapshot.hasToday {
            Text("Jadwal besok belum tersedia.").foregroundStyle(.secondary)
        }
    }
}

struct LocationDetectionControls: View {
    @Environment(\.locale) private var locale
    let store: PrayerDataStore
    let chooseManually: () -> Void

    var body: some View {
        Group {
            switch store.detection.state {
            case .idle:
                Button("Gunakan lokasi saat ini", systemImage: "location") {
                    detect()
                }
            case .locating:
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Mencari kota…")
                    Spacer()
                    Button("Batal") { store.detection.cancel() }
                }
            case .found(let city, _):
                ProgressView("Memuat \(city.name.localizedCapitalized)…")
                    .controlSize(.small)
            case .failed(let error):
                Text(error.message.localized(in: locale)).font(.callout).foregroundStyle(.secondary)
                Button("Coba lokasi lagi") { detect() }
            }
            if let error = store.cityError { Text(error.localized(in: locale)).font(.callout).foregroundStyle(.secondary) }
            Text("Lokasi hanya diambil saat diminta. Koordinat tidak disimpan; Apple memproses lokasi untuk mencari nama kota.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(store.isRefreshing || store.isLoadingCities)
    }

    private func detect() {
        let request = store.detection.start {
            if store.cities.isEmpty { await store.loadCities() }
            guard !store.cities.isEmpty else { throw LocationSetupError.unavailable }
            return store.cities
        }
        Task {
            await request.value
            guard !request.isCancelled,
                  case .found(let city, let names) = store.detection.state else { return }
            await store.select(city, displayName: names.map { PrayerCityChoice.displayName($0) }.joined(separator: ", "))
        }
    }
}

struct LocationOnboardingView: View {
    @Environment(\.locale) private var locale
    let store: PrayerDataStore
    let finish: () -> Void
    @State private var choosingCity = false

    var body: some View {
        Form {
            Section {
                Label("Waktunya ambil jeda.", systemImage: "moon.stars").font(.title2.weight(.semibold))
                Text("Pilih kota untuk jadwal sholat yang sesuai. Kamu bisa menggantinya kapan saja di Pengaturan.")
                    .foregroundStyle(.secondary)
            }
            Section("Lokasi jadwal") {
                LocationDetectionControls(store: store) { choosingCity = true }
                Button("Pilih kota manual", systemImage: "magnifyingglass") {
                    store.detection.cancel()
                    choosingCity = true
                }
                .disabled(store.isRefreshing)
                if let pending = store.pendingCity {
                    ProgressView("Memuat \(pending.name.localizedCapitalized)…")
                }
                if let message = store.message { Text(message.localized(in: locale)).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 440)
        .sheet(isPresented: $choosingCity, onDismiss: {
            if store.onboardingComplete { finish() }
        }) { CitySelectionView(store: store) }
        .onChange(of: store.onboardingComplete) { _, complete in
            if complete && !choosingCity { finish() }
        }
        .onDisappear { store.detection.cancel() }
    }
}
