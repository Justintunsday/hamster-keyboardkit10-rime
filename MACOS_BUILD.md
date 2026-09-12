# macOS Build Commands

在 macOS 上执行 Release 设备编译：

    brew install xcodegen
    bash scripts/prepare-rime-resources.sh
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project PinyinKeyboard.xcodeproj
    xcodebuild -project PinyinKeyboard.xcodeproj -scheme PinyinKeyboard -sdk iphoneos -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build

生成 IPA：

    mkdir -p artifacts/Payload
    cp -R build/DerivedData/Build/Products/Release-iphoneos/PinyinKeyboard.app artifacts/Payload/
    (cd artifacts && ditto -c -k --sequesterRsrc --keepParent Payload PinyinKeyboard-unsigned.ipa)

本交付不运行测试。Windows 环境不能运行 XcodeGen、Xcode、iOS SDK 或 KeyboardKit/RimeStatic 二进制链接。GitHub Actions 使用 macOS runner 执行资源准备、Release iphoneos 无签名编译和 IPA 打包。
