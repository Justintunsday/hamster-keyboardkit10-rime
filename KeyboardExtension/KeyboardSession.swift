import Combine
import PinyinCore

final class KeyboardSession: ObservableObject {
    @Published private(set) var state: CompositionState
    private let machine: PinyinInputStateMachine

    init(engine: PinyinEngine? = nil) {
        if let engine {
            let machine = PinyinInputStateMachine(engine: engine)
            self.machine = machine
            self.state = machine.state
            return
        }

        let rimeSession: RimeSession
        do {
            let adapter = RimeEngineAdapter()
            rimeSession = try adapter.makeBundledSession(
                applicationIdentifier: "PinyinKeyboard.KeyboardExtension"
            )
            do {
                try rimeSession.start()
            } catch {
                rimeSession.stop()
                let failedSession = RimeSession(failure: .native(error.localizedDescription))
                let failedMachine = PinyinInputStateMachine(rimeSession: failedSession)
                self.machine = failedMachine
                self.state = failedMachine.state
                return
            }
        } catch {
            let failedSession = RimeSession(failure: .native(error.localizedDescription))
            let failedMachine = PinyinInputStateMachine(rimeSession: failedSession)
            self.machine = failedMachine
            self.state = failedMachine.state
            return
        }

        let machine = PinyinInputStateMachine(rimeSession: rimeSession)
        self.machine = machine
        self.state = machine.state
    }

    @discardableResult
    func input(_ text: String) -> PinyinTransition {
        apply(machine.input(text))
    }

    @discardableResult
    func deleteBackward() -> PinyinTransition {
        apply(machine.deleteBackward())
    }

    @discardableResult
    func selectCandidate(at index: Int) -> PinyinTransition {
        apply(machine.selectCandidate(at: index))
    }

    @discardableResult
    func pressSpace() -> PinyinTransition {
        apply(machine.pressSpace())
    }

    @discardableResult
    func pressReturn() -> PinyinTransition {
        apply(machine.pressReturn())
    }

    @discardableResult
    func setMode(_ mode: PinyinMode) -> PinyinTransition {
        apply(machine.setMode(mode))
    }

    @discardableResult
    func synchronizeMode(_ mode: PinyinMode) -> PinyinTransition {
        apply(machine.synchronizeMode(mode))
    }

    @discardableResult
    func toggleChineseEnglish() -> PinyinTransition {
        apply(machine.toggleChineseEnglish())
    }

    @discardableResult
    func toggleShift() -> PinyinTransition {
        apply(machine.toggleShift())
    }

    @discardableResult
    func toggleCapsLock() -> PinyinTransition {
        apply(machine.toggleCapsLock())
    }

    private func apply(_ transition: PinyinTransition) -> PinyinTransition {
        state = transition.state
        return transition
    }
}
