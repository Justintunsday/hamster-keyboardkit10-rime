//
//  DiagnosticsViewController.swift
//  HamsteriOS
//

import HamsterKit
import HamsterUIKit
import UIKit

/// Displays the bounded, privacy-preserving diagnostics shared by the host
/// app and keyboard extension.
public final class DiagnosticsViewController: NibLessViewController {
  private let textView = UITextView()

  override public func loadView() {
    title = "诊断日志"

    let rootView = UIView()
    rootView.backgroundColor = .systemBackground

    textView.isEditable = false
    textView.isSelectable = true
    textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    textView.textColor = .label
    textView.backgroundColor = .secondarySystemBackground
    textView.translatesAutoresizingMaskIntoConstraints = false
    rootView.addSubview(textView)
    NSLayoutConstraint.activate([
      textView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 12),
      textView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -12),
      textView.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 12),
      textView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12),
    ])

    view = rootView
  }

  override public func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(title: "刷新", style: .plain, target: self, action: #selector(refreshLogs)),
      UIBarButtonItem(title: "清除", style: .plain, target: self, action: #selector(clearLogs)),
      UIBarButtonItem(title: "分享", style: .plain, target: self, action: #selector(shareLogs)),
      UIBarButtonItem(title: "复制", style: .plain, target: self, action: #selector(copyLogs)),
    ]
    refreshLogs()
  }

  override public func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    refreshLogs()
  }

  @objc private func refreshLogs() {
    textView.text = HamsterDiagnostics.exportText()
    textView.scrollRangeToVisible(NSRange(location: textView.text.utf16.count, length: 0))
  }

  @objc private func copyLogs() {
    UIPasteboard.general.string = HamsterDiagnostics.exportText()
    let alert = UIAlertController(title: "已复制", message: "诊断日志已复制到剪贴板。", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "好", style: .default))
    present(alert, animated: true)
  }

  @objc private func shareLogs() {
    let activity = UIActivityViewController(
      activityItems: [HamsterDiagnostics.exportText()],
      applicationActivities: nil
    )
    if let popover = activity.popoverPresentationController {
      popover.barButtonItem = navigationItem.rightBarButtonItems?.first
    }
    present(activity, animated: true)
  }

  @objc private func clearLogs() {
    let alert = UIAlertController(
      title: "清除诊断日志？",
      message: "这会删除主 App 和键盘扩展共享的诊断记录。",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
    alert.addAction(UIAlertAction(title: "清除", style: .destructive) { [weak self] _ in
      HamsterDiagnostics.clear()
      self?.refreshLogs()
    })
    present(alert, animated: true)
  }
}