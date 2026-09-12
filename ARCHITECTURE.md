# Architecture

## Modules

### PinyinCore

CompositionState 保存模式、原始拼音、候选、Shift 和 Caps Lock 状态。

PinyinInputStateMachine 接收按键语义事件并返回 PinyinTransition。转换结果同时描述状态更新、待上屏文本、是否删除正文和是否清除 marked text。键盘扩展不直接修改核心状态。

LocalPinyinEngine 使用独立的小型词表。引擎执行以下操作：

1. 验证 ASCII 拼音输入前缀。
2. 使用动态规划切分合法音节。
3. 使用词频和完整匹配加分排序。
4. 对词表拼音执行前缀检索。

RimeEngineAdapter 默认创建 RimeKitSessionDriver。RimeKitBridge 只封装 librime 公共 C API；RimeResourceInstaller 负责把 CI 打包的雾凇资源复制到扩展 Application Support，并触发 RIME deploy。RIME 无法启动时进入显式错误状态，不调用 LocalPinyinEngine。

### KeyboardExtension

KeyboardSession 默认创建 RimeEngineAdapter 和持久 RimeSession，启动失败时保留失败状态和错误文本。KeyboardViewController 初始化 KeyboardKit，安装 PinyinActionHandler，创建标准 KeyboardView，并根据模式更新 KeyboardKit keyboard context。

PinyinActionHandler 将 KeyboardKit action 映射到核心状态机：

- character -> 拼音或直接文本输入
- backspace -> 组合删除或正文删除
- space -> 首选候选提交或空格
- primary -> 回车
- shift -> Shift 状态
- nextKeyboard -> advanceToNextInputMode

TextDocumentProxyAdapter 是唯一写入宿主文本框的层。它只调用 UITextDocumentProxy 的 setMarkedText、insertText、deleteBackward。

PinyinKeyboardView 在标准 KeyboardKit 视图上方增加候选栏和模式栏。候选栏通过 SwiftUI 横向滚动视图显示候选。

### App

主 App 不处理按键。它显示启用步骤、离线状态、开放访问状态和设置入口。

## 数据流

    KeyboardKit action
        -> PinyinActionHandler
        -> KeyboardSession
        -> PinyinInputStateMachine
        -> RimeSession
        -> PinyinTransition
        -> TextDocumentProxyAdapter
        -> UITextDocumentProxy

候选按钮直接调用同一状态机的 selectCandidate，不绕过核心模块。

## 安全边界

- 键盘扩展不启用开放访问。
- 不配置 App Group。
- 不配置网络权限。
- 不联网处理按键。
- 不使用私有 KeyboardKit API。
- 不复制 KeyboardKit 闭源实现或 Pro 实现。
