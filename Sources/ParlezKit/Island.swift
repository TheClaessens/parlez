import AppKit
import SwiftUI

/// Where the Island sits on one screen, in screen coordinates.
public struct IslandLayout: Equatable, Sendable {
    /// The Island at full size; the panel always has this frame.
    public let frame: CGRect
    /// The notch's size, which the Island collapses into; nil on a screen without a notch.
    public let notch: CGSize?

    /// How far the Island reaches past each side of the notch, and the height of its row below it.
    static let overhang: CGFloat = 20
    static let rowHeight: CGFloat = 36
    /// The Island's width on a screen without a notch, and its gap below the menu bar.
    static let floatingWidth: CGFloat = 220
    static let floatingGap: CGFloat = 6

    public init(screenFrame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat, topLeftArea: CGRect?, topRightArea: CGRect?) {
        if safeAreaTop > 0, let left = topLeftArea, let right = topRightArea {
            // The notch is centred: it is whatever the menu bar areas either side of it leave over.
            let notch = CGSize(width: screenFrame.width - left.width - right.width, height: safeAreaTop)
            let size = CGSize(width: notch.width + 2 * Self.overhang, height: notch.height + Self.rowHeight)
            self.notch = notch
            frame = CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
        } else {
            notch = nil
            frame = CGRect(
                x: screenFrame.midX - Self.floatingWidth / 2, y: visibleFrame.maxY - Self.floatingGap - Self.rowHeight,
                width: Self.floatingWidth, height: Self.rowHeight)
        }
    }

    init(_ screen: NSScreen) {
        self.init(
            screenFrame: screen.frame, visibleFrame: screen.visibleFrame, safeAreaTop: screen.safeAreaInsets.top,
            topLeftArea: screen.auxiliaryTopLeftArea, topRightArea: screen.auxiliaryTopRightArea)
    }
}

/// Whether the Island is out: during a Dictation, or while a signal is showing.
private func islandIsOut(_ state: Dictation.State, showingSignal: Bool) -> Bool {
    state == .recording || state == .transcribing || showingSignal
}

/// The Island: a borderless, non-activating panel at the top of the screen with the active menu bar.
/// It only renders the Dictation core's state and signals; it never takes focus or mouse input.
@MainActor public final class Island {
    private let dictation: Dictation
    private var panel: NSPanel?

    public init(dictation: Dictation) {
        self.dictation = dictation
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = dictation.state
            _ = dictation.signal
        } onChange: { [weak self] in
            Task { @MainActor in self?.changed() }
        }
    }

    private func changed() {
        // Move to the active menu bar's screen when the Island comes out, but not mid-Dictation
        // (transcribing follows recording, which already placed it).
        if dictation.state != .transcribing, islandIsOut(dictation.state, showingSignal: dictation.signal != nil) { place() }
        observe()
    }

    private func place() {
        // NSScreen.main is the screen holding the focused window, which is the one with the active menu bar.
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let layout = IslandLayout(screen)
        let panel = panel ?? makePanel()
        if panel.frame != layout.frame { panel.setFrame(layout.frame, display: false) }
        (panel.contentView as? NSHostingView<IslandView>)?.rootView = IslandView(dictation: dictation, notch: layout.notch)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar  // above the menu bar, so it can draw around the notch
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false  // Parlez is never the active app
        panel.contentView = NSHostingView(rootView: IslandView(dictation: dictation, notch: nil))
        self.panel = panel
        return panel
    }
}

struct IslandView: View {
    let dictation: Dictation
    let notch: CGSize?

    /// Lets the very first Island grow rather than appear at full size.
    @State private var appeared = false
    /// True while the latest signal is up, which keeps the Island out even with no Dictation running.
    @State private var showingSignal = false
    @State private var message: String?
    @State private var shakes: CGFloat = 0

    /// How long a busy shake and an error message stay up.
    static let shakeDuration: Duration = .seconds(0.6)
    static let messageDuration: Duration = .seconds(3)
    /// Scales the Microphone level (RMS, speech around 0.02...0.2) onto the meter.
    /// ponytail: tuned by eye against one built-in mic; adjust if the meter sits too low or pins.
    static let meterGain: Float = 2.5

    private var expanded: Bool {
        appeared && islandIsOut(dictation.state, showingSignal: showingSignal)
    }

    var body: some View {
        let collapsed = notch ?? .zero
        // Under the notch only the bottom corners are rounded; floating, it is a full pill.
        let (top, bottom): (CGFloat, CGFloat) = notch == nil ? (IslandLayout.rowHeight / 2, IslandLayout.rowHeight / 2) : (0, 14)
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(
                topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom, topTrailingRadius: top)
                .fill(.black)
            if expanded {
                content.frame(height: IslandLayout.rowHeight)
            }
        }
        .frame(width: expanded ? nil : collapsed.width, height: expanded ? nil : collapsed.height)
        .opacity(expanded ? 1 : 0)
        .modifier(Shake(shakes: shakes))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.35), value: expanded)
        .environment(\.colorScheme, .dark)
        .onAppear { appeared = true }
        .task(id: dictation.signal) {
            showingSignal = dictation.signal != nil
            message = nil
            guard let signal = dictation.signal else { return }
            if case .error(let text) = signal.kind {
                message = text
            } else {
                withAnimation(.linear(duration: 0.4)) { shakes += 1 }
            }
            try? await Task.sleep(for: message == nil ? Self.shakeDuration : Self.messageDuration)
            if !Task.isCancelled {
                showingSignal = false
                message = nil
            }
        }
    }

    @ViewBuilder private var content: some View {
        if let message {
            Text(message).font(.system(size: 12, weight: .medium)).foregroundStyle(.red).lineLimit(1)
        } else if dictation.state == .transcribing {
            ProgressView().controlSize(.small)
        } else {
            meter
        }
    }

    private var meter: some View {
        let level = CGFloat(min(1, dictation.level.squareRoot() * Self.meterGain))
        return HStack(spacing: 3) {
            ForEach(0..<5) { bar in
                Capsule().fill(.white).frame(width: 3, height: 4 + 16 * level * [0.5, 0.8, 1, 0.8, 0.5][bar])
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
    }
}

/// Shakes side to side once per whole step of `shakes`.
private struct Shake: GeometryEffect {
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(shakes * .pi * 6), y: 0))
    }
}
