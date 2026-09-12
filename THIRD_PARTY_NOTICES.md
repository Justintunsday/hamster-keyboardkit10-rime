# Third-Party Notices

## KeyboardKit 10.9.4

来源：[KeyboardKit](https://github.com/KeyboardKit/KeyboardKit)。

项目通过 Swift Package Manager 在 project.yml 中固定 10.9.4。依赖的官方二进制包校验和为：

    1438fe94a40503519b0a070261d37234d657e65331a7dc327d32c4086b140c60

本项目只调用 KeyboardKit 的公开 API。KeyboardKit 的源代码、二进制和商标按上游许可证处理。本项目不复制 KeyboardKit 实现，不使用 Pro 专属功能，不捆绑 Pro 授权。

## LicenseKit 2.2.4

KeyboardKit 10.9.4 的传递依赖。由 KeyboardKit 的 Swift Package manifest 固定为 2.2.4。按其上游许可证处理。本项目不直接调用或复制其实现。

## RimeStatic 1.16.1-pack.1

目标来源：[ghostflyby/librime-xcframework](https://github.com/ghostflyby/librime-xcframework)。当前未集成二进制、C 头文件、词库或 Rime 数据。RimeEngineAdapter 只保留边界和失败状态。完成生命周期、资源部署、架构和许可证核验后，才能添加依赖。

## pinyin-data

候选来源：[mozillazg/pinyin-data](https://github.com/mozillazg/pinyin-data)，许可证为 MIT。当前未复制或打包其数据。后续集成必须对具体文件、上游数据和许可证进行逐项记录。

## 项目原创部分

PinyinCore 的状态机、候选模型、动态规划切分、小型词表、键盘扩展适配和主 App 代码从零编写，使用根目录 LICENSE 中的 MIT 许可证。
