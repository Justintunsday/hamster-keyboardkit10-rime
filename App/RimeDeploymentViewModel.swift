import Combine
import PinyinCore
import UIKit

final class RimeDeploymentViewModel: ObservableObject {
    @Published private(set) var state: RimeDeploymentState

    private let coordinator = RimeDeploymentCoordinator()

    init() {
        state = coordinator.status()
    }

    var statusTitle: String {
        switch state {
        case .notDeployed:
            return "未部署"
        case .deploying:
            return "部署中"
        case .ready:
            return "成功"
        case .failed:
            return "失败"
        }
    }

    var statusDetail: String? {
        switch state {
        case .notDeployed:
            return "首次使用前部署本地 RIME 资源。"
        case .deploying:
            return "主 App 正在准备共享资源。保持应用运行。"
        case .ready(let manifest):
            return "\(manifest.schemaID) / \(manifest.schemaVersion)"
        case .failed(let message):
            return message
        }
    }

    func refresh() {
        state = coordinator.status()
    }

    func deployIfNeeded() {
        if case .notDeployed = state {
            deploy()
        }
    }

    func deploy() {
        guard !isDeploying else {
            return
        }
        state = .deploying
        let backgroundTask = UIApplication.shared.beginBackgroundTask(
            withName: "PinyinKeyboard RIME deployment"
        )
        let coordinator = self.coordinator
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result: Result<RimeDeploymentManifest, Error>
            do {
                result = .success(try coordinator.deploy())
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                guard let self else {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    return
                }
                switch result {
                case .success(let manifest):
                    self.state = .ready(manifest)
                case .failure(let error):
                    self.state = .failed(error.localizedDescription)
                }
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }

    private var isDeploying: Bool {
        if case .deploying = state {
            return true
        }
        return false
    }
}
