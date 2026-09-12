import Foundation

public enum PinyinMode: String, CaseIterable, Codable, Equatable, Sendable {
    case chinese
    case english
    case numbers
    case symbols

    public var title: String {
        switch self {
        case .chinese:
            return "中"
        case .english:
            return "英"
        case .numbers:
            return "123"
        case .symbols:
            return "符号"
        }
    }
}

public enum PinyinRuntimeStatus: Equatable, Codable, Sendable {
    case local
    case rimeReady
    case rimeFailed(String)
}

public struct PinyinCandidate: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let text: String
    public let pinyin: String
    public let frequency: Int
    public let score: Int
    public let rank: Int

    public init(
        text: String,
        pinyin: String,
        frequency: Int,
        score: Int,
        rank: Int
    ) {
        self.id = "\(text)|\(pinyin)"
        self.text = text
        self.pinyin = pinyin
        self.frequency = frequency
        self.score = score
        self.rank = rank
    }
}

public struct CompositionState: Equatable, Codable, Sendable {
    public var mode: PinyinMode
    public var rawPinyin: String
    public var candidates: [PinyinCandidate]
    public var isShifted: Bool
    public var isCapsLocked: Bool
    public var runtimeStatus: PinyinRuntimeStatus
    public var rimeDeploymentStatus: String
    public var rimeSchemaID: String?
    public var rimeSchemaSelected: Bool

    public init(
        mode: PinyinMode = .chinese,
        rawPinyin: String = "",
        candidates: [PinyinCandidate] = [],
        isShifted: Bool = false,
        isCapsLocked: Bool = false,
        runtimeStatus: PinyinRuntimeStatus = .local,
        rimeDeploymentStatus: String = "unknown",
        rimeSchemaID: String? = nil,
        rimeSchemaSelected: Bool = false
    ) {
        self.mode = mode
        self.rawPinyin = rawPinyin
        self.candidates = candidates
        self.isShifted = isShifted
        self.isCapsLocked = isCapsLocked
        self.runtimeStatus = runtimeStatus
        self.rimeDeploymentStatus = rimeDeploymentStatus
        self.rimeSchemaID = rimeSchemaID
        self.rimeSchemaSelected = rimeSchemaSelected
    }

    public var isComposing: Bool {
        !rawPinyin.isEmpty
    }
}

public struct PinyinTransition: Equatable, Sendable {
    public let state: CompositionState
    public let insertedText: String?
    public let shouldDeleteBackward: Bool
    public let clearMarkedText: Bool

    public init(
        state: CompositionState,
        insertedText: String? = nil,
        shouldDeleteBackward: Bool = false,
        clearMarkedText: Bool = false
    ) {
        self.state = state
        self.insertedText = insertedText
        self.shouldDeleteBackward = shouldDeleteBackward
        self.clearMarkedText = clearMarkedText
    }
}

public protocol PinyinEngine {
    func candidates(for input: String, limit: Int) -> [PinyinCandidate]
    func isValidInputPrefix(_ input: String) -> Bool
    func bestSegmentation(for input: String) -> [String]?
}
