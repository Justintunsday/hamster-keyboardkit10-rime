# Third-Party Notices

本文件记录构建和 IPA 打包使用的第三方组件。项目未复制 GuruIM 的 AI、剪贴板、GURU、云服务或文件服务代码。

## KeyboardKit 10.9.4

来源：[KeyboardKit](https://github.com/KeyboardKit/KeyboardKit)。

项目通过 Swift Package Manager 固定 10.9.4。依赖的官方二进制包校验和：

    1438fe94a40503519b0a070261d37234d657e65331a7dc327d32c4086b140c60

KeyboardKit 的源代码、二进制和商标按上游许可证处理。本项目只调用公开 API，不复制实现，不使用 Pro 专属功能。KeyboardKit 产品只链接主 App；键盘扩展使用主 App Frameworks 的运行路径。

## LicenseKit 2.2.4

KeyboardKit 10.9.4 的传递依赖。按其上游许可证处理。本项目不直接调用或复制其实现。

## librime-xcframework 1.16.1-pack.8

来源：[ghostflyby/librime-xcframework](https://github.com/ghostflyby/librime-xcframework)。固定 tag commit：

    c3cbebee642a3f880fcd038f03b59842f8a5c7d1

使用 SwiftPM 产品 `RimeStatic`。发布资产 `librime-static.xcframework.zip` SHA256：

    25f4cd03c6c22a6e41504b567f26928491e9f767c22a9dd6b8697e205a0cadc0

包装仓库和上游 librime 使用 BSD 3-Clause。静态资产可能包含 vcpkg 依赖；上游发布包中的 `LICENSE.txt`、`THIRD_PARTY_NOTICES.md` 和 `third-party-notices.zip` 随二进制保留。IPA 通过静态链接把 RimeStatic 放入键盘扩展二进制，不复制 RimeStatic 源码。

## rime-ice 2026.06.30

来源：[iDvel/rime-ice](https://github.com/iDvel/rime-ice)，release commit：

    6810e8916d160498620a16fef2135956fecbd485

CI 使用 `full.zip`，SHA256：

    675d23b070be00e1b800f9a6db033ef98f4493cd5b568ed8aa3b3541769c46ac

该资源包包含 schema、词典、Lua、OpenCC 数据和 `LICENSE`。资源许可证为 GPL-3.0。资源作为未修改数据文件打包到 Swift package resource bundle；使用和再分发必须遵守资源包许可证。资源包的完整许可证文件随 IPA 保留。

## GuruIM 公开参考

来源：[CauT/GuruIM](https://github.com/CauT/GuruIM)，参考固定提交 `bee7c4da71352753d5f4b6ea607cddea04b9dbe6`。GuruIM 代码仓库使用 MIT 加 Commons Clause；本项目不链接、复制或分发 GuruIM 代码，仅采用其公开的 RimeKit/librime/输入资源分层路线。该参考不改变本项目或上述组件的许可证。

## RimeKitBridge

`PinyinCore/Sources/RimeKitBridge` 为本项目从零编写的 Objective-C bridge，仅调用 librime 公共 C API。该 bridge 按根目录 LICENSE 的 MIT 许可证发布，不包含 GuruIM 源代码。

## 项目原创部分

PinyinCore 状态机、候选模型、动态规划切分、小型 LocalPinyinEngine 词表、Rime session/snapshot 适配、键盘扩展适配和主 App 代码从零编写，使用根目录 LICENSE 中的 MIT 许可证。
