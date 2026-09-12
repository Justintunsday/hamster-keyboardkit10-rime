import KeyboardKit
import PinyinCore
import SwiftUI
import UIKit

final class KeyboardViewController: KeyboardInputViewController {
    private let session = KeyboardSession()
    private lazy var proxyAdapter = TextDocumentProxyAdapter(proxy: textDocumentProxy)

    override func viewWillSetupKeyboardKit() {
        setupKeyboardKit(for: .pinyinKeyboard) { [weak self] _ in
            guard let self else {
                return
            }
            self.services.actionHandler = PinyinActionHandler(
                controller: self,
                session: self.session,
                applyTransition: { [weak self] transition in
                    self?.apply(transition)
                }
            )
        }
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { [weak self] controller in
            guard let self else {
                return EmptyView()
            }
            return PinyinKeyboardView(
                services: controller.services,
                session: self.session,
                onTransition: { [weak self] transition in
                    self?.apply(transition)
                },
                onModeChange: { [weak self] mode in
                    self?.setMode(mode)
                }
            )
        }
    }

    private func apply(_ transition: PinyinTransition) {
        proxyAdapter.proxy = textDocumentProxy
        proxyAdapter.apply(transition)
    }

    private func setMode(_ mode: PinyinMode) {
        apply(session.setMode(mode))
        switch mode {
        case .chinese, .english:
            state.keyboardContext.keyboardType = .alphabetic
        case .numbers:
            state.keyboardContext.keyboardType = .numeric
        case .symbols:
            state.keyboardContext.keyboardType = .symbolic
        }
        reloadInputViews()
    }
}

private extension KeyboardApp {
    static var pinyinKeyboard: KeyboardApp {
        KeyboardApp(name: "Pinyin Keyboard")
    }
}
