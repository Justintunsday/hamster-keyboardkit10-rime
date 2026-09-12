import XCTest
@testable import PinyinCore

final class PinyinCoreTests: XCTestCase {
    private let engine = LocalPinyinEngine()

    func testNihaoCandidate() {
        let candidates = engine.candidates(for: "nihao", limit: 10)
        XCTAssertEqual(candidates.first?.text, "你好")
        XCTAssertTrue(candidates.contains { $0.text == "你" })
    }

    func testZhongguoCandidate() {
        XCTAssertEqual(engine.candidates(for: "zhongguo", limit: 10).first?.text, "中国")
    }

    func testWoainiCandidate() {
        XCTAssertEqual(engine.candidates(for: "woaini", limit: 10).first?.text, "我爱你")
    }

    func testXiexieCandidate() {
        XCTAssertEqual(engine.candidates(for: "xiexie", limit: 10).first?.text, "谢谢")
    }

    func testDynamicProgrammingSegmentation() {
        XCTAssertEqual(engine.bestSegmentation(for: "woaini"), ["wo", "ai", "ni"])
        XCTAssertEqual(engine.bestSegmentation(for: "zhongguo"), ["zhong", "guo"])
    }

    func testPinyinBackspacePrecedesDocumentDeletion() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("ni")

        let first = machine.deleteBackward()
        XCTAssertEqual(first.state.rawPinyin, "n")
        XCTAssertFalse(first.shouldDeleteBackward)

        let second = machine.deleteBackward()
        XCTAssertEqual(second.state.rawPinyin, "")
        XCTAssertFalse(second.shouldDeleteBackward)

        let third = machine.deleteBackward()
        XCTAssertTrue(third.shouldDeleteBackward)
    }

    func testCandidateSelectionCommitsText() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("nihao")

        let transition = machine.selectCandidate(at: 0)
        XCTAssertEqual(transition.insertedText, "你好")
        XCTAssertEqual(transition.state.rawPinyin, "")
    }

    func testCandidateSelectionConsumesOnlyItsPinyinPrefix() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("nihao")
        guard let index = machine.state.candidates.firstIndex(where: { $0.text == "你" }) else {
            return XCTFail("candidate 你 is missing")
        }

        let transition = machine.selectCandidate(at: index)
        XCTAssertEqual(transition.insertedText, "你")
        XCTAssertEqual(transition.state.rawPinyin, "hao")
        XCTAssertTrue(transition.state.candidates.contains { $0.text == "好" })
    }

    func testSpaceCommitsFirstCandidate() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("zhongguo")

        let transition = machine.pressSpace()
        XCTAssertEqual(transition.insertedText, "中国")
        XCTAssertEqual(transition.state.rawPinyin, "")
    }

    func testReturnCommitsRawPinyin() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("shang")

        let transition = machine.pressReturn()
        XCTAssertEqual(transition.insertedText, "shang")
        XCTAssertEqual(transition.state.rawPinyin, "")
    }

    func testChineseEnglishSwitchCommitsComposition() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("ni")

        let toEnglish = machine.toggleChineseEnglish()
        XCTAssertEqual(toEnglish.insertedText, "你")
        XCTAssertEqual(toEnglish.state.mode, .english)

        let toChinese = machine.toggleChineseEnglish()
        XCTAssertEqual(toChinese.state.mode, .chinese)
    }

    func testNoCandidateFallsBackToRawPinyin() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("shang")
        XCTAssertTrue(machine.state.candidates.isEmpty)

        let transition = machine.pressSpace()
        XCTAssertEqual(transition.insertedText, "shang")
    }

    func testChinesePunctuationCommitsCompositionThenPunctuation() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("ni")

        let transition = machine.input(",")
        XCTAssertEqual(transition.insertedText, "你，")
        XCTAssertEqual(transition.state.rawPinyin, "")
    }

    func testChinesePunctuationWithoutCompositionIsInsertedDirectly() {
        let machine = PinyinInputStateMachine(engine: engine)
        XCTAssertEqual(machine.input(",").insertedText, "，")
    }

    func testIncompletePinyinRemainsEditable() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("abc")
        XCTAssertEqual(machine.state.rawPinyin, "abc")
        _ = machine.deleteBackward()
        XCTAssertEqual(machine.state.rawPinyin, "ab")
        _ = machine.input("d")
        XCTAssertEqual(machine.state.rawPinyin, "abd")
    }

    func testCompositionIsLimitedTo64ASCIICharacters() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input(String(repeating: "z", count: 80))
        XCTAssertEqual(machine.state.rawPinyin.count, 64)
    }

    func testDigitSelectsCandidateWhenCompositionExists() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("nihao")
        let transition = machine.input("2")
        XCTAssertEqual(transition.insertedText, "你")
        XCTAssertEqual(transition.state.rawPinyin, "hao")
    }

    func testSynchronizeNumericModeBackToChineseKeepsStateConsistent() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.input("ni")

        _ = machine.synchronizeMode(.numbers)
        XCTAssertEqual(machine.state.mode, .numbers)
        XCTAssertEqual(machine.state.rawPinyin, "ni")
        XCTAssertTrue(machine.state.candidates.isEmpty)

        _ = machine.synchronizeMode(.chinese)
        XCTAssertEqual(machine.state.mode, .chinese)
        XCTAssertEqual(machine.state.rawPinyin, "ni")
        XCTAssertFalse(machine.state.candidates.isEmpty)
    }

    func testExactCandidateRanksBeforePrefixCandidate() {
        let candidates = engine.candidates(for: "ni", limit: 10)
        XCTAssertEqual(candidates.first?.text, "你")
        XCTAssertTrue(candidates.dropFirst().contains { $0.text == "你好" })
    }

    func testModeSpecificTextInput() {
        let machine = PinyinInputStateMachine(engine: engine)
        _ = machine.setMode(.english)
        XCTAssertEqual(machine.input("a").insertedText, "a")
        _ = machine.toggleShift()
        XCTAssertEqual(machine.input("b").insertedText, "B")
        _ = machine.setMode(.symbols)
        XCTAssertEqual(machine.input(",").insertedText, "，")
    }
}
