import SwiftUI

struct SettingsView: View {
    @Environment(UpdateController.self) private var updates
    @State private var language = LanguagePreference.current

    var body: some View {
        @Bindable var updates = updates
        Form {
            Section {
                Picker("Language", selection: $language) {
                    Text("System Default").tag(AppLanguage.system)
                    // Language names are shown in their own language so anyone can find theirs.
                    Text(verbatim: "English").tag(AppLanguage.english)
                    Text(verbatim: "Tiếng Việt").tag(AppLanguage.vietnamese)
                }
                .onChange(of: language) { LanguagePreference.set(language) }

                if language != LanguagePreference.atLaunch {
                    HStack {
                        Label("Relaunch Defaultly to use the new language.", systemImage: "arrow.clockwise.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if Relaunch.isAvailable {
                            Button("Relaunch Now") { updates.relaunchApp() }
                                .glassButton(prominent: true)
                        }
                    }
                }
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $updates.automaticallyChecks)
                Toggle(isOn: $updates.automaticallyInstalls) {
                    Text("Download and install updates automatically")
                    Text("Updates are installed when you quit Defaultly.")
                }
                .disabled(!updates.automaticallyChecks || updates.installProblem != nil)
                if let problem = updates.installProblem {
                    Label(problem.message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    if let lastCheck = updates.lastCheck {
                        Text("Last checked \(lastCheck, format: .relative(presentation: .named))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not checked yet").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Check Now") { updates.checkNow() }
                }
            }
            .disabled(updates.currentVersion == nil)
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
