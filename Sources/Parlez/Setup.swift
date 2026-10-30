import AVFoundation
import ApplicationServices
import ParlezKit
import SwiftUI

/// Setup: gets the Microphone and Accessibility permissions and prepares the speech model, then tells the
/// Dictation core it is complete. Its window opens at launch only when a step is not satisfied. It keeps
/// watching the permissions afterwards: a revoke makes the core unavailable again and reopens the window.
@MainActor @Observable
final class Setup {
    enum Step: Int {
        case microphone, accessibility, model

        /// The System Settings pane that grants this step; nil for the model.
        var settingsPane: URL? {
            let anchor: String? = switch self {
            case .microphone: "Privacy_Microphone"
            case .accessibility: "Privacy_Accessibility"
            case .model: nil
            }
            return anchor.flatMap { URL(string: "x-apple.systempreferences:com.apple.preference.security?\($0)") }
        }
    }

    private(set) var microphone: AVAuthorizationStatus = .notDetermined
    private(set) var accessibility = false
    /// The model download fraction once the model step has started; nil before.
    private(set) var modelProgress: Double?
    private(set) var modelReady = false
    private(set) var modelFailed = false

    /// The first step that is not satisfied, or nil when Setup is complete.
    var current: Step? {
        if microphone != .authorized { return .microphone }
        if !accessibility { return .accessibility }
        if !modelReady { return .model }
        return nil
    }

    private let dictation: Dictation
    private let transcriber: VozTranscriber
    private var window: NSWindow?

    init(dictation: Dictation, transcriber: VozTranscriber) {
        self.dictation = dictation
        self.transcriber = transcriber
    }

    /// The one place the permissions are read; `current` turns them into each step's satisfaction.
    private func checkPermissions() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibility = AXIsProcessTrusted()
    }

    /// Called once at launch. With everything in place this only loads the model (~0.3 s), with no window.
    func start() {
        checkPermissions()
        if current != .model || !VozTranscriber.isModelDownloaded { show() }
        Task { await run() }
    }

    /// Re-checks the permissions every second for as long as Parlez runs: a grant in System Settings is
    /// seen without a restart, and a revoke puts the core back to unavailable and reopens Setup at that step.
    /// Prepares the model once it is the current step.
    private func run() async {
        var complete = false
        while true {
            checkPermissions()
            if complete != (current == nil) {
                complete.toggle()
                if complete {
                    dictation.setupCompleted()
                    window?.close()
                } else {
                    dictation.setupIncomplete()
                    show()
                }
            }
            if current == .model, modelProgress == nil, !modelFailed { await prepareModel() }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func prepareModel() async {
        modelProgress = 0
        do {
            try await transcriber.prepare { fraction in Task { @MainActor in self.modelProgress = fraction } }
            modelReady = true
        } catch {
            NSLog("Parlez: preparing the speech model failed: \(error)")
            modelProgress = nil
            modelFailed = true
            show()
        }
    }

    func requestMicrophone() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            checkPermissions()
        }
    }

    func retryModel() { modelFailed = false }

    func openSystemSettings(for step: Step) {
        if let pane = step.settingsPane { NSWorkspace.shared.open(pane) }
    }

    private func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SetupView(setup: self)))
            window.title = "Parlez Setup"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        bringToFront { window?.makeKeyAndOrderFront(nil) }
    }
}

/// The Setup window: the three steps with their status; only the current step offers an action.
struct SetupView: View {
    let setup: Setup

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set up Parlez").font(.title2.bold())
            step(.microphone, "Microphone", "Parlez listens only while you dictate, and never leaves this Mac.") {
                if setup.microphone == .notDetermined {
                    Button("Allow Microphone") { setup.requestMicrophone() }
                } else {
                    Button("Open System Settings") { setup.openSystemSettings(for: .microphone) }
                }
            }
            step(.accessibility, "Accessibility",
                 "Parlez pastes your Transcript by pressing ⌘V for you, which macOS only allows with Accessibility "
                 + "permission. Turn Parlez on in the list; this window moves on by itself.") {
                Button("Open System Settings") { setup.openSystemSettings(for: .accessibility) }
            }
            step(.model, "Speech model",
                 "Downloads the speech model and prepares it once, so your first Dictation is instant.") {
                if setup.modelFailed {
                    Text("The download failed. Check your connection.").foregroundStyle(.red)
                    Button("Try Again") { setup.retryModel() }
                } else if let progress = setup.modelProgress {
                    ProgressView(value: progress)
                    Text(progress < 1 ? "Downloading…" : "Preparing… this takes about 20 seconds the first time.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func step(
        _ step: Setup.Step, _ title: String, _ explanation: String, @ViewBuilder action: () -> some View
    ) -> some View {
        let done = setup.current.map { step.rawValue < $0.rawValue } ?? true
        let isCurrent = setup.current == step
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : isCurrent ? .accentColor : .secondary)
                .font(.title2)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(explanation).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if isCurrent { action() }
            }
        }
        .opacity(done || isCurrent ? 1 : 0.5)
    }
}
