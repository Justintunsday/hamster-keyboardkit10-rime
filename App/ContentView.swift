import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var deployment = RimeDeploymentViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("启用步骤") {
                    Text("打开系统设置，进入通用 > 键盘 > 键盘，添加 Pinyin Keyboard。")
                    Text("在键盘设置中开启完全访问。完全访问仅用于读取本地 App Group 共享容器中的 RIME 资源和用户词典。")
                    Text("在任意文本输入框中使用地球键切换输入法。")
                }

                Section("RIME 部署") {
                    LabeledContent("状态", value: deployment.statusTitle)
                    if let detail = deployment.statusDetail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    switch deployment.state {
                    case .notDeployed, .failed:
                        Button("部署或重试") {
                            deployment.deploy()
                        }
                    case .deploying:
                        ProgressView()
                    case .ready:
                        Button("重新部署") {
                            deployment.deploy()
                        }
                    }
                }

                Section("运行状态") {
                    LabeledContent("引擎", value: "librime 1.16.1-pack.8")
                    LabeledContent("词库", value: "rime-ice 2026.06.30")
                    LabeledContent("失败处理", value: "显示错误，不回退")
                    LabeledContent("网络处理", value: "禁用")
                    LabeledContent("开放访问", value: "必须开启")
                }

                Section("隐私") {
                    Text("按键处理和 RIME 会话在设备本地完成。键盘扩展不联网。完全访问仅用于 App Group 共享容器中的本地资源、用户词典和部署状态，不上传按键内容。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("打开应用设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        UIApplication.shared.open(url)
                    }
                }
            }
            .navigationTitle("Pinyin Keyboard")
            .onAppear {
                deployment.refresh()
                deployment.deployIfNeeded()
            }
        }
    }
}

#Preview {
    ContentView()
}
