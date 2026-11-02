import SwiftUI

enum AppLanguage: String, CaseIterable {
    case indonesian = "id"
    case english = "en"

    var locale: Locale { Locale(identifier: rawValue) }
    var name: String { self == .indonesian ? "Bahasa Indonesia" : "English" }
}

extension LocalizedStringResource {
    // Resolve at presentation time so already-visible messages follow the selected language.
    func localized(in locale: Locale) -> String {
        var resource = self
        resource.locale = locale
        return String(localized: resource)
    }
}

func appErrorMessage(_ error: any Error) -> LocalizedStringResource {
    if let error = error as? PrayerDataError { return error.message }
    if let error = error as? LocationSetupError { return error.message }
    return "Terjadi kesalahan. \(error.localizedDescription)"
}

private struct AppLanguageModifier: ViewModifier {
    let preferences: ReminderPreferences

    func body(content: Content) -> some View {
        content.environment(\.locale, preferences.language.locale)
    }
}

extension View {
    func appLanguage(_ preferences: ReminderPreferences) -> some View {
        modifier(AppLanguageModifier(preferences: preferences))
    }
}
