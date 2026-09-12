import Foundation
import RimeKitBridge

#if canImport(Darwin)
import Darwin
#endif

public struct RimeDeploymentManifest: Codable, Equatable, Sendable {
    public let status: String
    public let resourceVersion: String
    public let schemaID: String
    public let schemaVersion: String
    public let sharedDataPath: String
    public let userDataPath: String

    public init(
        status: String = "ready",
        resourceVersion: String,
        schemaID: String,
        schemaVersion: String,
        sharedDataPath: String,
        userDataPath: String
    ) {
        self.status = status
        self.resourceVersion = resourceVersion
        self.schemaID = schemaID
        self.schemaVersion = schemaVersion
        self.sharedDataPath = sharedDataPath
        self.userDataPath = userDataPath
    }
}

public enum RimeDeploymentState: Equatable, Sendable {
    case notDeployed
    case deploying
    case ready(RimeDeploymentManifest)
    case failed(String)
}

public enum RimeDeploymentError: Error, Equatable, Sendable {
    case appGroupUnavailable(String)
    case lockUnavailable(String)
    case notDeployed
    case invalidManifest(String)
    case resource(RimeResourceError)
    case native(String)
}

extension RimeDeploymentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "App Group 共享容器不可用: \(identifier)。请开启完全访问并打开主 App 完成部署。"
        case .lockUnavailable(let message):
            return "RIME 部署锁不可用: \(message)"
        case .notDeployed:
            return "RIME 尚未部署。请打开主 App 完成部署后重试。"
        case .invalidManifest(let message):
            return "RIME 完成标记无效: \(message)"
        case .resource(let error):
            return error.localizedDescription
        case .native(let message):
            return message
        }
    }
}

/// Owns App Group deployment. The keyboard extension only consumes the
/// published manifest through `sessionPathsIfReady()`.
public struct RimeDeploymentCoordinator: Sendable {
    public static let defaultAppGroupIdentifier = "group.com.example.PinyinKeyboard"
    public static let schemaID = "rime_ice"
    public static let schemaVersion = "mobile-2026.06.30-1"

    public let appGroupIdentifier: String

    public init(appGroupIdentifier: String = RimeDeploymentCoordinator.defaultAppGroupIdentifier) {
        self.appGroupIdentifier = appGroupIdentifier
    }

    public func status() -> RimeDeploymentState {
        do {
            let manifest = try readManifestWithReadLock()
            _ = try sessionPathsIfReady()
            return .ready(manifest)
        } catch RimeDeploymentError.notDeployed {
            return .notDeployed
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Deploys package resources into an isolated staging directory, runs
    /// librime maintenance there, and publishes the completed directory with
    /// one atomic manifest update. Existing active data remains untouched on
    /// any failure.
    public func deploy() throws -> RimeDeploymentManifest {
        let fileManager = FileManager.default
        return try withLock(exclusive: true) {
            let paths = try makeDeploymentDirectories(fileManager: fileManager)
            let source = try RimeResourceInstaller.validatedBundledResourceRoot()

            if fileManager.fileExists(atPath: paths.stagingRoot.path) {
                try fileManager.removeItem(at: paths.stagingRoot)
            }
            try fileManager.createDirectory(at: paths.stagingRoot, withIntermediateDirectories: true)
            let stagedShared = paths.stagingRoot.appendingPathComponent("SharedData", isDirectory: true)
            let stagedUser = paths.stagingRoot.appendingPathComponent("UserData", isDirectory: true)
            try fileManager.copyItem(at: source, to: stagedShared)

            if let previous = try? readManifestUnlocked(root: paths.root),
               let previousUser = try? resolveManifestPath(previous.userDataPath, root: paths.root),
               fileManager.fileExists(atPath: previousUser.path) {
                try fileManager.copyItem(at: previousUser, to: stagedUser)
            } else {
                try fileManager.createDirectory(at: stagedUser, withIntermediateDirectories: true)
            }

            try RimeResourceInstaller.writeManagedUserConfiguration(to: stagedUser)
            var nativeError: NSError?
            let deployed = RimeKitDeploymentController.deploy(
                withSharedDataPath: stagedShared.path,
                userDataPath: stagedUser.path,
                schemaID: Self.schemaID,
                error: &nativeError
            )
            guard deployed else {
                throw RimeDeploymentError.native(
                    nativeError?.localizedDescription ?? "RIME maintenance/deploy failed"
                )
            }
            try RimeResourceInstaller.validateDeploymentOutputs(
                sharedDataPath: stagedShared,
                userDataPath: stagedUser,
                schemaID: Self.schemaID
            )

            let versionName = "\(RimeResourceInstaller.resourceVersion)-\(UUID().uuidString.lowercased())"
            let finalRoot = paths.versionsRoot.appendingPathComponent(versionName, isDirectory: true)
            try fileManager.moveItem(at: paths.stagingRoot, to: finalRoot)
            let manifest = RimeDeploymentManifest(
                resourceVersion: RimeResourceInstaller.resourceVersion,
                schemaID: Self.schemaID,
                schemaVersion: Self.schemaVersion,
                sharedDataPath: relativePath(
                    finalRoot.appendingPathComponent("SharedData", isDirectory: true),
                    root: paths.root
                ),
                userDataPath: relativePath(
                    finalRoot.appendingPathComponent("UserData", isDirectory: true),
                    root: paths.root
                )
            )
            try writeManifestAtomically(manifest, at: paths.markerURL)
            return manifest
        }
    }

    /// Returns only already-published data. This method never copies package
    /// resources and never invokes librime maintenance.
    public func sessionPathsIfReady() throws -> RimeResourcePaths {
        try withLock(exclusive: false) {
            let paths = try deploymentDirectories()
            let manifest = try readManifestUnlocked(root: paths.root)
            guard manifest.status == "ready",
                  manifest.resourceVersion == RimeResourceInstaller.resourceVersion,
                  manifest.schemaID == Self.schemaID,
                  manifest.schemaVersion == Self.schemaVersion else {
                throw RimeDeploymentError.invalidManifest("资源版本、schema 或状态不匹配")
            }
            let shared = try resolveManifestPath(manifest.sharedDataPath, root: paths.root)
            let user = try resolveManifestPath(manifest.userDataPath, root: paths.root)
            guard FileManager.default.fileExists(atPath: shared.path),
                  FileManager.default.fileExists(atPath: user.path) else {
                throw RimeDeploymentError.invalidManifest("共享资源目录不存在")
            }
            try RimeResourceInstaller.validateDeploymentOutputs(
                sharedDataPath: shared,
                userDataPath: user,
                schemaID: Self.schemaID
            )
            return RimeResourcePaths(sharedDataPath: shared, userDataPath: user)
        }
    }

    private struct DeploymentDirectories {
        let root: URL
        let versionsRoot: URL
        let stagingRoot: URL
        let markerURL: URL
        let lockURL: URL
    }

    private func makeDeploymentDirectories(fileManager: FileManager) throws -> DeploymentDirectories {
        let paths = try deploymentDirectories()
        try fileManager.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.versionsRoot, withIntermediateDirectories: true)
        return paths
    }

    private func deploymentDirectories() throws -> DeploymentDirectories {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw RimeDeploymentError.appGroupUnavailable(appGroupIdentifier)
        }
        let root = container.appendingPathComponent("RimeDeployment", isDirectory: true)
        return DeploymentDirectories(
            root: root,
            versionsRoot: root.appendingPathComponent("versions", isDirectory: true),
            stagingRoot: root.appendingPathComponent("staging", isDirectory: true),
            markerURL: root.appendingPathComponent("deployment-complete.json"),
            lockURL: root.appendingPathComponent("deployment.lock")
        )
    }

    private func readManifestWithReadLock() throws -> RimeDeploymentManifest {
        try withLock(exclusive: false) {
            let paths = try deploymentDirectories()
            return try readManifestUnlocked(root: paths.root)
        }
    }

    private func readManifestUnlocked(root: URL) throws -> RimeDeploymentManifest {
        let marker = root.appendingPathComponent("deployment-complete.json")
        guard FileManager.default.fileExists(atPath: marker.path) else {
            throw RimeDeploymentError.notDeployed
        }
        do {
            let data = try Data(contentsOf: marker)
            return try JSONDecoder().decode(RimeDeploymentManifest.self, from: data)
        } catch {
            throw RimeDeploymentError.invalidManifest(error.localizedDescription)
        }
    }

    private func resolveManifestPath(_ relativePath: String, root: URL) throws -> URL {
        let rootPath = root.standardizedFileURL.path
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(rootPath + "/") else {
            throw RimeDeploymentError.invalidManifest("路径越界")
        }
        return candidate
    }

    private func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return String(path.dropFirst(rootPath.count + 1))
    }

    private func writeManifestAtomically(
        _ manifest: RimeDeploymentManifest,
        at markerURL: URL
    ) throws {
        let data = try JSONEncoder().encode(manifest)
        let temporaryURL = markerURL.deletingLastPathComponent()
            .appendingPathComponent(".deployment-complete-\(UUID().uuidString).tmp")
        try data.write(to: temporaryURL, options: .atomic)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: markerURL.path) {
            _ = try fileManager.replaceItemAt(markerURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: markerURL)
        }
    }

    private func withLock<T>(exclusive: Bool, _ body: () throws -> T) throws -> T {
        let paths = try deploymentDirectories()
        try FileManager.default.createDirectory(
            at: paths.root,
            withIntermediateDirectories: true
        )
        let lock = try RimeDeploymentFileLock(url: paths.lockURL, exclusive: exclusive)
        return try withExtendedLifetime(lock) {
            try body()
        }
    }
}

private final class RimeDeploymentFileLock: @unchecked Sendable {
    #if canImport(Darwin)
    private let descriptor: Int32

    init(url: URL, exclusive: Bool) throws {
        descriptor = open(url.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw RimeDeploymentError.lockUnavailable(String(cString: strerror(errno)))
        }
        let operation = exclusive ? LOCK_EX : LOCK_SH
        guard flock(descriptor, operation) == 0 else {
            let message = String(cString: strerror(errno))
            close(descriptor)
            throw RimeDeploymentError.lockUnavailable(message)
        }
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }
    #else
    init(url: URL, exclusive: Bool) throws {
        throw RimeDeploymentError.lockUnavailable("Darwin file locking is unavailable")
    }
    #endif
}
