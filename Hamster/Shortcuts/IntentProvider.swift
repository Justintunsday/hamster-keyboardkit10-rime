//
//  IntentProvider.swift
//  Hamster
//
//  Created by morse on 2023/9/25.
//

import AppIntents

@available(iOS 16.0, *)
struct IntentProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    return [
      AppShortcut(intent: RimeSyncIntent(), phrases: ["RIME Sync using ${applicationName}", "使用${applicationName}同步RIME"]),
      AppShortcut(intent: RimeDeployIntent(), phrases: ["RIME Deploy using ${applicationName}", "使用${applicationName}重新部署RIME"]),
    ]
  }
}
