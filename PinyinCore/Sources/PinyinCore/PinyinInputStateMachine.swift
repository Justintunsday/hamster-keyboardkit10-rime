import Foundation

public final class PinyinInputStateMachine {
    public static let maxCompositionLength = 64

    public private(set) var state: CompositionState
    private let localEngine: PinyinEngine?
    private let rimeSession: RimeSession?

    public init(
        engine: PinyinEngine,
        state: CompositionState = CompositionState()
    ) {
        self.localEngine = engine
        self.state = state
        self.rimeSession = nil
        self.state.runtimeStatus = .local
    }

    public init(
        rimeSession: RimeSession,
        state: CompositionState = CompositionState()
    ) {
        self.localEngine = nil
        self.state = state
        self.rimeSession = rimeSession
        if rimeSession.isStarted {
            self.state.runtimeStatus = .rimeReady
            apply(rimeSession.snapshot)
        } else {
            let message = rimeSession.lastError?.localizedDescription
                ?? "RIME session is not started"
            self.state.runtimeStatus = .rimeFailed(message)
        }
    }

    @discardableResult
    public func input(_ text: String) -> PinyinTransition {
        guard !text.isEmpty else {
            return transition()
        }

        switch state.mode {
        case .chinese:
            return rimeSession == nil ? inputWithLocalEngine(text) : inputWithRime(text)

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

        if rimeSession != nil {
            guard processRime(.backspace) != nil else {
                return transition(clearMarkedText: true)
            }
            return transition(clearMarkedText: true)
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

        if rimeSession != nil {
            guard let snapshot = processRime(.candidate(index)) else {
                return transition(clearMarkedText: true)
            }
            return transition(
                insertedText: snapshot.committedText,
                clearMarkedText: true
            )
        }

        guard let selected = consume(candidate: state.candidates[index]) else {
            return transition()
        }
        return transition(insertedText: selected, clearMarkedText: true)
    }

    @discardableResult
    public func pressSpace() -> PinyinTransition {
        if state.mode == .chinese, !state.rawPinyin.isEmpty {
            if rimeSession != nil {
                guard let snapshot = processRime(.space),
                      let committedText = snapshot.committedText,
                      !committedText.isEmpty else {
                    markRimeFailure("RIME space key produced no committed text")
                    return transition(clearMarkedText: true)
                }
                return transition(insertedText: committedText, clearMarkedText: true)
            }

            let output = state.candidates.first?.text ?? state.rawPinyin
            clearComposition()
            return transition(insertedText: output, clearMarkedText: true)
        }
        return transition(insertedText: " ")
    }

    @discardableResult
    public func pressReturn() -> PinyinTransition {
        if state.mode == .chinese, !state.rawPinyin.isEmpty {
            if rimeSession != nil {
                guard let snapshot = processRime(.enter),
                      let committedText = snapshot.committedText,
                      !committedText.isEmpty else {
                    markRimeFailure("RIME return key produced no committed text")
                    return transition(clearMarkedText: true)
                }
                return transition(insertedText: committedText, clearMarkedText: true)
            }

            let output = state.rawPinyin
            clearComposition()
            return transition(insertedText: output, clearMarkedText: true)
        }
        return transition(insertedText: "\n")
    }

    @discardableResult
    public func setMode(_ mode: PinyinMode) -> PinyinTransition {
        var pendingText: String?
        if state.mode == .chinese, !state.rawPinyin.isEmpty {
            let originalRawPinyin = state.rawPinyin
            if rimeSession != nil {
                guard let snapshot = processRime(.space),
                      let committedText = snapshot.committedText,
                      !committedText.isEmpty else {
                    markRimeFailure("RIME mode switch produced no committed text")
                    return transition(clearMarkedText: true)
                }
                pendingText = committedText
            } else {
                pendingText = state.candidates.first?.text ?? originalRawPinyin
            }
        }

        resetRimeComposition()
        clearComposition()
        state.mode = mode
        return transition(insertedText: pendingText, clearMarkedText: true)
    }

    @discardableResult
    public func synchronizeMode(_ mode: PinyinMode) -> PinyinTransition {
        state.mode = mode
        if mode == .chinese {
            if let rimeSession {
                if rimeSession.isStarted {
                    apply(rimeSession.snapshot)
                } else {
                    markRimeFailure(rimeSession.lastError?.localizedDescription
                        ?? "RIME session is not started")
                }
            } else {
                refreshCandidates()
            }
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

    private func inputWithLocalEngine(_ text: String) -> PinyinTransition {
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
    }

    private func inputWithRime(_ text: String) -> PinyinTransition {
        guard let rimeSession, rimeSession.isStarted else {
            markRimeFailure(rimeSession?.lastError?.localizedDescription
                ?? "RIME session is not started")
            return transition(clearMarkedText: true)
        }

        var accepted = false
        var insertedOutput = ""

        for character in text.lowercased() {
            if chinesePunctuation(for: character) != nil {
                guard let snapshot = processRime(.text(String(character))) else {
                    break
                }
                insertedOutput += snapshot.committedText ?? ""
                accepted = true
                continue
            }

            if let digit = character.wholeNumberValue, (1...9).contains(digit) {
                if !state.rawPinyin.isEmpty,
                   state.candidates.indices.contains(digit - 1),
                   let snapshot = processRime(.candidate(digit - 1)) {
                    insertedOutput += snapshot.committedText ?? ""
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
            guard let snapshot = processRime(.text(String(character))) else {
                break
            }
            insertedOutput += snapshot.committedText ?? ""
            accepted = true
        }

        return transition(
            insertedText: insertedOutput.isEmpty ? nil : insertedOutput,
            clearMarkedText: accepted || !insertedOutput.isEmpty
        )
    }

    private func processRime(_ key: RimeKey) -> RimeSnapshot? {
        guard let rimeSession, rimeSession.isStarted else {
            markRimeFailure(rimeSession?.lastError?.localizedDescription
                ?? "RIME session is not started")
            return nil
        }
        do {
            let snapshot = try rimeSession.process(key)
            apply(snapshot)
            return snapshot
        } catch {
            markRimeFailure(error.localizedDescription)
            return nil
        }
    }

    private func resetRimeComposition() {
        guard let rimeSession, rimeSession.isStarted else {
            return
        }
        if let snapshot = try? rimeSession.reset() {
            apply(snapshot)
        } else {
            markRimeFailure(rimeSession.lastError?.localizedDescription
                ?? "RIME composition reset failed")
        }
    }

    private func apply(_ snapshot: RimeSnapshot) {
        state.runtimeStatus = .rimeReady
        state.rawPinyin = snapshot.rawInput.isEmpty ? snapshot.preedit : snapshot.rawInput
        state.candidates = snapshot.pinyinCandidates
    }

    private func markRimeFailure(_ message: String) {
        state.runtimeStatus = .rimeFailed(message)
    }

    private func refreshCandidates() {
        guard let localEngine else {
            markRimeFailure("RIME candidate state is unavailable")
            return
        }
        state.candidates = localEngine.candidates(for: state.rawPinyin, limit: 30)
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
