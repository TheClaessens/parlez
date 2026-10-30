import KeyboardShortcuts
import ParlezKit
import ServiceManagement
import SwiftUI

/// The Settings window: the Dictation shortcut, Launch at login and Retouche.
struct SettingsView: View {
    let dictation: Dictation
    let retoucher: any Retoucher
    @State private var loginItemStatus = SMAppService.mainApp.status
    /// Kept while the Retoucher is unavailable, so Retouche comes back on by itself when it can run.
    @AppStorage(ParlezApp.retoucheKey) private var retoucheOn = false
    @AppStorage(ParlezApp.ownShortcutKey) private var ownShortcut = false
    @State private var unavailableReason: String?

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Dictation shortcut:", name: .dictation)
            Toggle("Launch at login", isOn: Binding(
                get: { loginItemStatus == .enabled },
                set: setLaunchAtLogin
            ))
            if loginItemStatus == .requiresApproval {
                Button("Allow Parlez in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
            }
            Divider()
            Toggle(isOn: $retoucheOn) {
                HStack(spacing: 6) {
                    Text("Retouche")
                    Text("BETA").font(.system(size: 9, weight: .bold)).foregroundStyle(.indigo)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.indigo.opacity(0.15), in: .rect(cornerRadius: 3))
                }
            }
            .toggleStyle(.switch)
            .disabled(unavailableReason != nil)
            Text("Applies your self-corrections before pasting (“red, oh wait, green” becomes “green”). Runs on this Mac with Apple Intelligence, and takes a little longer.")
                .caption()
            if let unavailableReason {
                Label("\(unavailableReason) Until then every Dictation pastes your exact words, and your Retouche shortcut works as a plain Dictation shortcut.", systemImage: "info.circle")
                    .caption()
            } else if retoucheOn {
                Toggle("Use a separate shortcut for Retouche", isOn: $ownShortcut)
                if ownShortcut {
                    KeyboardShortcuts.Recorder("Retouche shortcut:", name: .retouche)
                    Text("The Dictation shortcut now pastes your exact words. Whichever shortcut you stop with decides.")
                        .caption()
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        // The user can change Login Items, and Apple Intelligence, in System Settings while this window is closed.
        .onAppear {
            loginItemStatus = SMAppService.mainApp.status
            unavailableReason = retoucher.unavailableReason
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            unavailableReason = retoucher.unavailableReason
        }
        .onChange(of: retoucheOn) { ParlezApp.applyRetouche(to: dictation) }
        .onChange(of: ownShortcut) { ParlezApp.applyRetouche(to: dictation) }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Parlez: Launch at login change failed: \(error)")
        }
        // Show what the system actually did, not what was asked.
        loginItemStatus = SMAppService.mainApp.status
    }
}

private extension View {
    /// The grey small print under a setting.
    func caption() -> some View {
        font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// The "Settings…" menu item.
struct SettingsMenuItem: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") { bringToFront { openSettings() } }
        .keyboardShortcut(",")
    }
}
