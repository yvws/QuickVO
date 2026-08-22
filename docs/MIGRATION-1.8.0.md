# 升级到 1.8.0

下面每一条都对照各版本 `QuickVO.xcframework` 的 `.swiftinterface` 逐行核对过。

## 先看你从哪个版本来

改动量取决于你的起点，这两条路差别很大：

| 你现在用的版本 | 需要做什么 |
| --- | --- |
| **1.7.4 – 1.7.9** | **没有破坏性变更。** 只需检查一处穷举 `switch`，见下面「[从 1.7.4 及以后升级](#从-174-及以后升级)」 |
| **1.7.3 或更早** | 有 4 处编译期破坏和 4 处行为变化，典型接入点改动量 3 行。见「[从 1.7.3 及更早升级](#从-173-及更早升级)」 |

> 早前这份文档把那 4 处破坏归给了 1.8.0。核对 `.swiftinterface` 后确认它们实际随 **1.7.4** 发布：`RTCConfig` 在 1.7.3 的接口里还在，1.7.4 就已经没有了，`endpointNotConfigured`、`logEnvironment`、`defaultIceURL` 也都是 1.7.4 出现的。已按实际发布版本更正。

---

## 1.8.0 本身有什么

相对 1.7.9，公开接口是**纯增量的**：60 个新声明，零删除、零签名变更。全部属于新的诊断与崩溃上报子系统。

- `QVDiagnostics`（`install` / `isInstalled` / `captureReport` / `uploadReportsNow` / `deliverPendingReports` / `setReportUploader` / `setUploadsRoutineSegments`）
- `QVDiagnosticsOptions`、`QVReportUploader`、`QVUploadRequest` / `QVUploadOutcome` / `QVUploadProgress` / `QVUploadNowResult`、`QVReportKind`

用法见 [README 的「诊断与崩溃上报」](../README.md#诊断与崩溃上报)。两件事值得在升级时就决定：

1. **崩溃捕获是 opt-in 的**，不调用 `QVDiagnostics.install()` 就不安装。如果你的 App 已经在用 Crashlytics / Sentry / Bugsnag，**不要调用它** —— 两套收集器会争抢同一组信号处理器。
2. **日志上报默认开启**（仅在出错或崩溃时上传，常规日志段不传）。关闭是 `RTCEngine.engine.uploadLog = false`，改投自己的服务是实现 `QVReportUploader`。上传内容清单见 README 的隐私小节。

### 从 1.7.4 及以后升级

唯一需要检查的地方：`ConnectError` 新增了一个 case。

```swift
case screenShareGroupUnavailable(String)
```

屏幕共享时 App Group 容器不可达会抛它 —— 这个错误此前不存在，App Group 配错的表现是对端静默黑屏。**如果你对 `ConnectError` 做了没有 `default` 的穷举 `switch`，会编译不过**，补一个 case 或 default 即可。

除此之外，1.7.4 → 1.8.0 不需要改任何代码。

---

## 从 1.7.3 及更早升级

以下内容随 **1.7.4** 发布。如果你已经在 1.7.4 及以后，跳过这一节。

## 一、为什么会有破坏性变更

一句话：**信令地址是部署事实，不是房间属性。**

旧模型里 `socketURL` 存在每个房间的 `RTCConfig` 上。而实际用法是「每通电话新建一个 `RTCRoom`」，于是一个进程级别、长期不变的地址，被存在了短命对象上。要让它保持正确只能靠 `resetConfig(_:)` 一次次去补，而下一次建房间又会把补丁冲掉——如果你像很多接入方那样把 `RTCConfig` 缓存成 `static let`，它在首次访问时就把当时的地址冻住了，之后再拿到的新地址永远进不去。

```
旧：地址挂在短命对象上，靠打补丁维持
    RTCEngine ── create(appId)
    RTCRoom#1 ── RTCConfig(socketURL) ──┐
    RTCRoom#2 ── RTCConfig(socketURL) ──┼── 每个都要单独设，漏一个就连错地方
    RTCRoom#3 ── RTCConfig(socketURL) ──┘

新：地址挂在进程级对象上，房间加入时取一份快照
    RTCEngine ── create(appId, socketURL:) 或 configure(socketURL:)
        │
        └── RTCRoom#1/#2/#3 ── join 时各取一份快照，整场会话不变
```

配套地，「没配地址」从「悄悄用一个内置默认值」变成了一个显式错误。

---

## 二、必改：不改编译不过

### 1. `RTCConfig` 已删除

这个类型整体消失，包括 `RTCConfig(socketURL:iceURL:rtcStatsDataChannelPreferenceSeconds:)`。三个属性各自搬了家：

| 原属性 | 新位置 |
| --- | --- |
| `socketURL` | `RTCEngine.engine.socketURL` |
| `iceURL` | `RTCEngine.engine.iceURL` |
| `rtcStatsDataChannelPreferenceSeconds` | `RTCRoomConfig.config` |

```swift
// 旧
extension RTCConfig {
    static let myConfig = RTCConfig(socketURL: URL(string: signalURL)!, iceURL: nil)
}

// 新：整段删掉，不需要替代品
```

### 2. `RTCRoom.init(with:delegat:)` → `RTCRoom.init(delegat:)`

```swift
// 旧
let room = RTCRoom(with: myConfig, delegat: self)

// 新
let room = RTCRoom(delegat: self)
```

已经在用 `RTCRoom()` 无参构造的地方不用动，但要确认地址已经通过 engine 配过了（见第 5 条）。

### 3. `RTCRoom.resetConfig(config:)` → `RTCEngine.engine.configure(socketURL:)`

地址晚到是被支持的正常流程，只是配置的对象从房间换成了引擎。

```swift
// 旧：设在某一个房间上
room.resetConfig(config: RTCConfig(socketURL: url))

// 新：设在引擎上，对之后所有房间生效
RTCEngine.engine.configure(socketURL: url)
```

**一个语义变化**：`configure(...)` 只影响**下一次** join，不会改动正在进行的会话。旧的 `resetConfig` 会当场改掉 socket 和 ICE，却按设计不改 `whiteboardURL`——同一个房间半边跟着新地址、半边留在旧地址。现在整场会话被钉在它加入时的那个地址上，要换地址就 `quit()` 之后重新 `join()`。

### 4. 如果直接 `#import` 过这几个 ObjC 头文件

`VideoSampleBufferConverter.h`、`RTCYUVConverterT.h`、`RTCI420FrameT.h`、`RTCVideoUtilT.h` 及 21 个 libyuv 头文件全部从 framework 移除，`Headers/` 目录现在是空的，SDK 是纯 Swift。

这几个类**从来就没法用**：framework 里带着 6 个未解析的 libyuv 符号，任何真的去调用它们的代码都会在链接期报 undefined symbol。所以这里删掉的是一个坏掉的公开 API，不是一个能用的功能。如果你的工程里有这几个文件的**自己的副本**（Broadcast Extension 常见这么做），不受影响，继续用你的副本即可。

---

## 三、必知：编译能过，但行为变了

### 5. 没配地址时 `join` 会抛错

```swift
ConnectError.endpointNotConfigured
// "endpoint is not configured. Call RTCEngine.create(_:socketURL:) or
//  RTCEngine.engine.configure(socketURL:) before join"
```

旧版本在没配地址时会静默使用一个内置默认地址。现在它是显式错误。

**如果你的 `ConnectError` switch 没有 `default` 分支，会编译不过**，补一个 case 或 default 即可。

实际会踩到这条的场景只有一种：`RTCEngine.create` 之后、地址到手之前就去 join。原来这种情况会连到内置地址上（大概率连不通，表现为超时），现在会立刻拿到一个说明原因的错误。

### 6. ICE / STUN 的层次关系

`RTCEngine.engine.iceURL` 默认是 5 个公共 STUN 服务器（`RTCEngine.defaultIceURL` 可读）。三层叠加，只有中间一层归你管：

- 你传入的列表**整体替换**内置默认列表（不是追加）；
- 服务端下发的 TURN **追加**在你的列表之后；
- 服务端若选择 relay-only 策略，你这层 STUN 根本不参与候选收集。

`configure(socketURL:)` 不传 `iceURL` 时保持原列表不变，不会把你注入过的列表悄悄清空。

### 7. `RTCRoomConfig.defaultVideo` / `defaultAudio` 现在每次返回新实例

以前它们是 `static let`，和 `RTCRoomConfig.config.video` **是同一个对象**：

```swift
RTCRoomConfig.config.video.width = 640   // 旧版本：把 SDK 的「默认 1280」也一起改掉了
```

这个别名问题已修复，`RTCEngine.destroy()` 现在能真正把配置恢复到出厂值（以前那句恢复是在把对象赋值给它自己）。如果你的代码**依赖**了「改 config 就等于改 default」这个副作用，需要显式改两处；正常用法不受影响。

同时新增了可读的默认值常量：`RoomVideoCaptureConfig.defaultWidth` / `defaultHeight` / `defaultFps`，`RoomAudioCaptureConfig.defaultEchoCancellation` / `defaultNoiseSuppression` / `defaultAutoGainControl`。

### 8. SDK 自身日志上报地址变更

旧地址 `logs1.quickvo.org` 已经没有 DNS 记录，也就是说**日志上报一直在无声失败**。新地址：

| 环境 | 地址 |
| --- | --- |
| 生产（默认） | `prod-sdk-logs.quickvo.org` |
| 开发 / beta | `dev-sdk-logs.quickvo.org` |

选择方式见下一节。上报失败现在会打一条 warning 到 `RTCEngine.engine.onLog`，不会再悄悄吞掉。

---

## 四、新增能力

### `logEnvironment`：beta 包把 SDK 日志发到 dev

```swift
// 生产包：不用写，默认就是 .production
RTCEngine.create(appId, socketURL: url)

// beta / 开发包
RTCEngine.create(appId, socketURL: url, logEnvironment: .development)
```

**只能在 `create` 时传**，事后设置无效。因为 `create` 内部就会把上一次会话遗留的日志立刻上传——而那条日志之所以存在，通常正是因为上次会话出了问题，是最不该丢的一条。

### 配置可读回

`socketURL`、`iceURL`、`logEnvironment` 现在都是 `public private(set)`，可以直接读出来确认 SDK 实际在用什么。旧的 `RTCConfig.socketURL` 是 `internal`——能写不能读，这也是那个被冻结的地址长期没被发现的原因之一。

```swift
assert(RTCEngine.engine.socketURL != nil, "地址还没配")
```

### pre-publish 半配置会告警

`prePublishAuthToken` 和 `prePublishBaseURL` 只配了一个时，join 仍会走 WebSocket 路径正常完成（只是发布慢一点），但现在会打一条 warning 指出缺的是哪个。两个都不配是默认情况，保持安静。

---

## 五、迁移步骤

先扫一遍影响面：

```bash
rg -n "RTCConfig|resetConfig|RTCRoom\(with:|RTCRoom\.init\(with:" --type swift
rg -n "VideoSampleBufferConverter|RTCYUVConverterT|RTCI420FrameT|RTCVideoUtilT"
```

然后按顺序：

1. **删掉所有 `RTCConfig` 的定义和扩展**，包括缓存成 `static let` 的那些。
2. **`RTCRoom(with:…)` 改成 `RTCRoom()` 或 `RTCRoom(delegat:)`。**
3. **地址已知**就并进 `create`：`RTCEngine.create(appId, socketURL: url)`；**地址晚到**就在拿到时调 `RTCEngine.engine.configure(socketURL: url)`，替换原来的 `resetConfig`。
4. **beta 包加上 `logEnvironment: .development`。**
5. **检查 `ConnectError` 的 switch** 是否穷举，补 `.endpointNotConfigured` 或 `default`。
6. **确认 join 之前地址一定已配。**

改完的典型形态：

```swift
// 启动
RTCEngine.create(appId)

// 地址到手（网络回调里）
Task {
    let url = await fetchSignalURL()
    RTCEngine.engine.configure(socketURL: url)
}

// 每通电话
let room = RTCRoom(delegat: self)
try await room.join(token, roomId, option)
```

### 唯一一处编译器不会提醒你的地方

`RTCEngine.create(_:socketURL:iceURL:logEnvironment:)` 的新参数都有默认值，所以 `RTCEngine.create(appId)` **照样能编译**。如果你只做了前两步（删 `RTCConfig`、改 `RTCRoom()`）却漏了第三步，代码会干净地通过编译，然后在 join 的时候抛 `.endpointNotConfigured`。

这是本次变更里唯一一处编译器帮不上忙的地方，所以第 3 步值得单独核对一遍：每一个 `RTCEngine.create` 调用点，都要能回答「这个进程的地址是在哪一行进 engine 的」。

---

## 六、不变的部分

以下都没动，不用改：

- `RoomLocalOption` 的全部字段和构造器，包括 `userId`、`publishType`、`prePublishAuthToken` / `prePublishBaseURL`
- `join` / `quit` / 推拉流 / 白板 / 屏幕共享的全部 API
- `RTCRoomConfig.config.video.*` / `audio.*` 的读写方式
- `RTCRoomDelegate` 与 `RTCParticipantDelegate` 的全部回调
- `RTCEngine.engine.onLog` / `netStatus` / `netType` / `uploadLog`
- SPM 依赖声明和集成方式

---

## 七、产物层面的变化（无需任何改动）

- framework 不再包含任何构建机绝对路径（此前 76 个源文件路径、1371 处）
- 不再包含开发 / 测试域名
- `Headers/` 从 26 个头文件变成 0 个，SDK 现在是纯 Swift
- 不再携带 6 MB 的 `libyuv.a`，也不再有 6 个未解析的 libyuv 符号
- 只有 `arm64` 切片（此前 `libyuv.a` 混进了 `armv7 i386 x86_64`）

这些在每次发版前由构建流程强制检查，任一项不达标构建直接失败。

---

## 完整 API 变更表

按实际发布版本归属。

### 1.7.3 → 1.7.4

| 变更 | 1.7.3 | 1.7.4 |
| --- | --- | --- |
| 删除 | `struct RTCConfig` | — |
| 删除 | `RTCRoom.init(with:delegat:)` | `RTCRoom.init(delegat:)` |
| 删除 | `RTCRoom.resetConfig(config:)` | `RTCEngine.engine.configure(socketURL:iceURL:)` |
| 签名 | `RTCEngine.create(_:)` | `RTCEngine.create(_:socketURL:iceURL:logEnvironment:)` |
| 语义 | `RTCRoomConfig.defaultVideo` 为 `static let` | 改为 `static var { get }`，每次返回新实例 |
| 新增 | — | `RTCEngine.socketURL` / `iceURL` / `logEnvironment` / `defaultIceURL` |
| 新增 | — | `enum RTCLogEnvironment { development, production }` |
| 新增 | — | `ConnectError.endpointNotConfigured` |
| 新增 | — | `RTCRoomConfig.rtcStatsDataChannelPreferenceSeconds` |
| 新增 | — | `RoomVideoCaptureConfig.defaultWidth` / `defaultHeight` / `defaultFps` |
| 新增 | — | `RoomAudioCaptureConfig.defaultEchoCancellation` / `defaultNoiseSuppression` / `defaultAutoGainControl` |
| 移除 | 26 个公开 ObjC 头文件 | 0 |

### 1.7.9 → 1.8.0

零删除、零签名变更。

| 变更 | 1.7.9 | 1.8.0 |
| --- | --- | --- |
| 新增 | — | `enum QVDiagnostics` 及其 7 个静态方法 |
| 新增 | — | `struct QVDiagnosticsOptions`（`.crashes` `.termination` `.watchdog` `.metrics` `.zombies` `.default` `.all`） |
| 新增 | — | `protocol QVReportUploader` |
| 新增 | — | `struct QVUploadRequest` / `enum QVUploadOutcome` |
| 新增 | — | `struct QVUploadProgress` / `struct QVUploadNowResult` |
| 新增 | — | `enum QVReportKind`（`.crash` `.hang` `.outOfMemory` `.nonFatalError` `.routine`） |
| 新增 | — | `ConnectError.screenShareGroupUnavailable(String)` |
| 依赖 | — | 分发清单新增 `KSCrash 2.6.0`（`Recording` + `Filters`） |
