# Pinyin Keyboard

从零实现的 iOS 16+ 简体中文 26 键拼音输入法最小工程。

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
- 本地小型词表。词表不代表生产级覆盖率，不声称达到搜狗或百度的专有排序质量。

## 架构

- PinyinCore：Swift Package。实现状态机、独立 LocalPinyinEngine、候选模型和 Rime 适配边界。
- KeyboardExtension：UITextDocumentProxy 适配、KeyboardKit action handler、候选栏和标准键盘视图。
- App：启用步骤、隐私说明、离线状态和设置入口。
- project.yml：XcodeGen 工程描述。

KeyboardKit 固定为 10.9.4。只使用公开 KeyboardInputViewController、KeyboardView、标准 action handler、标准 layout/styling API。不复制 KeyboardKit 源码，不使用 Pro 功能。

## 构建

构建需要 macOS、Xcode 15 或更高版本、Swift 5.9 和 XcodeGen。

    brew install xcodegen
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project PinyinKeyboard.xcodeproj
    xcodebuild -scheme PinyinKeyboard -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
    cd PinyinCore
    swift test

生成的 PinyinKeyboard.xcodeproj 不提交到当前工作区。Windows 环境不能运行 Xcode、iOS Simulator 或 xcodebuild。在 macOS 上执行 xcodegen generate 后再构建。

## 隐私约束

默认配置为 RequestsOpenAccess=false。键盘扩展不联网、不发送按键、不保存按键历史。主 App 只显示启用和状态信息。

## 许可证和来源

原始代码使用 MIT 许可证，见 LICENSE。KeyboardKit、LicenseKit 和未来可选的 Rime 组件保留各自许可证，见 THIRD_PARTY_NOTICES.md。本实现的内置小型词表由本项目手工编写，不复制专有词库、模型或资源。
