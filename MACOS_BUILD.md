# macOS Build Commands

在 macOS 上执行：

    brew install xcodegen
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project PinyinKeyboard.xcodeproj
    xcodebuild -scheme PinyinKeyboard -sdk iphonesimulator -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
    cd PinyinCore
    swift test

执行设备测试前，配置有效的签名团队和唯一 Bundle Identifier：

    xcodebuild -scheme PinyinKeyboard -sdk iphoneos -configuration Release build DEVELOPMENT_TEAM=<TEAM_ID>

当前 Windows 环境不能验证 XcodeGen、Xcode、iOS SDK 或 KeyboardKit 二进制链接。
