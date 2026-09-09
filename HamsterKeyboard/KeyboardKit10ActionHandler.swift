//
//  KeyboardKit10ActionHandler.swift
//  HamsterKeyboard
//
//  Rime action routing for KeyboardKit 10.9.4.
//

import HamsterKit
import HamsterKeyboardKit
import KeyboardKit
import UIKit

final class KeyboardKit10ActionHandler: KeyboardKit.StandardKeyboardActionHandler {
  private weak var inputController: KeyboardKit.KeyboardInputViewController?
  private let rimeContext: RimeContext

  init(
    controller: KeyboardKit.KeyboardInputViewController,
    rimeContext: RimeContext
  ) {
    self.inputController = controller
    self.rimeContext = rimeContext
    super.init(
      controller: controller,
      keyboardContext: controller.state.keyboardContext,
      keyboardBehavior: controller.services.keyboardBehavior,
      autocompleteContext: controller.state.autocompleteContext,
      autocompleteService: controller.services.autocompleteService,
      emojiContext: controller.state.emojiContext,
      feedbackContext: controller.state.feedbackContext,
      feedbackService: controller.services.feedbackService,
      keyboardAppContext: controller.state.keyboardAppContext,
      spacebarDragGestureHandler: controller.services.spacebarDragGestureHandler
    )
  }

  override func action(
    for gesture: KeyboardKit.Keyboard.Gesture,
    on action: KeyboardKit.KeyboardAction
  ) -> KeyboardKit.KeyboardAction.GestureAction? {
    switch (gesture, action) {
    case (.release, .character(let character)):
      return { [weak self] _ in self?.insert(character) }
    case (.release, .backspace), (.repeatPress, .backspace):
      return { [weak self] _ in self?.deleteBackward() }
    case (.release, .space):
      return { [weak self] _ in self?.sendRimeKey(XK_space, fallback: " ") }
    case (.release, .primary):
      return { [weak self] _ in self?.sendRimeKey(XK_Return, fallback: "\n") }
    case (.release, .nextKeyboard):
      return { [weak self] _ in self?.inputController?.advanceToNextInputMode() }
    default:
      return super.action(for: gesture, on: action)
    }
  }
}

private extension KeyboardKit10ActionHandler {
  func insert(_ text: String) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      if !rimeContext.asciiMode, rimeContext.tryHandleInputText(text) { return }
      inputController?.textDocumentProxy.insertText(text)
    }
  }

  func deleteBackward() {
    Task { @MainActor [weak self] in
      guard let self else { return }
      if !rimeContext.userInputKey.isEmpty {
        rimeContext.deleteBackward()
      } else {
        inputController?.textDocumentProxy.deleteBackward()
      }
    }
  }

  func sendRimeKey(_ keyCode: Int32, fallback: String) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      if !rimeContext.asciiMode, rimeContext.tryHandleInputCode(keyCode) { return }
      inputController?.textDocumentProxy.insertText(fallback)
    }
  }
}
