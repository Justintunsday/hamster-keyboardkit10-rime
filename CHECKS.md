# Local Swift Checks

在 macOS 上执行以下纯 Swift 检查：

    cd PinyinCore
    swift test
    swiftc -version

解析检查：

    swiftc -parse-as-library -typecheck Sources/PinyinCore/*.swift

Windows 不提供 Xcode、iOS SDK 或默认 Swift 工具链。本次 Windows 工作区未运行 swift test、swiftc、XcodeGen、xcodebuild 或 iOS Simulator。macOS 上首次执行前运行 xcodegen generate。
