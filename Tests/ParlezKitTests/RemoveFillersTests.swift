import ParlezKit
import Testing
import Voz

struct RemoveFillersTests {
    /// "So uh we ship Monday.", one word every half second.
    let text = "So uh we ship Monday."
    let words = [
        Word(text: "So", start: 0.0, end: 0.3),
        Word(text: "uh", start: 0.5, end: 0.8),
        Word(text: "we", start: 1.0, end: 1.3),
        Word(text: "ship", start: 1.5, end: 1.8),
        Word(text: "Monday.", start: 2.0, end: 2.6),
    ]

    func filler(_ start: Double, _ end: Double) -> ClosedRange<Double> { start...end }

    @Test func dropsAWordFullyInsideAFiller() {
        #expect(removeFillers(text: text, words: words, fillers: [filler(0.4, 0.9)]) == "So we ship Monday.")
    }

    @Test func keepsAWordOnlyPartlyInsideAFiller() {
        #expect(removeFillers(text: text, words: words, fillers: [filler(1.2, 1.4)]) == text)
    }

    @Test func returnsTheTextUnchangedWhenNoFillerCoversAWord() {
        #expect(removeFillers(text: text, words: words, fillers: []) == text)
        #expect(removeFillers(text: text, words: words, fillers: [filler(0.3, 0.5), filler(2.7, 3.0)]) == text)
    }

    @Test func isEmptyWhenEveryWordIsInsideAFiller() {
        #expect(removeFillers(text: text, words: words, fillers: [filler(0, 3)]) == "")
    }

    @Test func keepsThePunctuationOfTheWordsAroundADroppedFiller() {
        let words = [
            Word(text: "Well,", start: 0.0, end: 0.4),
            Word(text: "uh,", start: 0.5, end: 0.8),
            Word(text: "Monday.", start: 1.0, end: 1.5),
        ]
        #expect(removeFillers(text: "Well, uh, Monday.", words: words, fillers: [filler(0.45, 0.9)]) == "Well, Monday.")
    }

    /// Voz clamps the last words to the end of the Recording, which can leave them without duration.
    @Test func dropsAWordWithoutDurationInsideAFillerAndKeepsOneOutside() {
        let words = [
            Word(text: "So", start: 0.0, end: 0.3),
            Word(text: "uh", start: 0.6, end: 0.6),
            Word(text: "Bye.", start: 3.0, end: 3.0),
        ]
        #expect(removeFillers(text: "So uh Bye.", words: words, fillers: [filler(0.4, 0.9)]) == "So Bye.")
    }
}
