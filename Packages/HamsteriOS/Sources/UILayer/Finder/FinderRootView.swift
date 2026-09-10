//
//  FinderRootView.swift
//
//
//  Created by morse on 2023/7/11.
//

import Combine
import HamsterKit
import HamsterUIKit
import UIKit

class FinderRootView: NibLessView {
  // MARK: properties

  private let finderViewModel: FinderViewModel
  private let fileBrowserViewModelFactory: FileBrowserViewModelFactory

  private var subscriptions = Set<AnyCancellable>()

  lazy var segmentedControl: UISegmentedControl = {
    let tags: [String]
    if finderViewModel.enableAppleCloud {
      tags = ["通用", "应用文件", "键盘文件", "iCloud文件"]
    } else {
      tags = ["通用", "应用文件", "键盘文件"]
    }
    let segmentedControl = UISegmentedControl(items: tags)
    segmentedControl.selectedSegmentIndex = 0
    segmentedControl.addTarget(
      finderViewModel,
      action: #selector(finderViewModel.segmentChangeAction(sender:)),
      for: .valueChanged)
    return segmentedControl
  }()

  lazy var contentView: UIView = {
    let view = UIView(frame: .zero)
    return view
  }()

  lazy var settingTableView: FinderSettingsView = {
    let view = FinderSettingsView(finderViewModel: finderViewModel)
    return view
  }()

  lazy var appDocumentFileBrowseView: FileBrowserView = {
    let fileBrowserViewModel = fileBrowserViewModelFactory.makeFileBrowserViewModel(rootURL: FileManager.sandboxDirectory)
    return FileBrowserView(finderViewModel: finderViewModel, fileBrowserViewModel: fileBrowserViewModel)
  }()

  lazy var appGroupDocumentFileBrowseView: FileBrowserView? = {
    guard let shareURL = try? FileManager.shareURL else { return nil }
    let fileBrowserViewModel = fileBrowserViewModelFactory.makeFileBrowserViewModel(rootURL: shareURL)
    return FileBrowserView(finderViewModel: finderViewModel, fileBrowserViewModel: fileBrowserViewModel)
  }()

  lazy var iCloudDocumentFileBrowseView: FileBrowserView? = {
    if let iCloudURL = URL.iCloudDocumentURL {
      let fileBrowserViewModel = fileBrowserViewModelFactory.makeFileBrowserViewModel(rootURL: iCloudURL)
      return FileBrowserView(finderViewModel: finderViewModel, fileBrowserViewModel: fileBrowserViewModel)
    }
    return nil
  }()

  // MARK: methods

  init(frame: CGRect = .zero, finderViewModel: FinderViewModel, fileBrowserViewModelFactory: FileBrowserViewModelFactory) {
    self.finderViewModel = finderViewModel
    self.fileBrowserViewModelFactory = fileBrowserViewModelFactory

    super.init(frame: frame)

    backgroundColor = UIColor.systemBackground

    setupView()
  }

  func setupView() {
    constructViewHierarchy()
    activateViewConstraints()

    finderViewModel.segmentActionPublished
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] in
        switchView($0)
      }
      .store(in: &subscriptions)
  }

  override func constructViewHierarchy() {
    addSubview(segmentedControl)
    addSubview(contentView)
  }

  override func activateViewConstraints() {
    segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      segmentedControl.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
      segmentedControl.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
      segmentedControl.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),

      contentView.topAnchor.constraint(equalToSystemSpacingBelow: segmentedControl.bottomAnchor, multiplier: 1.0),
      contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
      contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }
}

extension FinderRootView {
  func switchView(_ action: FinderSegmentAction) {
    switch action {
    case .settings:
      switchSettingView()
    case .appFiles:
      switchAppFileBrowser()
    case .appGroupFiles:
      switchAppGroupFileBrowser()
    case .iCloudFiles:
      switchAppleCloudBrowser()
    }
  }

  func switchSettingView() {
    changeContentSubView(view: settingTableView)
  }

  func switchAppFileBrowser() {
    changeContentSubView(view: appDocumentFileBrowseView)
  }

  func switchAppGroupFileBrowser() {
    guard let view = appGroupDocumentFileBrowseView else {
      let stackView = UIStackView(frame: .zero)
      stackView.axis = .vertical
      stackView.alignment = .center
      stackView.distribution = .fill

      let warningLabel = UILabel(frame: .zero)
      warningLabel.text = "App Group 共享容器不可用，请检查 App 和键盘扩展的签名权限后重新安装。"
      warningLabel.font = UIFont.preferredFont(forTextStyle: .body)
      warningLabel.numberOfLines = 0
      stackView.addArrangedSubview(warningLabel)
      changeContentSubView(view: stackView)
      return
    }
    changeContentSubView(view: view)
  }

  func switchAppleCloudBrowser() {
    if let view = iCloudDocumentFileBrowseView {
      changeContentSubView(view: view)
    } else {
      let stackView = UIStackView(frame: .zero)
      stackView.axis = .vertical
      stackView.alignment = .center
      stackView.distribution = .fill

      let warringLabel = UILabel(frame: .zero)
      warringLabel.text = "iCloud异常"
      warringLabel.font = UIFont.preferredFont(forTextStyle: .body)
      stackView.addSubview(warringLabel)
      changeContentSubView(view: stackView)
    }
  }

  private func changeContentSubView(view: UIView) {
    contentView.subviews.forEach { $0.removeFromSuperview() }
    view.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(view)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: contentView.topAnchor),
      view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
      view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
    ])
  }
}
