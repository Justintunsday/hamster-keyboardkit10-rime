//
//  HamsterDiagnostics.swift
//  HamsterKit
//
//  Small, privacy-preserving diagnostics shared by the host app and keyboard
//  extensions. Each bundle writes its own atomic file in the App Group so
//  separate processes cannot overwrite one another's event stream.
//

import Foundation
import OSLog

/// The process that produced a diagnostic event.
public enum HamsterDiagnosticProcess: String, Codable, Sendable {
  case host
  case keyboard
}

/// A deliberately small severity set for the in-app diagnostics view.
public enum HamsterDiagnosticSeverity: String, Codable, Sendable {
  case info
  case warning
  case error
}

/// One diagnostic event. This type contains only lifecycle and system
/// metadata; callers must never pass user input, composition, or candidates.
public struct HamsterDiagnosticEvent: Codable, Identifiable, Hashable, Sendable {
  public let id: UUID
  public let timestamp: Date
  public let process: HamsterDiagnosticProcess
  public let target: String
  public let severity: HamsterDiagnosticSeverity
  public let category: String
  public let message: String
  public let appVersion: String
  public let appBuild: String
  public let systemVersion: String
  public let processID: Int32

  public init(
    id: UUID = UUID(),
    timestamp: Date = Date(),
    process: HamsterDiagnosticProcess,
    target: String,
    severity: HamsterDiagnosticSeverity,
    category: String,
    message: String,
    appVersion: String,
    appBuild: String,
    systemVersion: String,
    processID: Int32
  ) {
    self.id = id
    self.timestamp = timestamp
    self.process = process
    self.target = target
    self.severity = severity
    self.category = category
    self.message = message
    self.appVersion = appVersion
    self.appBuild = appBuild
    self.systemVersion = systemVersion
    self.processID = processID
  }
}

/// Shared diagnostics store.
///
/// `record` and session methods enqueue work on a utility queue. This is
/// important for an input method: a missing App Group, a full disk, or a slow
/// file system must not delay KeyboardKit or Rime startup. The synchronous
/// snapshot/clear methods are intended for the host app's diagnostics screen.
public enum HamsterDiagnostics {
  /// Per-bundle ring-buffer limits.
  public static let maximumEventCount = 200
  public static let maximumStorageBytes = 64 * 1024

  /// A guard for old or unexpected target files in the shared directory.
  public static let maximumTotalStorageBytes = 256 * 1024
  public static let maximumDisplayedEventCount = 500
  public static let diagnosticsDirectoryRelativePath = "Diagnostics/"

  private static let eventsFilePrefix = "events-"
  private static let legacyEventsFileName = "events.json"
  private static let markerFilePrefix = "active-"
  private static let legacyMarkerNames = ["active-host.marker", "active-keyboard.marker"]

  private static let queue = DispatchQueue(
    label: "dev.fuxiao.app.Hamster.diagnostics",
    qos: .utility
  )
  private static let logger = Logger(
    subsystem: "dev.fuxiao.app.Hamster",
    category: "diagnostics"
  )

  private static var diagnosticsDirectoryURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: HamsterConstants.appGroupName)?
      .appendingPathComponent("Diagnostics", isDirectory: true)
  }

  private static var targetFileIdentifier: String {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "unknown"
    return sanitizedFileIdentifier(bundleIdentifier)
  }

  private static var targetEventsURL: URL? {
    diagnosticsDirectoryURL?.appendingPathComponent(
      "\(eventsFilePrefix)\(targetFileIdentifier).json",
      isDirectory: false
    )
  }

  /// Enqueue one fixed-text breadcrumb. The StaticString parameters make it
  /// difficult to accidentally put typed text or document content in logs.
  public static func record(
    process: HamsterDiagnosticProcess,
    severity: HamsterDiagnosticSeverity = .info,
    category: StaticString,
    message: StaticString
  ) {
    let event = makeEvent(
      process: process,
      severity: severity,
      category: category,
      message: message
    )

    logToConsole(event)
    queue.async {
      append(event)
    }
  }

  /// Mark a process as active and report if its previous marker was left
  /// behind. Marker writes are regular asynchronous Foundation writes; no
  /// signal or exception handler is installed.
  public static func beginSession(process: HamsterDiagnosticProcess) {
    queue.async {
      guard let directory = diagnosticsDirectoryURL else { return }
      let marker = markerURL(in: directory)
      let hadPreviousMarker = FileManager.default.fileExists(atPath: marker.path)

      if hadPreviousMarker {
        append(makeEvent(
          process: process,
          severity: .warning,
          category: "lifecycle",
          message: "Previous session ended without a clean termination marker"
        ))
      }

      do {
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
        try Data("active".utf8).write(to: marker, options: .atomic)
      } catch {
        // Diagnostics must never affect the keyboard or host startup.
      }

      append(makeEvent(
        process: process,
        severity: .info,
        category: "lifecycle",
        message: "Session started"
      ))
    }
  }

  /// Clear the best-effort active-session marker. iOS may terminate a process
  /// without calling this method, which is precisely what the next session
  /// marker check can report.
  public static func endSession(process: HamsterDiagnosticProcess) {
    queue.async {
      guard let directory = diagnosticsDirectoryURL else { return }
      try? FileManager.default.removeItem(at: markerURL(in: directory))
      append(makeEvent(
        process: process,
        severity: .info,
        category: "lifecycle",
        message: "Session ended cleanly"
      ))
    }
  }

  /// Read all recognized per-target files, tolerating a corrupt individual
  /// file and returning the newest bounded set in timestamp order.
  public static func snapshot() -> [HamsterDiagnosticEvent] {
    queue.sync {
      mergedEvents()
    }
  }

  /// Remove only recognized diagnostics event and marker files.
  public static func clear() {
    queue.sync {
      guard let directory = diagnosticsDirectoryURL else { return }
      for url in recognizedEventURLs(in: directory) + recognizedMarkerURLs(in: directory) {
        try? FileManager.default.removeItem(at: url)
      }
    }
  }

  /// A plain-text export suitable for the system share sheet. It includes the
  /// same bounded metadata as the UI and never includes input text.
  public static func exportText() -> String {
    queue.sync {
      let events = mergedEvents()
      guard !events.isEmpty else { return "暂无诊断日志" }
      let formatter = ISO8601DateFormatter()
      return events.map { event in
        "[\(formatter.string(from: event.timestamp))] [\(event.process.rawValue)] [\(event.severity.rawValue.uppercased())] [\(event.category)] \(event.message) | target=\(event.target) app=\(event.appVersion)(\(event.appBuild)) system=\(event.systemVersion) pid=\(event.processID)"
      }.joined(separator: "\n")
    }
  }
}

private extension HamsterDiagnostics {
  static func makeEvent(
    process: HamsterDiagnosticProcess,
    severity: HamsterDiagnosticSeverity,
    category: StaticString,
    message: StaticString
  ) -> HamsterDiagnosticEvent {
    HamsterDiagnosticEvent(
      process: process,
      target: Bundle.main.bundleIdentifier ?? "unknown",
      severity: severity,
      category: bounded(String(describing: category), limit: 64),
      message: bounded(String(describing: message), limit: 240),
      appVersion: bounded(appVersion, limit: 64),
      appBuild: bounded(appBuild, limit: 64),
      systemVersion: bounded(ProcessInfo.processInfo.operatingSystemVersionString, limit: 96),
      processID: ProcessInfo.processInfo.processIdentifier
    )
  }

  static var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
  }

  static var appBuild: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
  }

  static func sanitizedFileIdentifier(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(min(value.count, 120))
    for scalar in value.unicodeScalars {
      let isASCIIAlpha = (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122)
      let isDigit = scalar.value >= 48 && scalar.value <= 57
      if isASCIIAlpha || isDigit || scalar.value == 45 || scalar.value == 95 {
        result.unicodeScalars.append(scalar)
      } else {
        result.append("_")
      }
      if result.count >= 120 { break }
    }
    return result.isEmpty ? "unknown" : result
  }

  static func markerURL(in directory: URL) -> URL {
    directory.appendingPathComponent(
      "\(markerFilePrefix)\(targetFileIdentifier).marker",
      isDirectory: false
    )
  }

  static func recognizedEventURLs(in directory: URL) -> [URL] {
    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return urls.filter { url in
      let name = url.lastPathComponent
      guard (name == legacyEventsFileName || (name.hasPrefix(eventsFilePrefix) && url.pathExtension == "json")) else {
        return false
      }
      let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
      return values?.isRegularFile == true
    }
  }

  static func recognizedMarkerURLs(in directory: URL) -> [URL] {
    guard let urls = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    return urls.filter { url in
      let name = url.lastPathComponent
      guard ((name.hasPrefix(markerFilePrefix) && url.pathExtension == "marker") || legacyMarkerNames.contains(name)) else {
        return false
      }
      let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
      return values?.isRegularFile == true
    }
  }

  static func mergedEvents() -> [HamsterDiagnosticEvent] {
    guard let directory = diagnosticsDirectoryURL else { return [] }
    var events = recognizedEventURLs(in: directory).flatMap { loadEvents(from: $0) }
    events.sort {
      if $0.timestamp == $1.timestamp {
        return $0.id.uuidString < $1.id.uuidString
      }
      return $0.timestamp < $1.timestamp
    }
    if events.count > maximumDisplayedEventCount {
      events = Array(events.suffix(maximumDisplayedEventCount))
    }
    return events
  }

  static func append(_ event: HamsterDiagnosticEvent) {
    guard let eventsURL = targetEventsURL else { return }
    do {
      let directory = eventsURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var events = loadEvents(from: eventsURL)
      events.append(event)
      let data = try encode(trim(events))
      // Each bundle owns this file. Atomic replacement prevents readers from
      // observing a partial JSON document while another process is writing.
      try data.write(to: eventsURL, options: .atomic)
      pruneStorage(in: directory)
    } catch {
      // A diagnostics failure must never become an application failure.
    }
  }

  static func loadEvents(from url: URL) -> [HamsterDiagnosticEvent] {
    guard let data = try? Data(contentsOf: url),
          let events = try? decode(data)
    else { return [] }
    return trim(events)
  }

  static func trim(_ events: [HamsterDiagnosticEvent]) -> [HamsterDiagnosticEvent] {
    var result = events
    while result.count > maximumEventCount || ((try? encode(result).count) ?? 0) > maximumStorageBytes {
      guard !result.isEmpty else { break }
      result.removeFirst()
    }
    return result
  }

  static func pruneStorage(in directory: URL) {
    let urls = recognizedEventURLs(in: directory)
    var sizes = urls.map { url -> (url: URL, size: Int64, date: Date) in
      let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
      return (url, Int64(values?.fileSize ?? 0), values?.contentModificationDate ?? .distantPast)
    }
    var total = sizes.reduce(Int64(0)) { $0 + $1.size }
    guard total > Int64(maximumTotalStorageBytes) else { return }

    sizes.sort { $0.date < $1.date }
    let currentURL = targetEventsURL
    for item in sizes where total > Int64(maximumTotalStorageBytes) {
      // Keep the file just written if possible; per-target trimming already
      // guarantees that it cannot exceed the total cap by itself.
      if item.url == currentURL && sizes.count > 1 { continue }
      try? FileManager.default.removeItem(at: item.url)
      total -= item.size
    }
  }

  static func encode(_ events: [HamsterDiagnosticEvent]) throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(events)
  }

  static func decode(_ data: Data) throws -> [HamsterDiagnosticEvent] {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode([HamsterDiagnosticEvent].self, from: data)
  }

  static func bounded(_ value: String, limit: Int) -> String {
    guard value.count > limit else { return value }
    return String(value.prefix(limit))
  }

  static func logToConsole(_ event: HamsterDiagnosticEvent) {
    switch event.severity {
    case .info:
      logger.info("[\(event.process.rawValue, privacy: .public)] [\(event.category, privacy: .public)] \(event.message, privacy: .public)")
    case .warning:
      logger.warning("[\(event.process.rawValue, privacy: .public)] [\(event.category, privacy: .public)] \(event.message, privacy: .public)")
    case .error:
      logger.error("[\(event.process.rawValue, privacy: .public)] [\(event.category, privacy: .public)] \(event.message, privacy: .public)")
    }
  }
}