import SwiftUI

@main
struct NidaApp: App {
    var body: some Scene {
        MenuBarExtra("Nida", systemImage: "moon.stars") {
            Text("Nida").font(.headline)
            Text("Notch prototype coming next.").foregroundStyle(.secondary)
            SettingsLink()
            Button("Quit Nida") { NSApplication.shared.terminate(nil) }
        }
        Settings {
            Form {
                Section("Nida") {
                    Text("A quiet moment for prayer.")
                    Text("Prototype build. No live schedule or reminders yet.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 420, height: 220)
        }
    }
}
