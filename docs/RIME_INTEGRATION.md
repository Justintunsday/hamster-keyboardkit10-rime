# RIME Integration

默认中文会话使用 `RimeStatic 1.16.1-pack.8`。RIME native bridge 和 session adapter 从零编写，仅使用 librime 公开 C API。GuruIM 只作为公开架构参考，不作为代码依赖；不集成其 AI、剪贴板、GURU、云同步或文件服务模块。

## 固定输入组件

- `ghostflyby/librime-xcframework` tag `1.16.1-pack.8`，commit `c3cbebee642a3f880fcd038f03b59842f8a5c7d1`。
- `RimeStatic` XCFramework SHA256：`25f4cd03c6c22a6e41504b567f26928491e9f767c22a9dd6b8697e205a0cadc0`。
- `iDvel/rime-ice` release `2026.06.30`，commit `6810e8916d160498620a16fef2135956fecbd485`。
- 雾凇 `full.zip` SHA256：`675d23b070be00e1b800f9a6db033ef98f4493cd5b568ed8aa3b3541769c46ac`。

## 会话边界

1. 主 App 的 `RimeDeploymentCoordinator` 从 Swift package resource bundle 复制 `default.yaml`、移动版 schema、雾凇全拼词典和 OpenCC 资源到 App Group staging 目录，复制已有用户数据，运行 maintenance，验证 build 输出后发布原子完成标记。
2. `RimeKitDeploymentController` 只由主 App 调用 `setup`、`initialize`、`start_maintenance` 和 `join_maintenance_thread`。键盘扩展禁止调用这些部署接口。
3. `RimeKitSession` 只读取主 App 发布的共享目录，调用 `setup`、`initialize`、`create_session` 和 `select_schema`，不会执行部署。
4. `RimeKitBridge` 将 `RimeContext`、`RimeCommit` 和 `RimeStatus` 深拷贝成 Objective-C snapshot，随后由 `RimeKitSessionDriver` 转换为 `RimeSnapshot`。
4. `PinyinInputStateMachine` 将字母、退格、空格、回车、候选点击和标点映射为 RIME key event，并把 commit delta 写入 `UITextDocumentProxy`。

所有中文候选由 librime `process_key`、`get_context`、`select_candidate_on_current_page`、`commit_composition` 和 `get_commit` 产生。RIME user data 位于 App Group 共享容器，session 使用完成标记指定的 user data 目录，用户词频由 RIME translator/user database 持久化。主 App 使用文件锁、隔离 staging 目录和原子标记，扩展不读取未完成目录。
5. 停止时销毁 `RimeSessionId`。宿主文本框写入只经过 `TextDocumentProxyAdapter`。

## 错误处理

缺少资源、资源校验文件缺失、部署失败、schema 选择失败或 session 操作抛错时，状态机进入 `rimeFailed` 状态并在候选栏显示错误。默认路径不创建、不调用 `LocalPinyinEngine`。LocalPinyinEngine 仅可由测试或显式调用方注入，不能模拟 RIME 运行时。

## 资源构建

仓库只提交资源占位目录。macOS 和 CI 执行：

    bash scripts/prepare-rime-resources.sh

脚本完成固定版本下载、SHA256 校验和 Swift package resource 目录准备。CI 在 `xcodegen generate` 前执行该步骤，因此 IPA 包含实际 RIME 资源。主 App 将资源复制到 App Group 可写目录，不修改 bundle。键盘扩展不复制资源，只读取已发布目录。

## 未验证项

Windows 无法运行 Xcode、iOS SDK、XcodeGen 或 SwiftPM Apple binary target。Release iphoneos 无签名构建由 macOS Actions 执行。真机启动时间、内存峰值、App Store 签名和键盘扩展系统启用状态需要设备验证。
