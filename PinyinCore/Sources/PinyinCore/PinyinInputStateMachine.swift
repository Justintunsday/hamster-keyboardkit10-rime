import Foundation

public final class PinyinInputStateMachine {
    public static let maxCompositionLength = 64

    public private(set) var state: CompositionState
    private let engine: PinyinEngine

    public init(
        engine: PinyinEngine = LocalPinyinEngine(),
        state: CompositionState = CompositionState()
    ) {
        self.engine = engine
        self.state = state
    }

    @discardableResult
    public func input(_ text: String) -> PinyinTransition {
        guard !text.isEmpty else {
            return transition()
        }

        switch state.mode {
        case .chinese:
            var accepted = false
            var insertedOutput = ""
            for character in text.lowercased() {
                if let punctuation = chinesePunctuation(for: character) {
                    if !state.rawPinyin.isEmpty {
                        insertedOutput += state.candidates.first?.text ?? state.rawPinyin
                        clearComposition()
                    }
                    insertedOutput += punctuation
                    continue
                }

                if let digit = character.wholeNumberValue, (1...9).contains(digit) {
                    if !state.rawPinyin.isEmpty,
                       state.candidates.indices.contains(digit - 1) {
                        let candidate = state.candidates[digit - 1]
                        if let text = consume(candidate: candidate) {
                            insertedOutput += text
                        }
                    } else if state.rawPinyin.isEmpty {
                        insertedOutput += String(character)
                    }
                    continue
                }

                guard isASCIILetter(character) else {
                    continue
                }
                guard state.rawPinyin.count < Self.maxCompositionLength else {
                    continue
                }
                state.rawPinyin.append(character)
                accepted = true
            }
            if accepted && !state.rawPinyin.isEmpty {
                refreshCandidates()
            }
            return transition(
                insertedText: insertedOutput.isEmpty ? nil : insertedOutput,
                clearMarkedText: accepted || !insertedOutput.isEmpty
            )

        case .english:
            let output = state.isShifted || state.isCapsLocked
                ? text.uppercased()
                : text
            if !state.isCapsLocked {
                state.isShifted = false
            }
            return transition(insertedText: output)

        case .numbers:
            let output = text.filter(\.isNumber)
            return transition(insertedText: output.isEmpty ? nil : output)

        case .symbols:
            let output = text.map { chineseSymbol(for: $0) }.joined()
            return transition(insertedText: output.isEmpty ? nil : output)
        }
    }

    @discardableResult
    public func deleteBackward() -> PinyinTransition {
        guard state.mode == .chinese, !state.rawPinyin.isEmpty else {
            return transition(shouldDeleteBackward: true, clearMarkedText: true)
        }

        state.rawPinyin.removeLast()
        refreshCandidates()
        return transition(clearMarkedText: true)
    }

    @discardableResult
    public func selectCandidate(at index: Int) -> PinyinTransition {
        guard state.mode == .chinese, state.candidates.indices.contains(index) else {
            return transition()
        }

        guard let selected = consume(candidate: state.candidates[index]) else {
            return transition()
        }
        return transition(insertedText: selected, clearMarkedText: true)
    }

    @discardableResult
    public func pressSpace() -> PinyinTransition {
        if state.mode == .chinese, !state.rawPinyin.isEmpty {
            let output = state.candidates.first?.text ?? state.rawPinyin
            clearComposition()
            return transition(insertedText: output, clearMarkedText: true)
        }
        return transition(insertedText: " ")
    }

    @discardableResult
    public func pressReturn() -> PinyinTransition {
        if state.mode == .chinese, !state.rawPinyin.isEmpty {
            let output = state.rawPinyin
            clearComposition()
            return transition(insertedText: output, clearMarkedText: true)
        }
        return transition(insertedText: "\n")
    }

    @discardableResult
    public func setMode(_ mode: PinyinMode) -> PinyinTransition {
        let pendingText: String?
        if state.mode == .chinese, !state.rawPinyin.isEmpty {
            pendingText = state.candidates.first?.text ?? state.rawPinyin
        } else {
            pendingText = nil
        }

        clearComposition()
        state.mode = mode
        return transition(insertedText: pendingText, clearMarkedText: true)
    }

    @discardableResult
    public func synchronizeMode(_ mode: PinyinMode) -> PinyinTransition {
        state.mode = mode
        if mode == .chinese {
            refreshCandidates()
        } else {
            state.candidates = []
        }
        return transition()
    }

    @discardableResult
    public func toggleChineseEnglish() -> PinyinTransition {
        switch state.mode {
        case .chinese:
            return setMode(.english)
        case .english:
            return setMode(.chinese)
        case .numbers, .symbols:
            return setMode(.chinese)
        }
    }

    @discardableResult
    public func toggleShift() -> PinyinTransition {
        state.isShifted.toggle()
        return transition()
    }

    @discardableResult
    public func toggleCapsLock() -> PinyinTransition {
        state.isCapsLocked.toggle()
        state.isShifted = state.isCapsLocked
        return transition()
    }

    private func refreshCandidates() {
        state.candidates = engine.candidates(for: state.rawPinyin, limit: 30)
    }

    private func clearComposition() {
        state.rawPinyin = ""
        state.candidates = []
    }

    private func consume(candidate: PinyinCandidate) -> String? {
        guard state.mode == .chinese,
              state.rawPinyin.hasPrefix(candidate.pinyin) else {
            return nil
        }

        state.rawPinyin = String(state.rawPinyin.dropFirst(candidate.pinyin.count))
        if state.rawPinyin.isEmpty {
            state.candidates = []
        } else {
            refreshCandidates()
        }
        return candidate.text
    }

    private func transition(
        insertedText: String? = nil,
        shouldDeleteBackward: Bool = false,
        clearMarkedText: Bool = false
    ) -> PinyinTransition {
        PinyinTransition(
            state: state,
            insertedText: insertedText,
            shouldDeleteBackward: shouldDeleteBackward,
            clearMarkedText: clearMarkedText
        )
    }

    private func isASCIILetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else {
            return false
        }
        return scalar.value >= 97 && scalar.value <= 122
    }

    private func chinesePunctuation(for character: Character) -> String? {
        switch character {
        case ",":
            return "，"
        case ".":
            return "。"
        case "?":
            return "？"
        case "!":
            return "！"
        case ":":
            return "："
        case ";":
            return "；"
        case "(":
            return "（"
        case ")":
            return "）"
        case "[":
            return "【"
        case "]":
            return "】"
        case "{":
            return "｛"
        case "}":
            return "｝"
        case "\"":
            return "“"
        case "'":
            return "‘"
        case "/":
            return "／"
        case "-":
            return "－"
        case "~":
            return "～"
        default:
            return nil
        }
    }

    private func chineseSymbol(for character: Character) -> String {
        chinesePunctuation(for: character) ?? String(character)
    }
}
