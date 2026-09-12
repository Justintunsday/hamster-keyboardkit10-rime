import Foundation

public enum RimeEngineStatus: String, Equatable, Sendable {
    case unavailable
    case configured
}

public enum RimeEngineError: Error, Equatable, Sendable {
    case notConfigured
}

/// Compile-safe integration boundary for a future RimeStatic build.
///
/// The package does not import Rime headers, bundle Rime data, or claim an
/// initialized Rime session. Enable a real implementation only after the C
/// API lifecycle and resource deployment are verified on a macOS/Xcode build.
public struct RimeEngineAdapter: PinyinEngine, Sendable {
    public init() {}

    public var status: RimeEngineStatus {
        .unavailable
    }

    public func start() throws {
        throw RimeEngineError.notConfigured
    }

    public func stop() {}

    public func candidates(for input: String, limit: Int) -> [PinyinCandidate] {
        []
    }

    public func isValidInputPrefix(_ input: String) -> Bool {
        false
    }

    public func bestSegmentation(for input: String) -> [String]? {
        nil
    }
}
