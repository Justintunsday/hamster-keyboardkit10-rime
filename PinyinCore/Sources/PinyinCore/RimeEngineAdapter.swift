import Foundation
import RimeKitBridge

public enum RimeEngineStatus: String, Equatable, Sendable {
    case unavailable
    case configured
}

public enum RimeEngineError: Error, Equatable, Sendable {
    case notConfigured
    case notStarted
    case resourcesUnavailable
    case native(String)
}

extension RimeEngineError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "RIME session driver is not configured"
        case .notStarted:
            return "RIME session is not started"
        case .resourcesUnavailable:
            return "RIME resources are unavailable"
        case .native(let message):
            return message
        }
    }
}

public enum RimeSessionStatus: Equatable, Sendable {
    case idle
    case ready
    case failed(String)
}

/// Build-time and runtime boundary for the native RIME implementation.
///
/// The bridge is a small Objective-C wrapper written for this project. It
/// exposes no GuruIM business modules, AI path, clipboard path, or cloud path.
public enum RimeKitIntegrationBoundary {
    public static let rimeKitModuleIsVisible = true
    public static let librimeModuleIsVisible = true
    public static let cAPILifecycleIsImplemented = true
}

public struct RimeSessionConfiguration: Equatable, Sendable {
    public let schemaID: String
    public let resourceDirectory: String
    public let userDataDirectory: String
    public let pageSize: Int

    public init(
        schemaID: String = "rime_ice",
        resourceDirectory: String = "RimeShared",
        userDataDirectory: String = "RimeUser",
        pageSize: Int = 5
    ) {
        self.schemaID = schemaID
        self.resourceDirectory = resourceDirectory
        self.userDataDirectory = userDataDirectory
        self.pageSize = max(1, pageSize)
    }
}

public enum RimeKey: Equatable, Sendable {
    case text(String)
    case backspace
    case space
    case enter
    case candidate(Int)
    case reset
}

public struct RimeCandidate: Identifiable, Hashable, Codable, Sendable {
    public let index: Int
    public let text: String
    public let pinyin: String
    public let comment: String?
    public let frequency: Int
    public let score: Int

    public var id: String {
        "\(index)|\(text)|\(pinyin)"
    }

    public init(
        index: Int,
        text: String,
        pinyin: String = "",
        comment: String? = nil,
        frequency: Int = 0,
        score: Int = 0
    ) {
        self.index = index
        self.text = text
        self.pinyin = pinyin
        self.comment = comment
        self.frequency = frequency
        self.score = score
    }

    public func asPinyinCandidate(rank: Int) -> PinyinCandidate {
        PinyinCandidate(
            text: text,
            pinyin: pinyin,
            frequency: frequency,
            score: score,
            rank: rank
        )
    }
}

public struct RimeSnapshot: Equatable, Sendable {
    public let preedit: String
    public let rawInput: String
    public let candidates: [RimeCandidate]
    public let selectedCandidateIndex: Int?
    public let committedText: String?
    public let pageIndex: Int
    public let pageSize: Int
    public let hasNextPage: Bool
    public let schemaID: String?

    public var isComposing: Bool {
        !preedit.isEmpty || !rawInput.isEmpty
    }

    public var pinyinCandidates: [PinyinCandidate] {
        candidates.enumerated().map { offset, candidate in
            candidate.asPinyinCandidate(rank: offset + 1)
        }
    }

    public init(
        preedit: String = "",
        rawInput: String = "",
        candidates: [RimeCandidate] = [],
        selectedCandidateIndex: Int? = nil,
        committedText: String? = nil,
        pageIndex: Int = 0,
        pageSize: Int = 0,
        hasNextPage: Bool = false,
        schemaID: String? = nil
    ) {
        self.preedit = preedit
        self.rawInput = rawInput
        self.candidates = candidates
        self.selectedCandidateIndex = selectedCandidateIndex
        self.committedText = committedText
        self.pageIndex = max(0, pageIndex)
        self.pageSize = max(0, pageSize)
        self.hasNextPage = hasNextPage
        self.schemaID = schemaID
    }

    public static let empty = RimeSnapshot()
}

public protocol RimeSessionDriver: AnyObject {
    func start() throws -> RimeSnapshot
    func stop()
    func reset() throws -> RimeSnapshot
    func process(_ key: RimeKey) throws -> RimeSnapshot
    func deleteBackward() throws -> RimeSnapshot
    func selectCandidate(at index: Int) throws -> RimeSnapshot
}

public final class RimeSession {
    public let configuration: RimeSessionConfiguration
    public private(set) var snapshot: RimeSnapshot
    public private(set) var isStarted = false
    public private(set) var status: RimeSessionStatus = .idle
    public private(set) var lastError: RimeEngineError?

    private let driver: (any RimeSessionDriver)?

    public init(
        configuration: RimeSessionConfiguration = RimeSessionConfiguration(),
        driver: (any RimeSessionDriver)? = nil
    ) {
        self.configuration = configuration
        self.driver = driver
        self.snapshot = .empty
    }

    public init(
        configuration: RimeSessionConfiguration = RimeSessionConfiguration(),
        failure: RimeEngineError
    ) {
        self.configuration = configuration
        self.driver = nil
        self.snapshot = .empty
        self.status = .failed(failure.localizedDescription)
        self.lastError = failure
    }

    public func start() throws {
        guard let driver else {
            let error = RimeEngineError.notConfigured
            status = .failed(error.localizedDescription)
            lastError = error
            throw error
        }

        do {
            snapshot = try driver.start()
            isStarted = true
            status = .ready
            lastError = nil
        } catch {
            isStarted = false
            let rimeError = error as? RimeEngineError ?? .native(error.localizedDescription)
            status = .failed(rimeError.localizedDescription)
            lastError = rimeError
            driver.stop()
            throw rimeError
        }
    }

    public func stop() {
        driver?.stop()
        isStarted = false
        status = .idle
        snapshot = .empty
    }

    @discardableResult
    public func reset() throws -> RimeSnapshot {
        try update { driver in
            try driver.reset()
        }
    }

    @discardableResult
    public func process(_ key: RimeKey) throws -> RimeSnapshot {
        try update { driver in
            try driver.process(key)
        }
    }

    @discardableResult
    public func deleteBackward() throws -> RimeSnapshot {
        try update { driver in
            try driver.deleteBackward()
        }
    }

    @discardableResult
    public func selectCandidate(at index: Int) throws -> RimeSnapshot {
        try update { driver in
            try driver.selectCandidate(at: index)
        }
    }

    private func update(
        _ operation: (any RimeSessionDriver) throws -> RimeSnapshot
    ) throws -> RimeSnapshot {
        guard isStarted, let driver else {
            let error = driver == nil
                ? RimeEngineError.notConfigured
                : RimeEngineError.notStarted
            status = .failed(error.localizedDescription)
            lastError = error
            throw error
        }

        do {
            let nextSnapshot = try operation(driver)
            snapshot = nextSnapshot
            status = .ready
            lastError = nil
            return nextSnapshot
        } catch {
            let rimeError = error as? RimeEngineError ?? .native(error.localizedDescription)
            status = .failed(rimeError.localizedDescription)
            lastError = rimeError
            isStarted = false
            driver.stop()
            throw rimeError
        }
    }
}

public struct RimeResourcePaths: Equatable, Sendable {
    public let sharedDataPath: URL
    public let userDataPath: URL

    public init(sharedDataPath: URL, userDataPath: URL) {
        self.sharedDataPath = sharedDataPath
        self.userDataPath = userDataPath
    }
}

public enum RimeResourceError: Error, Equatable, Sendable {
    case bundleResourceMissing
    case requiredFileMissing(String)
}

extension RimeResourceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bundleResourceMissing:
            return "Bundled RIME resource directory is missing"
        case .requiredFileMissing(let file):
            return "Required RIME resource is missing: \(file)"
        }
    }
}

public enum RimeResourceInstaller {
    public static let resourceVersion = "rime-ice-2026.06.30"

    public static var hasBundledResources: Bool {
        guard let root = bundledResourceURL(bundle: .module) else {
            return false
        }
        let fileManager = FileManager.default
        return ["default.yaml", "rime_ice.schema.yaml", "rime_ice.dict.yaml"]
            .allSatisfy { fileManager.fileExists(atPath: root.appendingPathComponent($0).path) }
    }

    public static func prepare(
        bundle: Bundle? = nil,
        applicationIdentifier: String = "PinyinKeyboard"
    ) throws -> RimeResourcePaths {
        guard let source = bundledResourceURL(bundle: bundle ?? .module) else {
            throw RimeResourceError.bundleResourceMissing
        }

        let fileManager = FileManager.default
        for file in ["default.yaml", "rime_ice.schema.yaml", "rime_ice.dict.yaml"]
            where !fileManager.fileExists(atPath: source.appendingPathComponent(file).path) {
            throw RimeResourceError.requiredFileMissing(file)
        }

        let baseURL = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory)
            .appendingPathComponent(applicationIdentifier, isDirectory: true)
        let sharedURL = baseURL.appendingPathComponent("RimeShared", isDirectory: true)
        let userURL = baseURL.appendingPathComponent("RimeUser", isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: userURL, withIntermediateDirectories: true)

        let markerURL = sharedURL.appendingPathComponent(".pinyin-keyboard-resource-version")
        let userMarkerURL = userURL.appendingPathComponent(".pinyin-keyboard-resource-version")
        let installedVersion = try? String(contentsOf: markerURL, encoding: .utf8)
        if installedVersion?.trimmingCharacters(in: .whitespacesAndNewlines) != resourceVersion {
            if fileManager.fileExists(atPath: sharedURL.path) {
                try fileManager.removeItem(at: sharedURL)
            }
            try fileManager.copyItem(at: source, to: sharedURL)
            try resourceVersion.write(to: markerURL, atomically: true, encoding: .utf8)
        }

        let installedUserVersion = try? String(contentsOf: userMarkerURL, encoding: .utf8)
        if installedUserVersion?.trimmingCharacters(in: .whitespacesAndNewlines) != resourceVersion {
            let buildURL = userURL.appendingPathComponent("build", isDirectory: true)
            if fileManager.fileExists(atPath: buildURL.path) {
                try fileManager.removeItem(at: buildURL)
            }
            try resourceVersion.write(to: userMarkerURL, atomically: true, encoding: .utf8)
        }

        let customDefault = userURL.appendingPathComponent("default.custom.yaml")
        if !fileManager.fileExists(atPath: customDefault.path) {
            let contents = """
            patch:
              schema_list:
                - schema: rime_ice
              translator/enable_user_dict: true
            """
            try contents.write(to: customDefault, atomically: true, encoding: .utf8)
        }

        return RimeResourcePaths(sharedDataPath: sharedURL, userDataPath: userURL)
    }

    private static func bundledResourceURL(bundle: Bundle) -> URL? {
        if let directURL = bundle.url(forResource: "Rime", withExtension: nil) {
            return directURL
        }
        guard let resourceURL = bundle.resourceURL else {
            return nil
        }
        return resourceURL.appendingPathComponent("Rime", isDirectory: true)
    }
}

public final class RimeKitSessionDriver: RimeSessionDriver, @unchecked Sendable {
    private let nativeSession: RimeKitSession

    public init(paths: RimeResourcePaths, schemaID: String = "rime_ice") {
        self.nativeSession = RimeKitSession(
            sharedDataPath: paths.sharedDataPath.path,
            userDataPath: paths.userDataPath.path,
            schemaID: schemaID
        )
    }

    public func start() throws -> RimeSnapshot {
        do {
            try nativeSession.start()
        } catch {
            throw RimeEngineError.native(error.localizedDescription)
        }
        return snapshot(from: nativeSession.currentSnapshot())
    }

    public func stop() {
        nativeSession.stop()
    }

    public func reset() throws -> RimeSnapshot {
        try checkedSnapshot {
            nativeSession.reset()
        }
    }

    public func process(_ key: RimeKey) throws -> RimeSnapshot {
        switch key {
        case .text(let text):
            return try checkedSnapshot {
                nativeSession.processText(text)
            }
        case .backspace:
            return try checkedSnapshot {
                nativeSession.processBackspace()
            }
        case .space:
            return try checkedSnapshot {
                nativeSession.processSpace()
            }
        case .enter:
            return try checkedSnapshot {
                nativeSession.processReturn()
            }
        case .candidate(let index):
            return try checkedSnapshot {
                nativeSession.selectCandidate(at: index)
            }
        case .reset:
            return try checkedSnapshot {
                nativeSession.reset()
            }
        }
    }

    public func deleteBackward() throws -> RimeSnapshot {
        try checkedSnapshot {
            nativeSession.processBackspace()
        }
    }

    public func selectCandidate(at index: Int) throws -> RimeSnapshot {
        try checkedSnapshot {
            nativeSession.selectCandidate(at: index)
        }
    }

    private func checkedSnapshot(
        _ operation: () -> RimeKitSnapshot
    ) throws -> RimeSnapshot {
        let nativeSnapshot = operation()
        if let message = nativeSession.lastErrorMessage, !message.isEmpty {
            throw RimeEngineError.native(message)
        }
        return snapshot(from: nativeSnapshot)
    }

    private func snapshot(from native: RimeKitSnapshot) -> RimeSnapshot {
        let candidates = native.candidates.map { candidate in
            RimeCandidate(
                index: candidate.index,
                text: candidate.text,
                comment: candidate.annotation.isEmpty ? nil : candidate.annotation
            )
        }
        return RimeSnapshot(
            preedit: native.preedit,
            rawInput: native.rawInput,
            candidates: candidates,
            selectedCandidateIndex: native.selectedCandidateIndex >= 0
                ? native.selectedCandidateIndex
                : nil,
            committedText: native.committedText,
            pageIndex: native.pageIndex,
            pageSize: native.pageSize,
            hasNextPage: native.hasNextPage,
            schemaID: native.schemaID
        )
    }
}

/// Factory for the native librime session. This type has no local algorithm
/// fallback. Resource, deployment, native initialization, and session errors
/// are returned to the caller.
public struct RimeEngineAdapter: Sendable {
    public init() {}

    public var status: RimeEngineStatus {
        RimeResourceInstaller.hasBundledResources ? .configured : .unavailable
    }

    public func makeSession(
        configuration: RimeSessionConfiguration = RimeSessionConfiguration(),
        driver: (any RimeSessionDriver)? = nil
    ) -> RimeSession {
        RimeSession(configuration: configuration, driver: driver)
    }

    public func makeBundledSession(
        applicationIdentifier: String = "PinyinKeyboard"
    ) throws -> RimeSession {
        guard status == .configured else {
            throw RimeEngineError.resourcesUnavailable
        }
        let paths: RimeResourcePaths
        do {
            paths = try RimeResourceInstaller.prepare(
                applicationIdentifier: applicationIdentifier
            )
        } catch {
            throw RimeEngineError.native(error.localizedDescription)
        }
        let configuration = RimeSessionConfiguration()
        let driver = RimeKitSessionDriver(paths: paths, schemaID: configuration.schemaID)
        return RimeSession(configuration: configuration, driver: driver)
    }
}
