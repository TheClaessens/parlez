import KeyboardShortcuts
import ParlezKit
import ServiceManagement
import SwiftUI

/// The Settings window: the Dictation shortcut and Launch at login, nothing else.
struct SettingsView: View {
    @State private var loginItemStatus = SMAppService.mainApp.status

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
        }
        .padding(20)
        .frame(width: 360)
        // The user can change Login Items in System Settings while this window is closed.
        .onAppear { loginItemStatus = SMAppService.mainApp.status }
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

/// The "Settings…" menu item.
struct SettingsMenuItem: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") { bringToFront { openSettings() } }
        .keyboardShortcut(",")
    }
}
