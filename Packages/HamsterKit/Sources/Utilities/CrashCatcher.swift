//
//  CrashCatcher.swift
//  HamsterKit
//
//  崩溃捕获:
//  - NSException 未捕获异常: 记录名称/原因/完整调用栈
//  - 常见崩溃信号(SIGABRT/SIGILL/SIGSEGV/SIGBUS/SIGFPE/SIGTRAP/SIGSYS):
//    记录信号/时间/进程号(信号处理上下文只做 POSIX 写入, 不保证符号化)
//  - 可选镜像 stderr 到日志文件: Swift 运行时 fatal error 等消息会打到
//    stderr, 在崩溃信号之前被镜像进会话日志, 便于定位崩溃原因
//  崩溃报告写入 AppLog.logDirectoryURL 下的 crash-*.log。
//

import Darwin
import Foundation

public final class CrashCatcher {
  /// 是否已安装
  public private(set) static var isInstalled = false

  private static let installLock = NSLock()
  private static var role = "unknown"
  private static var roleBytes = Array("unknown".utf8)
  private static var crashDirectoryPath = ""
  private static var didReportUncaughtException = false

  // 预分配(install 时完成)的信号处理缓冲区, 避免在信号处理上下文中分配内存
  private static let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)

  // Darwin.open 为可变参数 C 函数, Swift 无法直接调用;
  // install 时通过 dlsym 解析三参数版本供信号处理器使用
  private typealias OpenFunction = @convention(c) (UnsafePointer<CChar>, Int32, mode_t) -> Int32
  private static let openWithMode: OpenFunction? = {
    guard let handle = dlopen(nil, RTLD_LAZY),
          let symbol = dlsym(handle, "open")
    else { return nil }
    return unsafeBitCast(symbol, to: OpenFunction.self)
  }()

  private static let signals: [(Int32, String)] = [
    (SIGABRT, "SIGABRT"),
    (SIGBUS, "SIGBUS"),
    (SIGFPE, "SIGFPE"),
    (SIGILL, "SIGILL"),
    (SIGSEGV, "SIGSEGV"),
    (SIGSYS, "SIGSYS"),
    (SIGTRAP, "SIGTRAP"),
  ]

  private init() {}

  /// 安装崩溃捕获并启动文件日志。
  /// - Parameters:
  ///   - role: 日志/崩溃文件名前缀; 默认取当前 Bundle 标识最后一段
  ///   - mirrorConsoleToFile: 是否把本进程 stderr 镜像到会话日志文件
  public static func setup(role: String? = nil, mirrorConsoleToFile: Bool = false) {
    installLock.lock()
    defer { installLock.unlock() }
    if isInstalled { return }

    let resolvedRole = role ?? Self.defaultRole()
    Self.role = resolvedRole
    Self.roleBytes = Array(resolvedRole.utf8)

    // 先启动会话日志(崩溃目录与日志目录相同)
    _ = AppLog.shared.start(role: resolvedRole)

    // 预热 crash 目录路径与 open 函数指针(避免在信号处理上下文中触发懒初始化)
    Self.crashDirectoryPath = AppLog.logDirectoryURL.path
    _ = Self.openWithMode

    installUncaughtExceptionHandler()
    installSignalHandlers()
    if mirrorConsoleToFile {
      ConsoleMirror.start()
    }

    isInstalled = true
    AppLog.shared.info("CrashCatcher installed, role=\(resolvedRole)")
  }

  /// 默认角色: 取当前进程 Bundle id 的最后一段
  private static func defaultRole() -> String {
    guard let identifier = Bundle.main.bundleIdentifier,
          let last = identifier.split(separator: ".").last
    else { return "unknown" }
    return String(last)
  }

  // MARK: - NSException

  private static func installUncaughtExceptionHandler() {
    let handler: @convention(c) (NSException) -> Void = { exception in
      CrashCatcher.handleUncaughtException(exception)
    }
    NSSetUncaughtExceptionHandler(handler)
  }

  private static func handleUncaughtException(_ exception: NSException) {
    var report = "===== CRASH: uncaught NSException =====\n"
    report += "name: \(exception.name.rawValue)\n"
    report += "reason: \(exception.reason ?? "")\n"
    report += "callStackSymbols:\n"
    report += exception.callStackSymbols.joined(separator: "\n")
    report += "\n"
    writeFoundationReport(report)

    // 阻止 signal 处理器再写一份重复报告(异常处理上下文不访问 AppLog 锁,
    // 避免在异常线程恰好持有日志锁时死锁)
    didReportUncaughtException = true
  }

  // MARK: - 信号

  private static func installSignalHandlers() {
    for (signalValue, _) in signals {
      let handler: @convention(c) (Int32) -> Void = { signalValue in
        CrashCatcher.handleSignal(signalValue)
      }
      Darwin.signal(signalValue, handler)
    }
  }

  private static func handleSignal(_ signalValue: Int32) {
    if !didReportUncaughtException {
      writeSignalReport(signalValue)
    }
    // 恢复默认行为并重新触发, 让系统生成标准的崩溃记录
    Darwin.signal(signalValue, SIG_DFL)
    Darwin.raise(signalValue)
  }

  // MARK: - 报告写入

  /// Foundation 上下文(异常处理器)可用的报告写入
  private static func writeFoundationReport(_ text: String) {
    let directory = AppLog.logDirectoryURL
    try? FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    let fileName = "crash-\(role)-\(Int(Date().timeIntervalSince1970))-\(ProcessInfo.processInfo.processIdentifier).log"
    let fileURL = directory.appendingPathComponent(fileName)
    guard let data = text.data(using: .utf8) else { return }
    try? data.write(to: fileURL)
  }

  /// 信号处理上下文专用的 POSIX 写入(无锁、无内存分配)
  private static func writeSignalReport(_ signalValue: Int32) {
    let directoryPath = crashDirectoryPath
    guard !directoryPath.isEmpty else { return }

    let buffer = scratch
    var offset = 0

    let currentTime = Int(time(nil))
    let processID = Int(getpid())

    copyASCII(directoryPath, into: buffer, offset: &offset)
    copyASCII("/crash-", into: buffer, offset: &offset)
    for byte in roleBytes { buffer[offset] = byte; offset += 1 }
    copyASCII("-", into: buffer, offset: &offset)
    copyDecimal(currentTime, into: buffer, offset: &offset)
    copyASCII("-", into: buffer, offset: &offset)
    copyDecimal(processID, into: buffer, offset: &offset)
    copyASCII(".log", into: buffer, offset: &offset)

    let pathEnd = offset
    buffer[pathEnd] = 0 // NUL 结尾

    var contentOffset = pathEnd + 1
    copyASCII("===== CRASH: uncaught signal =====\n", into: buffer, offset: &contentOffset)
    copyASCII("time(sec): ", into: buffer, offset: &contentOffset)
    copyDecimal(currentTime, into: buffer, offset: &contentOffset)
    copyASCII("\npid: ", into: buffer, offset: &contentOffset)
    copyDecimal(processID, into: buffer, offset: &contentOffset)
    copyASCII("\nsignal: ", into: buffer, offset: &contentOffset)
    for byte in signalName(signalValue).utf8 { buffer[contentOffset] = byte; contentOffset += 1 }
    copyASCII(" (", into: buffer, offset: &contentOffset)
    copyDecimal(Int(signalValue), into: buffer, offset: &contentOffset)
    copyASCII(")\nrole: ", into: buffer, offset: &contentOffset)
    for byte in roleBytes { buffer[contentOffset] = byte; contentOffset += 1 }
    copyASCII("\n崩溃前运行日志见同级 *-*.log; 完整调用栈请用 Xcode/Console 复现查看\n", into: buffer, offset: &contentOffset)

    guard let openFile = openWithMode else { return }
    let fd = openFile(buffer, O_WRONLY | O_CREAT | O_APPEND, 0o644)
    guard fd >= 0 else { return }
    _ = Darwin.write(fd, buffer.advanced(by: pathEnd + 1), contentOffset - pathEnd - 1)
    Darwin.close(fd)
  }

  private static func signalName(_ signalValue: Int32) -> String {
    for (value, name) in signals where value == signalValue {
      return name
    }
    return "SIGNAL(\(signalValue))"
  }

  private static func copyASCII(_ string: String, into buffer: UnsafeMutablePointer<UInt8>, offset: inout Int) {
    for byte in string.utf8 {
      buffer[offset] = byte
      offset += 1
    }
  }

  private static func copyDecimal(_ value: Int, into buffer: UnsafeMutablePointer<UInt8>, offset: inout Int) {
    var remaining = UInt(abs(value))
    var divisor: UInt = 1
    while divisor * 10 <= remaining {
      divisor *= 10
    }
    if value < 0 {
      buffer[offset] = 0x2D // '-'
      offset += 1
    }
    while divisor > 0 {
      let digit = remaining / divisor
      buffer[offset] = UInt8(0x30 + digit)
      offset += 1
      remaining %= divisor
      divisor /= 10
    }
  }
}

/// 把本进程 stderr 输出(如 Swift fatal error 前的崩溃信息)镜像到会话日志
private final class ConsoleMirror {
  private static let startedLock = NSLock()
  private static var isStarted = false

  static func start() {
    startedLock.lock()
    defer { startedLock.unlock() }
    guard !isStarted else { return }
    isStarted = true

    let pipe = Pipe()
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)
    let readHandle = pipe.fileHandleForReading
    readHandle.readabilityHandler = { handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      guard let text = String(data: data, encoding: .utf8) else { return }
      for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
        AppLog.shared.debug("[console] \(line)")
      }
    }
  }
}
