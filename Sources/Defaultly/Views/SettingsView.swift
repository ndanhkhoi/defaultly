import SwiftUI

struct SettingsView: View {
    @State private var language = LanguagePreference.current
    private let launchLanguage = LanguagePreference.current

    var body: some View {
        Form {
            Picker("Language", selection: $language) {
                Text("System Default").tag(AppLanguage.system)
                // Language names are shown in their own language so anyone can find theirs.
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "Tiếng Việt").tag(AppLanguage.vietnamese)
            }
            .onChange(of: language) { LanguagePreference.set(language) }

            if language != launchLanguage {
                HStack {
                    Label("Relaunch Defaultly to use the new language.", systemImage: "arrow.clockwise.circle")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if LanguagePreference.canRelaunch {
                        Button("Relaunch Now") { LanguagePreference.relaunch() }
                            .glassButton(prominent: true)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
