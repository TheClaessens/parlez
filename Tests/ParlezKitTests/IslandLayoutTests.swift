import CoreGraphics
import ParlezKit
import Testing

struct IslandLayoutTests {
    @Test func growsOutOfTheNotchOfABuiltInDisplay() {
        // A 14" MacBook Pro: 1512 pt wide, a 38 pt top inset and 646 pt of menu bar either side of a 220 pt notch.
        let layout = IslandLayout(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 944),
            safeAreaTop: 38,
            topLeftArea: CGRect(x: 0, y: 944, width: 646, height: 38),
            topRightArea: CGRect(x: 866, y: 944, width: 646, height: 38))

        #expect(layout.notch == CGSize(width: 220, height: 38))
        #expect(layout.frame == CGRect(x: 541, y: 892, width: 430, height: 90))
    }

    @Test func floatsAtTheTopCentreOfAScreenWithoutANotch() {
        // An external 1920x1080 display to the right of the built-in one, with a 25 pt menu bar.
        let layout = IslandLayout(
            screenFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1055),
            safeAreaTop: 0,
            topLeftArea: nil,
            topRightArea: nil)

        #expect(layout.notch == nil)
        #expect(layout.frame == CGRect(x: 2316, y: 997, width: 312, height: 52))
    }
}
