# Local Swift Checks

纯 Swift 静态检查命令：

    cd PinyinCore
    swiftc -version
    swiftc -parse-as-library -typecheck Sources/PinyinCore/*.swift

本交付不运行测试。Windows 不提供 Xcode、iOS SDK 或默认 Swift 工具链，不能在 Windows 验证 RimeStatic、Objective-C bridge 或 xcodebuild。macOS Actions 只执行 Release iphoneos 无签名编译和 IPA 打包。
