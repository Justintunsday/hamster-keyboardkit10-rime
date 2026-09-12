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

    private let driver: (any RimeSessionDriver)?

    public init(
        configuration: RimeSessionConfiguration = RimeSessionConfiguration(),
        driver: (any RimeSessionDriver)? = nil
    ) {
        self.configuration = configuration
        self.driver = driver
        self.snapshot = .empty
    }

    public func start() throws {
        guard let driver else {
            throw RimeEngineError.notConfigured
        }

        snapshot = try driver.start()
        isStarted = true
    }

    public func stop() {
        driver?.stop()
        isStarted = false
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
            throw driver == nil
                ? RimeEngineError.notConfigured
                : RimeEngineError.notStarted
        }

        let nextSnapshot = try operation(driver)
        snapshot = nextSnapshot
        return nextSnapshot
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
        let installedVersion = try? String(contentsOf: markerURL, encoding: .utf8)
        if installedVersion?.trimmingCharacters(in: .whitespacesAndNewlines) != resourceVersion {
            if fileManager.fileExists(atPath: sharedURL.path) {
                try fileManager.removeItem(at: sharedURL)
            }
            try fileManager.copyItem(at: source, to: sharedURL)
            try resourceVersion.write(to: markerURL, atomically: true, encoding: .utf8)
        }

        let customDefault = userURL.appendingPathComponent("default.custom.yaml")
        if !fileManager.fileExists(atPath: customDefault.path) {
            let contents = """
            patch:
              schema_list:
                - schema: rime_ice
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
        snapshot(from: nativeSession.reset())
    }

    public func process(_ key: RimeKey) throws -> RimeSnapshot {
        switch key {
        case .text(let text):
            return snapshot(from: nativeSession.processText(text))
        case .backspace:
            return snapshot(from: nativeSession.processBackspace())
        case .space:
            return snapshot(from: nativeSession.processSpace())
        case .enter:
            return snapshot(from: nativeSession.processReturn())
        case .candidate(let index):
            return snapshot(from: nativeSession.selectCandidate(at: index))
        case .reset:
            return snapshot(from: nativeSession.reset())
        }
    }

    public func deleteBackward() throws -> RimeSnapshot {
        snapshot(from: nativeSession.processBackspace())
    }

    public func selectCandidate(at index: Int) throws -> RimeSnapshot {
        snapshot(from: nativeSession.selectCandidate(at: index))
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

/// PinyinEngine-compatible fallback surface. Stateful RIME operations are
/// exposed through `makeBundledSession`; LocalPinyinEngine remains the only
/// fallback when the native binary or resource set cannot start.
public struct RimeEngineAdapter: PinyinEngine, Sendable {
    private let fallback: LocalPinyinEngine

    public init(fallback: LocalPinyinEngine = LocalPinyinEngine()) {
        self.fallback = fallback
    }

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
    ) -> RimeSession? {
        guard status == .configured,
              let paths = try? RimeResourceInstaller.prepare(
                applicationIdentifier: applicationIdentifier
              ) else {
            return nil
        }
        let configuration = RimeSessionConfiguration()
        let driver = RimeKitSessionDriver(paths: paths, schemaID: configuration.schemaID)
        return RimeSession(configuration: configuration, driver: driver)
    }

    public func start() throws {
        guard status == .configured else {
            throw RimeEngineError.notConfigured
        }
    }

    public func stop() {}

    public func candidates(for input: String, limit: Int) -> [PinyinCandidate] {
        fallback.candidates(for: input, limit: limit)
    }

    public func isValidInputPrefix(_ input: String) -> Bool {
        fallback.isValidInputPrefix(input)
    }

    public func bestSegmentation(for input: String) -> [String]? {
        fallback.bestSegmentation(for: input)
    }
}
