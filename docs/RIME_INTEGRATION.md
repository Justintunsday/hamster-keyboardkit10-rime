# Rime Integration Boundary

当前版本不启用 Rime。

## 目标组件

- 项目：ghostflyby/librime-xcframework
- 目标构建：RimeStatic 1.16.1-pack.1
- 预期用途：在 PinyinEngine 协议后提供完整本地词库引擎。

## 必须完成的工作

1. 在 macOS/Xcode 中验证静态库、头文件和 Swift/Objective-C 模块映射。
2. 明确 rime_api_t 的初始化、创建 session、部署完成检查、commit、候选读取和销毁顺序。
3. 将 Rime 数据部署到键盘扩展可读位置。
4. 验证 iOS 键盘扩展的二进制架构、内存占用和启动时间。
5. 逐个记录二进制、头文件、词库和数据文件的许可证。
6. 增加带真实资源的单元测试和设备测试。

## 当前边界

RimeEngineAdapter 实现 PinyinEngine，但 status 为 unavailable，start() 返回 notConfigured，候选和切分为空。这样保持编译安全，不伪造 C API 生命周期。

project.yml 提供 PINYIN_ENABLE_RIME=0。在上述检查完成前不得改为启用，也不得在未验证资源部署时提交 Rime 数据。
