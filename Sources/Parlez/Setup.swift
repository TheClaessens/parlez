import AVFoundation
import ApplicationServices
import ParlezKit
import SwiftUI

/// Setup: gets the Microphone and Accessibility permissions and prepares the speech model, then tells the
/// Dictation core it is complete. Its window opens at launch only when a step is not satisfied.
/// ponytail: checked at launch only; a permission revoked while Parlez runs is caught at the next launch.
@MainActor @Observable
final class Setup {
    enum Step: Int { case microphone, accessibility, model }

    private(set) var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    private(set) var accessibility = AXIsProcessTrusted()
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

    /// Called once at launch. With everything in place this only loads the model (~0.3 s), with no window.
    func start() {
        if microphone != .authorized || !accessibility || !VozTranscriber.isModelDownloaded { show() }
        Task { await run() }
    }

    /// Re-checks the permissions every second, so a grant in System Settings is seen without a restart,
    /// and prepares the model once it is the current step.
    private func run() async {
        while current != nil {
            microphone = AVCaptureDevice.authorizationStatus(for: .audio)
            accessibility = AXIsProcessTrusted()
            if current == .model, modelProgress == nil, !modelFailed { await prepareModel() }
            try? await Task.sleep(for: .seconds(1))
        }
        dictation.setupCompleted()
        window?.close()
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
            microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        }
    }

    func retryModel() { modelFailed = false }

    func openSystemSettings(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
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
        // Parlez has no Dock icon, so activate it to bring the window to the front.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
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
                    Button("Open System Settings") { setup.openSystemSettings("Privacy_Microphone") }
                }
            }
            step(.accessibility, "Accessibility",
                 "Parlez pastes your Transcript by pressing ⌘V for you, which macOS only allows with Accessibility "
                 + "permission. Turn Parlez on in the list; this window moves on by itself.") {
                Button("Open System Settings") { setup.openSystemSettings("Privacy_Accessibility") }
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
