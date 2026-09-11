//
//  KeyboardKit10InputViewController.swift
//  HamsterKeyboard
//
//  KeyboardKit 10.9.4 bridge for the Rime-backed keyboard extension.
//

import Combine
import HamsterKit
import HamsterKeyboardKit
import KeyboardKit
import SwiftUI
import UIKit

/// KeyboardKit 10 host that keeps Hamster's Rime engine behind the stable
/// KeyboardKit controller and service APIs.
open class KeyboardKit10InputViewController: KeyboardKit.KeyboardInputViewController {
  public let hamsterRimeContext = RimeContext()
  private var rimeCancellables = Set<AnyCancellable>()

  override open func viewDidLoad() {
    super.viewDidLoad()
    observeRimeOutput()
  }

  override open func viewWillSetupKeyboardKit() {
    setupKeyboardKit(for: .hamster) { result in
      switch result {
      case .success:
        self.services.actionHandler = KeyboardKit10ActionHandler(
          controller: self,
          rimeContext: self.hamsterRimeContext
        )
      case .failure(let error):
        NSLog("KeyboardKit setup failed: %@", error.localizedDescription)
      }
    }
  }

  override open func viewWillSetupKeyboardView() {
    setupKeyboardView { [weak self] controller in
      guard let self else { return AnyView(EmptyView()) }
      return AnyView(
        HamsterKeyboardKit10View(
          services: controller.services,
          state: controller.state,
          rimeContext: hamsterRimeContext
        )
      )
    }
  }

  deinit {
    rimeCancellables.removeAll()
    hamsterRimeContext.shutdown()
  }
}

private extension KeyboardKit10InputViewController {
  func observeRimeOutput() {
    hamsterRimeContext.userInputKeyPublished
      .receive(on: DispatchQueue.main)
      .sink { [weak self] inputText in
        guard let self else { return }

        // RimeContext publishes only after commitText has been assigned. Read
        // and clear it exactly once so a commit cannot be inserted twice.
        let commitText = hamsterRimeContext.commitText
        hamsterRimeContext.resetCommitText()
        if !commitText.isEmpty {
          textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
          textDocumentProxy.insertText(commitText)
        }

        textDocumentProxy.setMarkedText(
          inputText,
          selectedRange: NSRange(location: inputText.utf16.count, length: 0)
        )
      }
      .store(in: &rimeCancellables)

    Task {
      await hamsterRimeContext.start(hasFullAccess: state.keyboardContext.hasFullAccess)
    }
  }
}

private extension KeyboardApp {
  static var hamster: KeyboardApp {
    .init(
      name: "仓输入法",
      appGroupId: HamsterConstants.appGroupName
    )
  }
}
