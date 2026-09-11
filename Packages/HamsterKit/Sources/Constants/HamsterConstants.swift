//
//  HamsterConstants.swift
//
//
//  Created by morse on 2023/7/3.
//

import Foundation

/// Hamster 应用常量
public enum HamsterConstants {
  /// App Group ID used by the signed-in Xcode build.
  public static let defaultAppGroupName = "group.dev.fuxiao.app.Hamster"

  /// SideStore writes the App Groups from the active provisioning profile to
  /// this key while preparing an app for re-signing.
  private static let sideStoreAppGroupsInfoPlistKey = "ALTAppGroups"

  /// App Group ID authorized by the current app signature.
  ///
  /// SideStore may append the free team's identifier to the group's name when
  /// it creates a provisioning profile. Reading its Info.plist metadata keeps
  /// the app and keyboard extension on the same authorized group after that
  /// rewrite, while the checked-in group remains the fallback for Xcode builds.
  public static var appGroupName: String {
    appGroupName(from: Bundle.main.infoDictionary)
  }

  static func appGroupName(from infoDictionary: [String: Any]?) -> String {
    let appGroups = infoDictionary?[sideStoreAppGroupsInfoPlistKey] as? [String] ?? []
    let originalGroupPrefix = defaultAppGroupName + "."

    if let matchingGroup = appGroups.first(where: {
      $0 == defaultAppGroupName || $0.hasPrefix(originalGroupPrefix)
    }) {
      return matchingGroup
    }

    return appGroups.first(where: { $0.hasPrefix("group.") }) ?? defaultAppGroupName
  }

  /// iCloud ID
  public static let iCloudID = "iCloud.dev.fuxiao.app.hamsterapp"

  /// keyboard Bundle ID
  public static let keyboardBundleID = "dev.fuxiao.app.Hamster.HamsterKeyboard"

  /// 跳转至系统添加键盘URL
  public static let addKeyboardPath = "app-settings:root=General&path=Keyboard/KEYBOARDS"

  // MARK: 与Squirrel.app保持一致

  /// RIME 预先构建的数据目录中
  public static let rimeSharedSupportPathName = "SharedSupport"

  /// RIME UserData目录
  public static let rimeUserPathName = "Rime"

  /// RIME 内置输入方案及配置zip包
  public static let inputSchemaZipFile = "SharedSupport.zip"

  /// 仓内置方案 zip 包
  public static let userDataZipFile = "rime-ice.zip"

  /// APP URL
  /// 注意: 此值需要与info.plist中的参数保持一致
  public static let appURL = "hamster://dev.fuxiao.app.hamster"
}
