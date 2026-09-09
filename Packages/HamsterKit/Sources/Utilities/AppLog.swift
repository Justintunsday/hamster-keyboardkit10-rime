//
//  AppLog.swift
//  HamsterKit
//
//  文件型日志: 主 App 与键盘扩展(HamsterKeyboard / SbxlmKeyboard)
//  写入同一个 AppGroup 共享目录 <AppGroup>/InputSchema/Logs,
//  因此键盘进程崩溃前后的日志也能在 App 的"文件 - 键盘文件"中直接查看。
//

import Foundation

public final class AppLog {
  public static let shared = AppLog()

  /// 日志目录(AppGroup 共享目录; 拿不到 AppGroup 时回退到沙盒 Document)
  public static var logDirectoryURL: URL {
    let groupDirectory = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)
    if let groupDirectory {
      return groupDirectory
        .appendingPathComponent("InputSchema", isDirectory: true)
        .appendingPathComponent("Logs", isDirectory: true)
    }
    return FileManager.sandboxDirectory
      .appendingPathComponent("Logs", isDirectory: true)
  }

  /// 单文件超过该大小后自动轮换
  public static let maximumFileSize = 1024 * 1024

  /// 当前进程正在写入的日志文件
  public private(set) var currentFileURL: URL?

  private let lock = NSLock()
  private var role = "unknown"
  private var fileHandle: FileHandle?
  private var fileSize = 0

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
  }()

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm:ss.SSS"
    return formatter
  }()

  private init() {}

  /// 启动日志会话, 每个进程调用一次即可(重复调用会重新开文件)
  @discardableResult
  public func start(role: String, maximumFileCount: Int = 30) -> URL? {
    lock.lock()
    let directory = Self.logDirectoryURL
    var newURL: URL?
    do {
      try FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
      newURL = Self.nextFileURL(in: directory, role: role)
      if let newURL {
        Self.prune(directory: directory, maximumFileCount: maximumFileCount)
      }
    } catch {
      // 目录创建失败时不阻塞业务逻辑
    }
    if let newURL {
      fileHandle = try? FileHandle(forWritingTo: newURL)
      fileSize = (try? FileManager.default.attributesOfItem(atPath: newURL.path)[.size] as? Int) ?? 0
    }
    self.role = role
    currentFileURL = newURL
    lock.unlock()

    if newURL != nil {
      info("日志会话开始 role=\(role) pid=\(ProcessInfo.processInfo.processIdentifier)")
    }
    return newURL
  }

  public func debug(_ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
    write(level: "DEBUG", message: message(), file: file, function: function, line: line)
  }

  public func info(_ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
    write(level: "INFO", message: message(), file: file, function: function, line: line)
  }

  public func warning(_ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
    write(level: "WARN", message: message(), file: file, function: function, line: line)
  }

  public func error(_ message: @autoclosure () -> String, file: String = #fileID, function: String = #function, line: Int = #line) {
    write(level: "ERROR", message: message(), file: file, function: function, line: line)
  }

  private func write(level: String, message: String, file: String, function: String, line: Int) {
    lock.lock()
    defer { lock.unlock() }
    guard let handle = fileHandle else { return }

    if fileSize >= Self.maximumFileSize, let url = currentFileURL {
      try? handle.close()
      let nextURL = Self.rotatedFileURL(after: url)
      fileHandle = try? FileHandle(forWritingTo: nextURL)
      fileSize = 0
      currentFileURL = nextURL
    }
    guard let fileHandle else { return }

    let time = Self.timeFormatter.string(from: Date())
    let text = "[\(time)][\(level)][\(role)] \(message)  (\(file):\(line) \(function))\n"
    guard let data = text.data(using: .utf8) else { return }
    do {
      try fileHandle.seekToEnd()
      try fileHandle.write(contentsOf: data)
      fileSize += data.count
    } catch {
      // 写入失败(磁盘/权限等)时忽略, 避免影响输入法主流程
    }
  }

  // MARK: 文件管理

  private static func nextFileURL(in directory: URL, role: String) -> URL? {
    let name = "\(role)-\(dateFormatter.string(from: Date()))"
    var candidate = directory.appendingPathComponent("\(name).log")
    var index = 0
    while FileManager.default.fileExists(atPath: candidate.path) {
      index += 1
      candidate = directory.appendingPathComponent("\(name)-\(index).log")
    }
    FileManager.default.createFile(atPath: candidate.path, contents: nil)
    return candidate
  }

  private static func rotatedFileURL(after url: URL) -> URL {
    let directory = url.deletingLastPathComponent()
    var index = 0
    var candidate: URL
    repeat {
      index += 1
      candidate = directory
        .appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)-\(index)")
        .appendingPathExtension("log")
    } while FileManager.default.fileExists(atPath: candidate.path)
    FileManager.default.createFile(atPath: candidate.path, contents: nil)
    return candidate
  }

  /// 删除最旧的日志文件, 仅保留最新 maximumFileCount 个
  private static func prune(directory: URL, maximumFileCount: Int) {
    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.creationDateKey],
      options: [.skipsHiddenFiles]
    ) else { return }
    let logs = urls.filter { $0.pathExtension == "log" }
      .sorted { ($0.lastPathComponent) < ($1.lastPathComponent) }
    guard logs.count > maximumFileCount else { return }
    for url in logs.prefix(logs.count - maximumFileCount) {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
