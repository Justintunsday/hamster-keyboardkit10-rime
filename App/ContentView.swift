import SwiftUI
import UIKit

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("启用步骤") {
                    Text("打开系统设置，进入通用 > 键盘 > 键盘，添加 Pinyin Keyboard。")
                    Text("在任意文本输入框中使用地球键切换输入法。")
                }

                Section("运行状态") {
                    LabeledContent("引擎", value: "librime 1.16.1-pack.8")
                    LabeledContent("词库", value: "rime-ice 2026.06.30")
                    LabeledContent("失败处理", value: "显示错误，不回退")
                    LabeledContent("网络处理", value: "禁用")
                    LabeledContent("开放访问", value: "禁用")
                }

                Section("隐私") {
                    Text("按键处理在键盘扩展本地完成。当前实现不联网、不启用 RequestsOpenAccess，不上传按键内容。")
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
        }
    }
}

#Preview {
    ContentView()
}
