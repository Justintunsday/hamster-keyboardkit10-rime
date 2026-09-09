//
//  HamsterDiagnostics.swift
//  HamsterKeyboardKit
//
//  键盘扩展诊断入口: 安装文件日志与崩溃捕获。
//  日志/崩溃报告写入 AppGroup 共享目录, 可在 App 的"文件 - 键盘文件"
//  中浏览与导出。
//

import HamsterKit

public enum HamsterDiagnostics {
  /// 安装崩溃捕获并启动文件日志(进程内幂等)。
  /// role 默认取当前扩展 Bundle id 最后一段(HamsterKeyboard/SbxlmKeyboard…)
  public static func install(mirrorConsoleToFile: Bool = true) {
    CrashCatcher.setup(mirrorConsoleToFile: mirrorConsoleToFile)
  }

  public static var log: AppLog { AppLog.shared }

  public static func debug(_ message: @autoclosure () -> String) {
    log.debug(message())
  }

  public static func info(_ message: @autoclosure () -> String) {
    log.info(message())
  }

  public static func warning(_ message: @autoclosure () -> String) {
    log.warning(message())
  }

  public static func error(_ message: @autoclosure () -> String) {
    log.error(message())
  }
}
