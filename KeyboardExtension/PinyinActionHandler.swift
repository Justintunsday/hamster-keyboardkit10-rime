import KeyboardKit
import PinyinCore

final class PinyinActionHandler: KeyboardAction.StandardKeyboardActionHandler {
    private let session: KeyboardSession
    private let applyTransition: (PinyinTransition) -> Void
    private weak var hostController: KeyboardInputViewController?
    private var lastKeyboardType: Keyboard.KeyboardType

    init(
        controller: KeyboardInputViewController,
        session: KeyboardSession,
        applyTransition: @escaping (PinyinTransition) -> Void
    ) {
        self.session = session
        self.applyTransition = applyTransition
        self.hostController = controller
        self.lastKeyboardType = controller.state.keyboardContext.keyboardType
        super.init(controller: controller)
    }

    override func handle(_ gesture: Keyboard.Gesture, on action: KeyboardAction) {
        switch action {
        case .character(let text):
            guard gesture == .release else {
                return
            }
            applyTransition(session.input(text))

        case .backspace:
            guard gesture == .release || gesture == .repeatPress else {
                return
            }
            applyTransition(session.deleteBackward())

        case .space:
            guard gesture == .release else {
                return
            }
            applyTransition(session.pressSpace())

        case .primary:
            guard gesture == .release else {
                return
            }
            applyTransition(session.pressReturn())

        case .shift:
            if gesture == .release {
                applyTransition(session.toggleShift())
            }
            super.handle(gesture, on: action)

        case .nextKeyboard:
            guard gesture == .release else {
                return
            }
            hostController?.advanceToNextInputMode()

        default:
            super.handle(gesture, on: action)
        }

        synchronizeSessionModeIfNeeded(for: gesture)
    }

    private func synchronizeSessionModeIfNeeded(for gesture: Keyboard.Gesture) {
        guard gesture == .release,
              let hostController else {
            return
        }

        let currentKeyboardType = hostController.state.keyboardContext.keyboardType
        defer {
            lastKeyboardType = currentKeyboardType
        }
        guard currentKeyboardType != lastKeyboardType,
              let mode = pinyinMode(for: currentKeyboardType),
              session.state.mode != mode else {
            return
        }

        applyTransition(session.synchronizeMode(mode))
    }

    private func pinyinMode(for keyboardType: Keyboard.KeyboardType) -> PinyinMode? {
        switch keyboardType {
        case .alphabetic:
            return .english
        case .numeric:
            return .numbers
        case .symbolic:
            return .symbols
        default:
            return nil
        }
    }
}
