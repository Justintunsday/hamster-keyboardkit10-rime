//
//  KeyboardKit10InputViewController.swift
//  HamsterKeyboard
//
//  KeyboardKit 10.9.4 bridge for the Rime-backed keyboard extension.
//

import Combine
import HamsterKeyboardKit
import HamsterKit
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
    HamsterDiagnostics.beginSession(process: .keyboard)
    HamsterDiagnostics.record(process: .keyboard, category: "lifecycle", message: "Keyboard extension view loaded")
    observeRimeOutput()
  }

  override open func viewWillSetupKeyboardKit() {
    HamsterDiagnostics.record(process: .keyboard, category: "keyboardkit", message: "KeyboardKit setup started")
    setupKeyboardKit(for: .hamster) { result in
      switch result {
      case .success:
        HamsterDiagnostics.record(process: .keyboard, category: "keyboardkit", message: "KeyboardKit setup succeeded")
        self.services.actionHandler = KeyboardKit10ActionHandler(
          controller: self,
          rimeContext: self.hamsterRimeContext
        )
      case .failure(let error):
        NSLog("KeyboardKit setup failed: %@", error.localizedDescription)
        HamsterDiagnostics.record(process: .keyboard, severity: .error, category: "keyboardkit", message: "KeyboardKit setup failed")
      }
    }
  }

  override open func viewWillSetupKeyboardView() {
    HamsterDiagnostics.record(process: .keyboard, category: "keyboardkit", message: "KeyboardKit view setup started")
    setupKeyboardView { [weak self] controller in
      guard let self else { return AnyView(EmptyView()) }
      HamsterDiagnostics.record(process: .keyboard, category: "keyboardkit", message: "KeyboardKit view builder invoked")
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
    HamsterDiagnostics.endSession(process: .keyboard)
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
      HamsterDiagnostics.record(process: .keyboard, category: "rime", message: "Rime startup requested")
      await hamsterRimeContext.start(hasFullAccess: state.keyboardContext.hasFullAccess)
      HamsterDiagnostics.record(process: .keyboard, category: "rime", message: "Rime startup completed")
    }
  }
}

private extension KeyboardApp {
  static var hamster: KeyboardApp {
    .init(
      name: "仓输入法",
      appGroupId: "group.dev.fuxiao.app.Hamster"
    )
  }
}
