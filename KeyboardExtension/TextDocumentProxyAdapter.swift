import UIKit
import PinyinCore

final class TextDocumentProxyAdapter {
    weak var proxy: UITextDocumentProxy?

    init(proxy: UITextDocumentProxy? = nil) {
        self.proxy = proxy
    }

    func apply(_ transition: PinyinTransition) {
        guard let proxy else {
            return
        }

        if transition.clearMarkedText {
            proxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        }

        if transition.shouldDeleteBackward {
            proxy.deleteBackward()
        }

        if let insertedText = transition.insertedText, !insertedText.isEmpty {
            proxy.insertText(insertedText)
        }

        if transition.state.mode == .chinese,
           !transition.state.rawPinyin.isEmpty {
            let location = transition.state.rawPinyin.utf16.count
            proxy.setMarkedText(
                transition.state.rawPinyin,
                selectedRange: NSRange(location: location, length: 0)
            )
        } else if transition.clearMarkedText {
            proxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
        }
    }
}
