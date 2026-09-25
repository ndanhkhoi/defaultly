import DefaultlyCore
import SwiftUI

/// The Software Update window's content, one layout per update phase.
struct UpdateView: View {
    let controller: UpdateController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch controller.phase {
            case .idle:
                header(Text("Software Update"), Text("Check whether a newer version of Defaultly is available."))
                buttons {
                    Button("Close") { controller.dismiss() }
                    Button("Check Now") { controller.checkNow() }.primary()
                }
            case .checking:
                header(Text("Checking for Updates…"))
                ProgressView().progressViewStyle(.linear)
                buttons { Button("Cancel") { controller.cancel(); controller.dismiss() } }
            case .upToDate:
                header(Text("You're Up to Date"), Text("Defaultly \(currentVersion) is the newest version."))
                buttons { Button("OK") { controller.dismiss() }.primary() }
            case .available(let update):
                available(update)
            case .installing(let update, let progress):
                installing(update, progress: progress)
            case .ready(_, let update):
                header(
                    Text("Defaultly \(update.release.version.description) Is Ready to Install"),
                    Text("It will be installed when you quit Defaultly. Relaunch now to start using it.")
                )
                notes(update)
                buttons {
                    Button("Install on Quit") { controller.dismiss() }
                    Button("Relaunch Now") { controller.relaunchNow() }.primary()
                }
            case .installed(let version):
                header(
                    Text("Defaultly \(version.description) Is Installed"),
                    Text("Defaultly couldn't reopen by itself. Quit it and open it again to use the new version.")
                )
                buttons { Button("Quit Defaultly") { NSApp.terminate(nil) }.primary() }
            case .failed(let message, let update):
                failed(message, update: update)
            }
        }
        .padding(20)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Phases

    @ViewBuilder
    private func available(_ update: AvailableUpdate) -> some View {
        header(
            Text("A New Version of Defaultly Is Available"),
            Text("Defaultly \(update.release.version.description) is available. You have \(currentVersion).")
        )
        notes(update)
        if let problem = controller.installProblem {
            Label(problem.message, systemImage: "info.circle")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Toggle("Download and install updates automatically", isOn: automaticallyInstalls)
        }
        HStack {
            Button("Skip This Version") { controller.skip() }
            Spacer()
            Button("Remind Me Later") { controller.dismiss() }
            if controller.installProblem == nil {
                Button("Install and Relaunch") { controller.install() }.primary()
            } else {
                Button("Download…") { controller.openReleasePage(update) }.primary()
            }
        }
        .controlSize(.large)
    }

    @ViewBuilder
    private func installing(_ update: AvailableUpdate, progress: Double?) -> some View {
        let version = update.release.version.description
        if let progress {
            header(Text("Downloading Defaultly \(version)…"))
            ProgressView(value: progress)
                .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            buttons { Button("Cancel") { controller.cancel() } }
        } else {
            header(Text("Installing Defaultly \(version)…"), Text("Checking the download and replacing the app. Defaultly relaunches when it's done."))
            ProgressView().progressViewStyle(.linear)
        }
    }

    @ViewBuilder
    private func failed(_ message: String, update: AvailableUpdate?) -> some View {
        header(
            update == nil ? Text("Couldn't Check for Updates") : Text("Couldn't Install the Update"),
            Text(verbatim: message),
            warning: true
        )
        buttons {
            if let update {
                Button("Download Manually…") { controller.openReleasePage(update) }
            } else {
                Button("OK") { controller.dismiss() }
            }
            Button("Try Again") { controller.retryInstall() }.primary()
        }
    }

    // MARK: - Parts

    private func header(_ title: Text, _ message: Text? = nil, warning: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .overlay(alignment: .bottomTrailing) {
                    if warning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                title.font(.title3.weight(.semibold))
                if let message {
                    message.foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func notes(_ update: AvailableUpdate) -> some View {
        ScrollView {
            ReleaseNotesList(sections: update.newReleases.map(ReleaseNotesList.Section.init))
                .padding(12)
        }
        .frame(height: 220)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        .accessibilityLabel(Text("Release Notes"))
    }

    private func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            Spacer()
            content()
        }
        .controlSize(.large)
    }

    private var currentVersion: String {
        controller.currentVersion?.description ?? "?"
    }

    private var automaticallyInstalls: Binding<Bool> {
        Binding(get: { controller.automaticallyInstalls }, set: { controller.automaticallyInstalls = $0 })
    }
}

private extension View {
    /// The window's default button.
    func primary() -> some View {
        glassButton(prominent: true).keyboardShortcut(.defaultAction)
    }
}
