import AppKit
import SwiftUI

/// Where the Island sits on one screen, in screen coordinates.
public struct IslandLayout: Equatable, Sendable {
    /// The Island at full size; the panel always has this frame.
    public let frame: CGRect
    /// The notch's size, which the Island collapses into; nil on a screen without a notch.
    public let notch: CGSize?

    /// How far the working Island reaches past each side of the notch, the heights of a one-line and a
    /// two-line message row below it, and how much further a two-line row reaches past each side.
    static let overhang: CGFloat = 85
    static let rowHeight: CGFloat = 36
    static let twoLineRowHeight: CGFloat = 52
    static let twoLineOverhang: CGFloat = 13
    /// The width of each top corner that curves out into the screen edge, and the radius of the bottom corners.
    static let topCorner: CGFloat = 7
    static let bottomCorner: CGFloat = 14
    /// How far the Island at its widest reaches past each side of the notch.
    static let reach = overhang + twoLineOverhang + topCorner
    /// On a screen without a notch: the working pill's width, its width with a message, and its gap below the menu bar.
    static let floatingWidth: CGFloat = 167
    static let floatingMessageWidth: CGFloat = 312
    static let floatingGap: CGFloat = 6
    /// How far the busy shake moves the Island to each side.
    static let shake: CGFloat = 6

    public init(screenFrame: CGRect, visibleFrame: CGRect, safeAreaTop: CGFloat, topLeftArea: CGRect?, topRightArea: CGRect?) {
        if safeAreaTop > 0, let left = topLeftArea, let right = topRightArea {
            // The notch is centred: it is whatever the menu bar areas either side of it leave over.
            let notch = CGSize(width: screenFrame.width - left.width - right.width, height: safeAreaTop)
            let size = CGSize(width: notch.width + 2 * Self.reach, height: notch.height + Self.twoLineRowHeight)
            self.notch = notch
            frame = CGRect(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
        } else {
            // The working row with a two-line message row below it, with room to shake.
            let size = CGSize(width: Self.floatingMessageWidth + 2 * Self.shake, height: Self.rowHeight + Self.twoLineRowHeight)
            notch = nil
            frame = CGRect(x: screenFrame.midX - size.width / 2, y: visibleFrame.maxY - Self.floatingGap - size.height, width: size.width, height: size.height)
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
    @State private var message: Message?
    @State private var shakes: CGFloat = 0
    /// The length of the last Recording, so its time stays up, frozen, while it is transcribed.
    @State private var frozenElapsed: Duration = .zero
    /// The automatic stop being counted down to, once it is `countdownLead` away or less.
    @State private var countdown: Dictation.AutomaticStop?

    /// Scales the Microphone level (RMS, speech around 0.02...0.2) onto the waveform.
    /// ponytail: tuned by eye against one built-in mic; adjust if the waveform sits too low or pins.
    static let meterGain: Float = 2.5
    /// How long before an automatic stop its countdown shows.
    nonisolated static let countdownLead: Duration = .seconds(10)

    private var expanded: Bool {
        appeared && islandIsOut(dictation.state, showingSignal: showingSignal)
    }

    private var working: Bool {
        islandIsOut(dictation.state, showingSignal: false)
    }

    /// The row below the working row: the latest signal's message, else the countdown to an automatic stop.
    private var shown: Message? {
        message ?? countdown.map(Message.init(countdown:))
    }

    /// The Island's size: beside the notch at notch height, a pill while working when floating; plus the shown row
    /// below, which widens it. Collapsed, it shrinks into the notch (or to nothing).
    private var size: CGSize {
        let shown = shown
        let below = shown.map { $0.twoLines ? IslandLayout.twoLineRowHeight : IslandLayout.rowHeight } ?? 0
        if let notch {
            guard expanded else { return CGSize(width: notch.width + 2 * IslandLayout.topCorner, height: notch.height) }
            let reach = IslandLayout.reach - (shown?.twoLines == true ? 0 : IslandLayout.twoLineOverhang)
            return CGSize(width: notch.width + 2 * reach, height: notch.height + below)
        }
        guard expanded else { return .zero }
        return CGSize(
            width: shown == nil ? IslandLayout.floatingWidth : IslandLayout.floatingMessageWidth,
            height: (working ? IslandLayout.rowHeight : 0) + below)
    }

    var body: some View {
        ZStack(alignment: .top) {
            (notch == nil ? AnyShape(RoundedRectangle(cornerRadius: IslandLayout.rowHeight / 2)) : AnyShape(NotchShape())).fill(.black)
            if expanded { content }
        }
        .frame(width: size.width, height: size.height)
        .opacity(expanded ? 1 : 0)
        .modifier(Shake(shakes: shakes))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(duration: 0.35), value: size)
        .environment(\.colorScheme, .dark)
        .onAppear { appeared = true }
        .onChange(of: dictation.recordingStartedAt) { previousStart, _ in
            if let previousStart { frozenElapsed = ContinuousClock.now - previousStart }
        }
        .task(id: dictation.automaticStop) {
            countdown = nil
            guard let stop = dictation.automaticStop else { return }
            try? await Task.sleep(until: stop.at - Self.countdownLead, clock: .continuous)
            if !Task.isCancelled { countdown = stop }
        }
        .task(id: dictation.signal) {
            showingSignal = dictation.signal != nil
            message = nil
            guard let signal = dictation.signal else { return }
            let message = Message(signal.kind)
            self.message = message
            if signal.kind == .busy { withAnimation(.linear(duration: 0.4)) { shakes += 1 } }
            try? await Task.sleep(for: message.duration)
            if !Task.isCancelled {
                showingSignal = false
                self.message = nil
            }
        }
    }

    /// The working row (beside the notch, or the pill's top row), and the shown row below it.
    private var content: some View {
        TimelineView(.animation(paused: !working)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: 0) {
                if let notch {
                    ZStack { if working { workingRow(bars: 9, t: t) } }
                        .frame(height: notch.height)
                } else if working {
                    workingRow(bars: 7, t: t).frame(height: IslandLayout.rowHeight)
                }
                if let shown { messageRow(shown) }
            }
            .padding(.horizontal, notch == nil ? 0 : IslandLayout.topCorner)
        }
    }

    /// One line: the icon, the title and the detail side by side. Two lines: the icon, then the title
    /// with the fix line underneath, shrinking a little rather than cutting off.
    @ViewBuilder private func messageRow(_ message: Message) -> some View {
        let icon = icon(message)
        let title = Text(message.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
        if message.twoLines {
            HStack(spacing: 10) {
                icon.font(.system(size: 17))
                VStack(alignment: .leading, spacing: 1) {
                    title
                    Text(message.detail).font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                }
                .lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(height: IslandLayout.twoLineRowHeight)
        } else {
            HStack(spacing: 8) {
                icon.font(.system(size: 14))
                title
                if !message.detail.isEmpty {
                    Text(message.detail).font(.system(size: 12).monospacedDigit()).foregroundStyle(.white.opacity(0.6))
                }
            }
            .lineLimit(1)
            .frame(height: IslandLayout.rowHeight)
        }
    }

    /// A symbol in the message's colour, or an amber ring that runs out with the seconds left.
    @ViewBuilder private func icon(_ message: Message) -> some View {
        switch message.icon {
        case .symbol(let name): Image(systemName: name).foregroundStyle(message.tint)
        case .ring(let left):
            ZStack {
                Circle().stroke(.yellow.opacity(0.25), lineWidth: 2)
                Circle().trim(from: 0, to: left).stroke(.yellow, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 14, height: 14)
        case nil: EmptyView()
        }
    }

    /// The dot (or spinner) and the elapsed time on the left, the waveform (or shimmer) on the right.
    private func workingRow(bars: Int, t: Double) -> some View {
        let recording = dictation.state == .recording
        let level = dictation.automaticStop?.reason == .silence ? 0 : CGFloat(min(1, dictation.level.squareRoot() * Self.meterGain))
        let elapsed: Duration = recording ? dictation.recordingStartedAt.map { ContinuousClock.now - $0 } ?? .zero : frozenElapsed
        return HStack {
            HStack(spacing: 8) {
                ZStack { if recording { RecordingDot(t: t) } else { Spinner(t: t) } }.frame(width: 12, height: 12)
                Text(elapsed.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, roundFractionalSeconds: .towardZero))))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(recording ? 1 : 0.6))
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(0..<bars, id: \.self) { bar in
                    Self.bar(bar, t: t, level: recording ? level : nil)
                }
            }
            .animation(.easeOut(duration: 0.08), value: level)
        }
        .padding(.horizontal, 15)
    }

    /// One bar of the waveform, driven by the level while recording (a still dot at level 0); without a level, one step of the
    /// shimmer that runs across the bars while transcribing.
    private static func bar(_ bar: Int, t: Double, level: CGFloat?) -> some View {
        let (opacity, height): (Double, CGFloat)
        if let level {
            // Each bar sways at its own pace, so the waveform doesn't move as one block.
            let pace = [0.82, 0.64, 0.95, 0.58, 0.77, 1.02, 0.69, 0.88, 0.73][bar % 9]
            let sway = 0.6 + 0.4 * sin(t * 2 * .pi / pace + Double(bar))
            (opacity, height) = level == 0 ? (0.35, 3) : (1, 3 + 14 * level * sway)
        } else {
            let phase = (t - Double(bar) * 0.08).truncatingRemainder(dividingBy: 1)
            let peak = phase < 0.4 ? phase / 0.4 : (1 - phase) / 0.6
            (opacity, height) = (0.2 + 0.8 * peak, 5 * (1 + 0.8 * peak))
        }
        return Capsule().fill(.white.opacity(opacity)).frame(width: 3, height: height)
    }
}

/// What a message row says: an optional icon in its colour, the title in white, and a detail in grey,
/// beside the title on one line or underneath it as the fix line; and how long it stays up.
/// The Island owns all this wording.
private struct Message {
    enum Icon { case symbol(String), ring(left: Double) }
    var icon: Icon?
    var tint: Color = .white
    let title: String
    let detail: String
    var twoLines = false
    var duration: Duration = .seconds(1.5)
}

extension Message {
    /// The countdown to an automatic stop: the ring, what is about to stop the Dictation, and the seconds left.
    init(countdown stop: Dictation.AutomaticStop) {
        let left = max(.zero, stop.at - ContinuousClock.now)
        self.init(
            icon: .ring(left: left / IslandView.countdownLead), title: stop.reason == .silence ? "No speech" : "Time limit",
            detail: "stopping in \(Int((left / .seconds(1)).rounded(.up))) s")
    }

    /// Errors are red circles, the Setup step left is an amber triangle; both say what to do on a second line, for 3 s.
    init(_ kind: Dictation.Signal.Kind) {
        switch kind {
        case .busy:
            self.init(title: "Still transcribing", detail: "one moment")
        // How a Dictation ended: a green check for a paste, grey circles otherwise.
        case .pasted(let words):
            self.init(icon: .symbol("checkmark.circle.fill"), tint: .green, title: "Pasted", detail: words == 1 ? "1 word" : "\(words) words")
        case .cancelled:
            self.init(icon: .symbol("xmark.circle.fill"), tint: .white.opacity(0.6), title: "Cancelled", detail: "nothing pasted")
        case .nothingHeard:
            self.init(icon: .symbol("waveform.circle.fill"), tint: .white.opacity(0.6), title: "Nothing heard", detail: "")
        case .setupUnfinished:
            self.init(
                icon: .symbol("exclamationmark.triangle.fill"), tint: .yellow, title: "Finish Setup to dictate",
                detail: "Open Parlez from the menu bar", twoLines: true, duration: .seconds(3))
        case .error(let reason):
            let (title, fix) =
                switch reason {
                case .microphoneDidNotStart: ("Microphone didn't start", "System Settings › Privacy › Microphone")
                case .couldNotTranscribe: ("Couldn't transcribe", "Nothing was pasted. Try that Dictation again.")
                case .pasteFailed: ("Paste failed", "The Transcript is on your clipboard: press ⌘V")
                }
            self.init(icon: .symbol("exclamationmark.circle.fill"), tint: .red, title: title, detail: fix, twoLines: true, duration: .seconds(3))
        }
    }
}

/// The red recording dot, with a ring that pulses out of it.
private struct RecordingDot: View {
    let t: Double
    var body: some View {
        let pulse = min(1, (t / 1.6).truncatingRemainder(dividingBy: 1) / 0.6)
        Circle().fill(.red).frame(width: 8, height: 8)
            .background(Circle().fill(.red.opacity(0.55 * (1 - pulse))).padding(-4.5 * pulse))
    }
}

/// A thin spinner, turning once every 0.8 s.
private struct Spinner: View {
    let t: Double
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 1.7)
            Circle().trim(from: 0, to: 0.25).stroke(.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .rotationEffect(.degrees(t / 0.8 * 360))
        }
        .frame(width: 10, height: 10)
    }
}

/// The Island beside the notch: its top corners curve out into the screen edge like the notch's own,
/// and its bottom corners are rounded.
private struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let corner = IslandLayout.topCorner
        let (left, right) = (rect.minX + corner, rect.maxX - corner)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: left, y: rect.minY), tangent2End: CGPoint(x: left, y: rect.maxY), radius: corner)
        path.addArc(tangent1End: CGPoint(x: left, y: rect.maxY), tangent2End: CGPoint(x: right, y: rect.maxY), radius: IslandLayout.bottomCorner)
        path.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: right, y: rect.minY), radius: IslandLayout.bottomCorner)
        path.addArc(tangent1End: CGPoint(x: right, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: corner)
        path.closeSubpath()
        return path
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
        ProjectionTransform(CGAffineTransform(translationX: IslandLayout.shake * sin(shakes * .pi * 6), y: 0))
    }
}
