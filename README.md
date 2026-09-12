# Pinyin Keyboard

从零实现的 iOS 16+ 简体中文 26 键拼音输入法工程。中文输入默认使用实际链接的 librime 会话；缺少 RIME 资源或 native session 启动失败时显示明确错误，不回退到手写算法。

## 范围

- 26 键 QWERTY 拼音输入。
- 中文、英文、数字、符号模式。
- 拼音组合文本、候选词栏、候选选择、横向滚动。
- 首选候选空格上屏。
- 数字选词可由数字键或点击候选完成。
- 退格优先删除组合串，组合为空后删除正文。
- 回车提交未匹配的原始拼音。
- Shift、Caps Lock、空格、回车、地球键、模式切换。
- 中文标点映射。
- RIME 默认方案：librime `RimeStatic 1.16.1-pack.8` 与雾凇拼音 `2026.06.30`。
- 固定静态包不含 Lua runtime。构建时使用 `scripts/rime_ice.mobile.schema.yaml` 作为移动核心 schema，保留雾凇全拼词典、OpenCC 简繁转换资源、用户词典和完整依赖文件；不启用 `lua_*` 组件。
- LocalPinyinEngine 仅供显式测试或离线对照注入。生产默认路径不创建、不调用该实现。

## 架构

- PinyinCore：Swift Package。实现状态机、显式 LocalPinyinEngine 测试实现、RimeKit 风格 Objective-C bridge、持久 RIME session/snapshot 边界和资源安装器。
- KeyboardExtension：UITextDocumentProxy 适配、KeyboardKit action handler、候选栏和标准键盘视图。
- App：启用步骤、隐私说明、离线状态和设置入口。
- project.yml：XcodeGen 工程描述。

KeyboardKit 固定为 10.9.4。只使用公开 KeyboardInputViewController、KeyboardView、标准 action handler、标准 layout/styling API。不复制 KeyboardKit 源码，不使用 Pro 功能。KeyboardKit 二进制只由主 App 链接；键盘扩展通过主 App 的 Frameworks runpath 解析。

## 构建

构建需要 macOS、Xcode 15 或更高版本、Swift 5.9 和 XcodeGen。

    brew install xcodegen
    bash scripts/prepare-rime-resources.sh
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project PinyinKeyboard.xcodeproj
    xcodebuild -project PinyinKeyboard.xcodeproj -scheme PinyinKeyboard -sdk iphoneos -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

`scripts/prepare-rime-resources.sh` 下载固定版本并校验 SHA256，随后写入移动核心 schema。运行时等待 RIME maintenance 完成，检查 `build/default.yaml`、schema、prism 和 table 输出，并显示 deployment、schema、plugin、context 状态。GitHub Actions 在生成 Xcode 工程前执行同一资源准备逻辑，并上传未签名 IPA。生成的 PinyinKeyboard.xcodeproj 不提交到当前工作区。Windows 环境不能运行 Xcode、iOS Simulator 或 xcodebuild。

## 隐私约束

默认配置为 `RequestsOpenAccess=false`。键盘扩展不联网、不发送按键、不保存按键历史。主 App 只显示启用和状态信息。项目不包含 AI、剪贴板、云服务或 GuruIM 数据采集功能。

## 许可证和来源

原始代码使用 MIT 许可证，见 LICENSE。KeyboardKit、LicenseKit、librime、librime-xcframework 和雾凇拼音资源保留各自许可证，见 THIRD_PARTY_NOTICES.md。本项目不复制 GuruIM 源代码；仅按其公开的 RIMEKit/librime/资源分层路线实现独立边界。本实现的 LocalPinyinEngine 词表由本项目手工编写，不复制专有词库、模型或资源，且不属于默认运行路径。
