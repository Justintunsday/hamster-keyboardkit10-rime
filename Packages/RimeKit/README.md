# RimeKit

使用 Objective-C 调用 librime 的 api，并桥接到Swift中，最终由 Rime.swift 提供 librime 的相关 API。

注意：为了减小项目大小，没有将依赖的二进制 framework 放到项目中，编译时需要先下载依赖的二进制 framework。

编译好的 framework 使用可用兼容 fork 的 release：https://github.com/amorphobia/LibrimeKit/releases/tag/v0.1.0。

可在项目根路径下执行 `make framework` 下载。

# 注意事项

`SbxlmRimeKitObjC` 与 `SbxlmRimeKit` 均为软链接，是为了解决声笔输入使用改版的 `librime`, 即 `"librime-sbxlm`
