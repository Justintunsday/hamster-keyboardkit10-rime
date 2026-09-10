//
//  AppDelegete.swift
//  Hamster
//
//  Created by morse on 2023/6/5.
//

import HamsterKit
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    HamsterDiagnostics.beginSession(process: .host)
    HamsterDiagnostics.record(
      process: .host,
      category: "lifecycle",
      message: "Host application did finish launching"
    )
    return true
  }

  func applicationWillTerminate(_ application: UIApplication) {
    HamsterDiagnostics.endSession(process: .host)
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    // Called when the user discards a scene session.
  }
}
