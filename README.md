<div align="center">

# QuickVO iOS SDK 接入文档

**面向 iOS 的实时音视频（RTC）SDK，基于 WebRTC 构建，支持 SFU / P2P 混合组网。**

[![Platform](https://img.shields.io/badge/platform-iOS%2015.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Device](https://img.shields.io/badge/device-arm64%20only-red.svg)](#环境要求)
[![WebRTC](https://img.shields.io/badge/WebRTC-137.0.1-green.svg)](https://webrtc.org)

</div>

---

## 目录

**接入准备**
[简介](#简介) · [环境要求](#环境要求) · [安装](#安装) · [工程配置](#工程配置) · [快速开始](#快速开始)

**核心 API**
[核心概念](#核心概念) · [引擎 RTCEngine](#引擎-rtcengine) · [房间 RTCRoom](#房间-rtcroom) · [房间委托](#房间委托-rtcroomdelegate) · [参与者与轨道](#参与者与轨道) · [视频渲染](#视频渲染) · [本地音视频控制](#本地音视频控制) · [采集配置](#采集配置)

**业务模块**
[发布与订阅](#发布与订阅) · [Simulcast 大小流](#simulcast-大小流) · [屏幕共享](#屏幕共享) · [房间管控](#房间管控) · [语音识别与翻译](#语音识别与翻译) · [白板](#白板) · [直播 CDN](#直播-cdn) · [网络与质量监控](#网络与质量监控) · [P2P](#p2p) · [美颜与自定义视频处理](#美颜与自定义视频处理) · [断线重连](#断线重连)

**运维与排查**
[诊断与崩溃上报](#诊断与崩溃上报) · [崩溃符号化](#崩溃符号化) · [错误码](#错误码) · [已知限制](#已知限制) · [API 拼写说明](#api-拼写说明) · [版本与迁移](#版本与迁移)

---

## 简介

QuickVO 在 WebRTC 之上封装了一套房间（Room）模型：创建 `RTCRoom`、加入房间、实现委托回调，即可集成 1v1 通话、多人会议、直播连麦等场景，无需直接接触底层 WebRTC 与信令细节。

SDK 内部采用 **SFU（服务端转发）+ P2P（点对点）混合组网**，按网络与场景自动选择链路，并内置断线重连、屏幕共享、美颜、实时语音识别与翻译、诊断上报等能力。

| 能力 | 说明 |
| --- | --- |
| 音视频通话 | 音频 / 视频轨道独立发布与订阅，前后摄像头切换，音频路由切换 |
| SFU + P2P 混合组网 | 服务端按条件下发 P2P 指令，SDK 自动切换，失败回落 SFU |
| 多场景 | 通信（1v1）、会议、直播、会控 |
| 自动断线重连 | 统一重连状态机，策略可通过 `RTCReconnectPolicy` 调优 |
| 屏幕共享 | ReplayKit Broadcast Extension + App Group 共享内存 |
| 美颜滤镜 | 内置 gpupixel 前处理管线，也可接管为自定义处理 |
| 语音识别与翻译 | 服务端 STT 与多语言翻译，支持 20 种语言 |
| 直播 CDN | 直播场景下返回国内 / 海外 / 全球播放地址 |
| Simulcast | 发布侧三层编码，订阅侧可切层 |
| 房间管控 | 禁言 / 禁视频 / 禁屏幕共享、管理员、白板协同 |
| 诊断与崩溃上报 | 日志分段落盘、崩溃捕获、上报通道可自定义 |

---

## 环境要求

| 项目 | 要求 | 说明 |
| --- | --- | --- |
| iOS | **15.0+** | `Package.swift` 声明 `.iOS(.v15)`，低于此版本 SPM 无法解析 |
| Swift | 5.9+ | `swift-tools-version: 5.9` |
| Xcode | 15.4+ | 当前发布版本由 Xcode 26.6 / Swift 6.3.3 构建 |
| 架构 | **仅真机 arm64** | `QuickVO.xcframework` 只有 `ios-arm64` 一个切片 |

> **模拟器不可用。** xcframework 不包含 `ios-arm64-simulator` 切片，接入后只能在真机上编译运行与调试。这是发布产物的既定形态，不是配置问题。

**产物形态：** `QuickVO.xcframework` 是**静态库**（`MACH_O_TYPE: staticlib`），SDK 代码在链接期进入你的 App 二进制，不会以独立动态库形式出现在 `Frameworks/` 中。这一点会影响崩溃符号化，详见[崩溃符号化](#崩溃符号化)。

---

## 安装

### Swift Package Manager

在 Xcode 中 **File → Add Package Dependencies**，填入：

```
https://github.com/quickvo/QuickVO.git
```

或在自己的 `Package.swift` 中声明：

```swift
dependencies: [
    .package(url: "https://github.com/quickvo/QuickVO.git", from: "1.8.0")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "QuickVO", package: "QuickVO")
    ])
]
```

`QuickVO` 这个 product 包含两个 target：二进制 target `QuickVO`（即 xcframework），以及空壳 target `QuickVOKit`。后者存在的唯一原因是 SPM 的 `binaryTarget` 不能声明依赖 —— 所有第三方依赖挂在 `QuickVOKit` 上，由它连带引入。你只需要 `import QuickVO`。

### 传递依赖

添加 SDK 会自动解析下列依赖，无需手动添加：

| 依赖 | 版本约束 | 用途 |
| --- | --- | --- |
| [WebRTC-iOS](https://github.com/quickvo/WebRTC-iOS) | 0.0.1+ | WebRTC 核心（137.0.1） |
| [Starscream](https://github.com/daltoniam/Starscream) | 4.0.8+ | WebSocket 信令 |
| [swift-protobuf](https://github.com/apple/swift-protobuf) | 1.32.0+ | 信令 Protobuf 编解码 |
| [SwiftNATDetector](https://github.com/quickvo/SwiftNATDetector) | 0.0.1+ | NAT 类型探测 |
| [GzipSwift](https://github.com/1024jp/GzipSwift) | 6.0.0+ | 数据压缩 |
| [gpupixel-iOS](https://github.com/quickvo/gpupixel-iOS) | 1.2.4+ | 美颜 / 视频前处理 |
| [KSCrash](https://github.com/kstenerud/KSCrash) | 2.6.0+ | 崩溃捕获（`Recording` + `Filters`） |

`QVReplayKitExt`（屏幕共享帧共享内存契约）已静态链接进 xcframework，主 App 无需声明；**但屏幕共享扩展需要单独添加**，见[屏幕共享](#屏幕共享)。

> 如果你的 App 已经集成了 KSCrash，两份 KSCrash 会在链接期产生符号冲突，或在运行期争抢同一套信号处理器。接入前请先阅读[诊断与崩溃上报](#诊断与崩溃上报)。

---

## 工程配置

### Info.plist 权限声明

| 键 | 是否必须 | 原因 |
| --- | --- | --- |
| `NSCameraUsageDescription` | 使用视频时**必须** | SDK 通过 `AVCaptureSession` 采集摄像头 |
| `NSMicrophoneUsageDescription` | 使用音频时**必须** | SDK 使用 `AVAudioSession` 的 `.playAndRecord` 分类 |
| `NSBluetoothAlwaysUsageDescription` | 建议 | 音频路由启用了 `.allowBluetoothHFP` / `.allowBluetoothA2DP` |
| `NSLocalNetworkUsageDescription` | 建议 | WebRTC 本地候选收集在部分网络环境下会触发本地网络询问 |

### 后台模式

在 **Signing & Capabilities → Background Modes** 勾选：

- **Audio, AirPlay, and Picture in Picture** —— 通话切到后台后继续收发音频所必需。
- **Voice over IP** —— 如果你用 CallKit 接管来电界面。

摄像头在后台被系统禁止采集，这是 iOS 的行为，SDK 会在回到前台时自动恢复采集。

### 权限申请时机

**SDK 不会替你申请权限。** 首次访问硬件时系统会自行弹窗（摄像头在 `startCamera` 时，麦克风在音频会话激活时），也就是说不做任何处理的话，权限弹窗会出现在 `join` 过程中，用户还没看到通话界面就被打断。

建议在进入通话页之前自行申请。SDK 提供了一个麦克风检查工具，但它是诊断用途（会做一次录放测试），不是通用的权限申请入口：

```swift
// 诊断用：检查麦克风权限并做一次录放测试，失败抛 AudioError.permissionDenied
try await RoomAuidioTool().checkMicrophonePermission()
try await RoomAuidioTool().checkRecordAndPlay()
```

常规做法仍然是自己调用 `AVCaptureDevice.requestAccess(for: .video)` 与 `AVAudioApplication.requestRecordPermission()`。

---

## 快速开始

一次最小可用的音视频通话，五步。

```swift
import QuickVO

final class CallViewController: UIViewController {

    private var room: RTCRoom!
    private let remoteView = RoomVideoView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(remoteView)

        // 1. 创建引擎。进程级，整个 App 只需一次，通常放在 AppDelegate。
        RTCEngine.create("your_app_id",
                         socketURL: URL(string: "wss://your-signal-server/websocket")!)

        // 2. 创建房间并设置委托。按通话新建，通话结束即释放。
        room = RTCRoom(delegat: self)

        Task {
            // 3. 加入房间
            let option = RoomLocalOption(
                userId: "user_123",
                defaultStartCamera: true,
                subscribeType: .auto,
                publishType: .auto,
                scence: .communication
            )
            do {
                try await room.join(token, "room_456", option)
            } catch {
                print("加入失败：\(error)")
            }
        }
    }
}

// 4. 房间委托：只有这三个方法没有默认实现，必须写
extension CallViewController: RTCRoomDelegate {
    func didJoin(_ room: RTCRoom, _ participant: RTCParticipant) {
        participant.delegate = self          // 关键：不设委托就收不到轨道
    }
    func didLeave(_ room: RTCRoom, _ participant: RTCParticipant) { }
    func didClose(_ room: RTCRoom, _ code: Int?, _ desc: String?) { }
}

// 5. 参与者委托：拿到远端轨道并渲染
extension CallViewController: RTCParticipantDelegate {
    func addVideoTrack(_ participant: RTCParticipant, _ track: RoomVideoTrack) {
        track.render = remoteView
    }
}
```

退出：

```swift
await room.quit()
```

---

## 核心概念

```
┌─────────────────────────────────────────────────────────────────┐
│  RTCEngine（进程级单例）                                          │
│  · appId、信令地址、ICE 配置、网络监测、共享媒体管线                  │
│  · create() 一次，destroy() 一次                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │  join 时取一份地址快照，整场会话不变
              ┌─────────────┴─────────────┐
              ▼                           ▼
      ┌───────────────┐           ┌───────────────┐
      │   RTCRoom     │           │   RTCRoom     │   按通话新建
      │  （一通电话）   │           │  （下一通）    │
      └───────┬───────┘           └───────────────┘
              │
      ┌───────┴────────────────────────────┐
      ▼                                    ▼
┌──────────────────┐            ┌────────────────────────┐
│ localPartipant   │            │ partipant[userId]      │
│ LocalRTCParticipant           │ RTCParticipant（远端）   │
│ · 麦克风/摄像头    │            │ · videoTracks          │
│ · 音频路由        │            │ · audioTracks          │
│ · 本地预览        │            │ · delegate ← 必须设置   │
└──────────────────┘            └───────────┬────────────┘
                                            │ addVideoTrack
                                            ▼
                                 ┌────────────────────┐
                                 │   RoomVideoTrack   │
                                 │   .render = view   │
                                 └────────────────────┘
```

三条容易踩的规则：

1. **信令地址属于引擎，不属于房间。** 房间在 `join` 时取一份快照，整场会话不变。
2. **不给 `RTCParticipant` 设 `delegate` 就永远收不到轨道。** 远端轨道只从 `addVideoTrack` / `addAuidoTrack` 出来。
3. **`RTCRoom` 是短命对象**，一通电话一个；`RTCEngine` 是长命对象，一个进程一个。

---

## 引擎 RTCEngine

### 创建与销毁

```swift
public static func create(_ appId: String,
                          socketURL: URL? = nil,
                          iceURL: [String]? = nil,
                          logEnvironment: RTCLogEnvironment = .production)

public func configure(socketURL: URL? = nil, iceURL: [String]? = nil)

public static func destroy()
```

信令地址**没有内置默认值**。未配置就 `join` 会抛 `ConnectError.endpointNotConfigured`。

```swift
// 地址启动时已知
RTCEngine.create("your_app_id", socketURL: URL(string: "wss://...")!)

// 地址要从自己的服务器取，就先创建、后补上；configure 对之后所有房间生效
RTCEngine.create("your_app_id")
RTCEngine.engine.configure(socketURL: url)
```

`iceURL` 传入时**整体替换**内置 STUN 列表，不是追加。内置列表可读：`RTCEngine.defaultIceURL`。

`destroy()` 清空 appId、地址、ICE 配置，重置 `RTCRoomConfig`，停止网络监测。**它不会自动退出仍在进行的房间** —— 先 `await room.quit()`，再 `destroy()`。

### 其他公开成员

```swift
public static let engine: RTCEngine
public var appId: String { get }
public private(set) var socketURL: URL?
public private(set) var iceURL: [String]
public static let defaultIceURL: [String]
public private(set) var logEnvironment: RTCLogEnvironment   // .development | .production
public var uploadLog: Bool                                  // 默认 true，见「诊断与崩溃上报」
public var onLog: ((RTCLogEntry) -> Void)?                  // SDK 日志回调
public var netStatus: ((NetworkMotorStatus) -> Void)?
public var netType: ((NetworkMotorType) -> Void)?
```

`onLog` 在一条专用串行队列上异步回调，不在写日志的线程上，可以安全地在回调里做重活。

```swift
RTCEngine.engine.onLog = { entry in
    MyLogger.log(level: entry.level, message: entry.message)
}
```

`RTCLogLevel`：`.verbose` `.debug` `.info` `.critical` `.warning` `.error` `.fault`。

> `logEnvironment: .development` 会把 **SDK 自身**的诊断日志发到开发环境的接收端，仅用于 beta 包。它和 `onLog` 无关，也不改变你 App 的日志行为。

---

## 房间 RTCRoom

```swift
public init(delegat: RTCRoomDelegate? = nil)      // 参数名是 delegat，无 e

public weak var delegate: RTCRoomDelegate?
public var roomId: String { get }
public var partipant: [String: RTCParticipant] { get }        // userId → 参与者
public var localPartipant: LocalRTCParticipant { get }
public var total: Int { get }
public var whiteboardId: String { get }
public var whiteboardURL: String { get }
```

### 加入与退出

```swift
func join(_ token: String? = nil, _ roomId: String, _ option: RoomLocalOption) async throws
func join(_ roomId: String, _ option: RoomLocalOption) async throws
func quit(intent: QuitIntent = .terminal) async
func updateToken(_ roomId: String, _ token: String) async throws
```

`QuitIntent` 决定退出时是否释放系统媒体资源：

| 值 | 含义 | 用在哪 |
| --- | --- | --- |
| `.terminal` | 最后一个房间结束时释放摄像头与音频会话（默认） | 正常挂断 |
| `.handoff` | 保持采集管线热着 | 一通电话直接切到下一通，避免摄像头黑一下 |

### RoomLocalOption

加入房间的参数集合。注意初始化器的标签 **`scence`**（对应属性名是 `scene`）。

```swift
public init(
    userId: String,                                   // 必填，为空抛 ConnectError.noAuth
    userFontCamera: Bool = true,                      // 默认使用前置摄像头
    defaultStartCamera: Bool = true,                  // 加入即开启摄像头
    defaultAuioSpeakerOn: Bool = false,               // 加入即走扬声器
    subscribeType: StreamType = .auto,                // .auto | .manual
    publishType: StreamType = .auto,                  // .auto | .manual
    scence: RoomScene = .communication,               // 场景
    enalbleSimulcast: Bool = false,                   // 发布侧开启大小流
    serverSpeech: RoomSpeechOption = RoomSpeechOption(),
    prePublishAuthToken: String? = nil,               // 与下一项配对使用
    prePublishBaseURL: URL? = nil                     // 走 HTTP 预发布，加快首帧
)
```

`RoomScene`：`.communication`（1v1 通信）、`.meeting`（会议）、`.live`（直播）、`.conference`（会控）。

> `.live` 场景下，加入时的参与者列表会被过滤为仅发布者。

---

## 房间委托 RTCRoomDelegate

只有三个方法**没有**默认实现，必须实现；其余都在 `public extension` 里给了空实现，按需覆盖。

### 必须实现

```swift
func didJoin(_ room: RTCRoom, _ participant: RTCParticipant)
func didLeave(_ room: RTCRoom, _ participant: RTCParticipant)
func didClose(_ room: RTCRoom, _ code: Int?, _ desc: String?)
```

### 可选实现

| 回调 | 触发时机 |
| --- | --- |
| `roomError(_ error: Error)` | 非致命错误统一出口，如订阅失败、发布失败 |
| `tokenExpired()` / `tokenWillExpired()` | Token 过期 / 即将过期，后者应触发 `updateToken` |
| `roomStatus(_ status: RTCRoomConnect)` | 合并后的连接状态 |
| `roomDetailStatus(_ room:_ status:)` | 信令与媒体两路的分别状态 |
| `disConnectWithoutRoom(_ room: RTCRoom)` | 尚未入房就断开 |
| `didPublished(_ room:_ track:)` | 本地发布成功 |
| `receivePublished(_ room:_ sub:)` | 远端有新流可订阅（仅 `.manual` 订阅模式） |
| `didSubscribed(_ room:_ sub:)` | 订阅成功 |
| `audioSessionRouteChange(_ room:_ route:)` | 音频路由变化（插拔耳机、连蓝牙） |
| `audioSessionInterrupt(_ room:_ type:)` | 音频被打断（来电等） |
| `updateAudioLevel(_ room:_ participant:)` | 房间级音量刷新，需先配置采样间隔 |
| `liveDidSetPlaybackUrls(_ room:_ urls:)` | 直播 CDN 地址下发 |
| `roomForbidSetDidChange(_ room:_ current:_ latestActions:)` | 房间级禁用集合变化 |
| `roomAdminDidChange(_ room:_ admin:)` | 管理员列表变化 |
| `whiteboardStateChanged(_ room:_ whiteboardId:)` | 白板状态变化 |
| `didJoinBootTime(_:)` / `didQuitBootTime(_:)` | 入房 / 退房耗时埋点 |

### 连接状态

```swift
public enum RTCRoomConnect: Equatable {
    case none, disConnect, connecting, connected
}
```

`roomStatus` 是信令与媒体两路状态的合并结果：两路都 `.connected` 才报 `.connected`，两路都断才报 `.disConnect`，其余一律 `.connecting`。要看清楚是哪一路出问题，用 `roomDetailStatus`。

---

## 参与者与轨道

### RTCParticipant

```swift
public weak var delegate: RTCParticipantDelegate?         // 不设就收不到轨道
public weak var debugDelegate: RTCParticipantDebugDelegate?
public var id: String
public var audioTracks: [RoomAudioTrack]
public var videoTracks: [RoomVideoTrack]
public internal(set) var audiollevel: Float               // 0...1
public var isSpeaking: Bool                               // audiollevel > 0.02
public var audioEnable / videoEnable / screenEnable: Bool
public var netMonitor: NetMonitorValue
public var volume: Double?                                // 远端播放音量 0...10，默认 5
public var joinTime: Int64
public var publishAuth / subscribeAuth: Bool
public var audioForbid / videoForbid / screenForbid: Bool // 设置即下发服务端指令
public func getTrack(type: RoomTrackType) -> RoomTrack?
public func getTrackType() -> [RoomTrackType]
```

遍历房间成员用 `room.partipant`（字典，key 是 userId，本端也在其中）。

### RTCParticipantDelegate

只有 `addVideoTrack` 必须实现。

```swift
func addVideoTrack(_ participant: RTCParticipant, _ track: RoomVideoTrack)     // 必须
func addAuidoTrack(_ participant: RTCParticipant, _ track: RoomAudioTrack)     // 可选
func action(_ participant: RTCParticipant, _ action: RTCParticipantAtion)
func speaking(_ participant: RTCParticipant, _ speaking: Bool)
func network(_ participant: RTCParticipant, _ net: NetMonitorValue)
func forbid(_ participant: RTCParticipant, _ action: PaticipantForbidAction)
func speechString(_ participant: RTCParticipant, _ string: RoomSpeechData)
func permissionsChanged(_ participant: RTCParticipant)
```

远端音频由 SDK 内部播放，**不需要**你处理 `addAuidoTrack` 才能听到声音。这个回调用于拿到轨道句柄做音量控制或 PCM 取样。

`action` 回调携带对方开关麦克风、摄像头、屏幕共享的状态变化：

```swift
public enum RTCParticipantAtion {
    case audioEnable(Bool)
    case videoEnable(Bool)
    case screenShare(Bool)
}
```

### 轨道类型

```swift
public enum RoomTrackType: CaseIterable, Hashable, Sendable {
    case audio, camera, screen, sysAudio
}

public class RoomVideoTrack: RoomTrack {
    public var trackId: String
    public var isEnabled: Bool
    public var render: RoomVideoView?                     // 赋值即挂载
    public static func applyRenders(_ bindings: [(track: RoomVideoTrack?, view: RoomVideoView?)])
}

public class RoomAudioTrack: RoomTrack {
    public var trackId: String
    public var isEnabled: Bool
    public var volume: Double                             // 0...10，默认 5
    public var renderBuffer: ((AVAudioPCMBuffer) -> Void)?  // 取 PCM 做波形可视化
}
```

---

## 视频渲染

SDK 只提供 UIKit / AppKit 视图，**不含 SwiftUI 封装**，在 SwiftUI 中使用需要自行套一层 `UIViewRepresentable`。

### 挂载与切换

```swift
// 单个挂载
track.render = roomVideoView

// 多个视图原子交换（画中画、大小窗互换）
RoomVideoTrack.applyRenders([
    (track: bigTrack,   view: bigView),
    (track: smallTrack, view: smallView)
])
```

重复给 `render` 赋同一个值是安全的，不会产生 remove + add 抖动 —— SwiftUI 的 body 反复重算场景下这一点很重要。挂载与摘除都在 `RoomVideoTrack` 内部的一条串行队列上完成，账本按「视图 + 底层轨 + 持有者」三元组记，陈旧的包装对象析构时不会误摘别人刚挂上的视图。

### RoomVideoView

```swift
open class RoomVideoView: RTCView {
    public enum VideoRenderMode { case MTL, sampleBuffer }
    public weak var delegate: RoomVideoDelegate?
    public var onFrameResumed: (() -> Void)?
    public var mirror: RTCVideoMirror              // .none | .mirror | .auto
    public var videoContentMode: UIView.ContentMode
    public var renderMode: VideoRenderMode
    public func rearmFirstFrame()
    public func render(_ frame: RTCVideoFrame)
}

public protocol RoomVideoDelegate: AnyObject {
    func videoView(didChangeVideoSize: RoomVideoView, size: CGSize)   // 分辨率变化，用于调整布局
    func renderFisrtFrame(view: RoomVideoView)                        // 首帧到达
}
```

### 本地预览

入房前后都可以：

```swift
await room.localPartipant.startPreview(roomVideoView)
```

如果需要在进入房间之前就做独立预览（比如「美颜调试页」），用 `LocalPreviewView`，它自带采集，不依赖房间：

```swift
public final class LocalPreviewView: UIView {
    public weak var delegate: LocalPreviewViewDelegate?
    func start()
    func stop()
    func switchCamera()
}
```

---

## 本地音视频控制

统一通过 `room.localPartipant`。

### 麦克风与摄像头

```swift
room.localPartipant.enableMicrophone(true)
room.localPartipant.microphoneIsEnable()            // -> Bool

room.localPartipant.enableCamera(true)
room.localPartipant.cameraIsEnable()                // -> Bool
room.localPartipant.switchCamera()                  // 不传参即前后互换
room.localPartipant.switchCamera(.back)             // RTCCameraPosion: .font | .back
room.localPartipant.camerPosion()                   // -> RTCCameraPosion
```

### 音频路由

音频路由相关 API 全部是 `async`。

```swift
// 简化用法
await room.localPartipant.enableSpeaker(true)       // 扬声器 / 听筒
await room.localPartipant.switchSpeaker()
await room.localPartipant.speakerIsEnable()         // -> Bool

// 完整用法：枚举可用输出并显式选择
let routes = await room.localPartipant.availableAudioRoutes    // [RTCAudioOutput]
let result = await room.localPartipant.setAudioRoute(.speaker) // Result<RTCAudioOutput, RTCAudioRouteError>
let current = await room.localPartipant.currentAudioRoute
```

```swift
public enum RTCAudioRoute: Sendable, Hashable {
    case speaker, receiver, bluetooth, headphones, carAudio, usb, airPlay
}

public enum RTCAudioRouteError {
    case routeUnavailable(RTCAudioRoute)
    case sessionFailed(Error)
    case settledElsewhere(RTCAudioOutput)      // 期间系统或用户切到了别处
}
```

路由的实际变化通过 `RTCRoomDelegate.audioSessionRouteChange` 通知 —— 用户插拔耳机、连断蓝牙都会走这里，不要只依赖自己调用 `setAudioRoute` 的返回值来维护 UI 状态。

### 多任务摄像头（iOS 16+ 分屏 / 台前调度）

```swift
room.localPartipant.isMultitaskingCameraAccessSupported   // -> Bool
room.localPartipant.isMultitaskingCameraAccessEnabled = true
```

---

## 采集配置

全局单例 `RTCRoomConfig.config`，`RTCEngine.destroy()` 时重置为默认值。

```swift
public final class RTCRoomConfig {
    public static let config: RTCRoomConfig
    public var video: RoomVideoCaptureConfig
    public var audio: RoomAudioCaptureConfig
    public var reconnectPolicy: RTCReconnectPolicy
    public var rtcStatsDataChannelPreferenceSeconds: TimeInterval    // 默认 1.0
}
```

### 视频采集

| 字段 | 类型 | 默认值 | 通话中可改 |
| --- | --- | --- | --- |
| `width` / `height` | `Int` | 1280 / 720 | 可以，会重启摄像头 |
| `fps` | `Int` | 30 | 可以，会重启摄像头 |
| `mirror` | `Bool` | `false` | 可以 |
| `degradation` | `RoomVideodegradation` | `.framerate` | 可以 |
| `filter` | `Bool` | `true` | 可以，见[美颜](#美颜与自定义视频处理) |
| `crop` | `RoomVideoCropping` | 居中不裁剪 | 可以 |

```swift
public enum RoomVideodegradation: Int, CaseIterable {
    case disabled       // 不降级
    case framerate      // 优先降帧率（默认）
    case resolution     // 优先降分辨率
    case balanced       // 两者平衡
}

public struct RoomVideoCropping {
    public var aspectRatio: Float?      // nil = 不裁剪
    public var cropXRatio: Float        // 0...1，默认 0.5（居中）
    public var cropYRatio: Float        // 0...1，默认 0.5
}
```

修改分辨率或帧率会**重启摄像头**，这是预期行为，画面会短暂中断。

### 音频采集

| 字段 | 默认值 |
| --- | --- |
| `echoCancellation` | `true` |
| `noiseSuppression` | `true` |
| `autoGainControl` | `false` |
| `audioLevelMonitor` | `nil`（不启用房间级音量回调） |

**音频三项约束在音频轨创建时绑定**，也就是首次发布音频的那一刻。通话中改动不会生效，除非音频轨被重建。要生效就在第一次 `join` 之前设置。

### 房间级音量回调

`updateAudioLevel` 默认不触发，需要先设置采样间隔：

```swift
RTCRoomConfig.config.audio.audioLevelMonitor = 2    // 每 2 个统计周期回调一次
```

底层统计周期是 500 ms，所以设为 `N` 时大致每 `N × 500 ms` 回调一次，且只包含正在说话的参与者。

---

## 发布与订阅

`subscribeType` 与 `publishType` 在 `RoomLocalOption` 里各自独立，都是 `.auto` 或 `.manual`。

### 自动模式（默认）

```
join ──▶ SDK 自动发布本地音视频 ──▶ didPublished
     └─▶ SDK 自动订阅房间内已有流 ──▶ didSubscribed ──▶ addVideoTrack
```

远端后续发布新流时也会自动订阅，`receivePublished` **不会**触发。

### 手动模式

```
join ──▶（不自动发布）
     │     你调用 publishStream() ──▶ didPublished
     │
     └─▶ 远端发布 ──▶ receivePublished(sub) ──▶ 你调用 subscribe(sub)
                                              ──▶ didSubscribed ──▶ addVideoTrack
```

```swift
public func publishStream() async throws
public func subscribe(_ userData: [RoomUserSubData]) async throws
public func unSubscribe(_ userData: [RoomUserSubData]) async throws
```

```swift
public struct RoomUserSubData {
    public var id: String
    public var track: [RoomTrackType]
    public var simucast: SimulcastType?       // 拼写是 simucast
    public init(id: String = "", track: [RoomTrackType] = [], simucast: SimulcastType? = nil)
}
```

典型手动订阅：

```swift
func receivePublished(_ room: RTCRoom, _ sub: [RoomUserSubData]) {
    Task {
        // 只订阅音频，省流量
        let audioOnly = sub.map { RoomUserSubData(id: $0.id, track: [.audio]) }
        try? await room.subscribe(audioOnly)
    }
}
```

> 手动模式下有一个例外：如果 SDK 已经记录了对某用户某轨道的订阅意图（比如你之前订阅过、对方重新发布），它会直接续订而不再走 `receivePublished`。

订阅失败不会让 `subscribe` 抛错，而是通过 `roomError` 送出 `ConnectError.subscribeStreamFailure` 或 `trackNotPublished`。

---

## Simulcast 大小流

### 发布侧

```swift
RoomLocalOption(userId: "...", enalbleSimulcast: true)
```

开启后摄像头轨道以三层编码发布，缩放系数 4 / 2 / 1。**屏幕共享轨道不参与 Simulcast。**

### 订阅侧切层

```swift
public enum SimulcastType: Sendable { case high, medium, low }

// 初次订阅就指定层
try await room.subscribe([RoomUserSubData(id: "user_a", track: [.camera], simucast: .low)])

// 已订阅后切层，不重新协商
try await room.simulcast([RoomUserSubData(id: "user_a", track: [.camera], simucast: .high)])

// 排查用：打印当前 mid 与层信息
let info = room.simulcastDiag([RoomUserSubData(id: "user_a", track: [.camera])])
```

不指定时默认取 `.high`。

`simulcast(_:)` 要求轨道**已经订阅成功**（内部需要 mid）。在 1v1 P2P 会话中或订阅尚未落地时调用会抛 `ConnectError.simulcastNoSFUTrack`。

---

## 屏幕共享

屏幕共享走系统的 ReplayKit Broadcast Upload Extension，帧通过 App Group 共享内存传给主 App。接入涉及**两个 target 的改动**。

```
┌────────────────────┐   Darwin 通知 reply.start/stop/end/receive  ┌──────────────────────┐
│  主 App            │◀───────────────────────────────────────────▶│ Broadcast Extension  │
│  QuickVO SDK       │                                             │  QVReplayKit         │
│                    │   共享内存环 qv_screen_frame_ring.v1.bin      │  SampleHandler       │
│  轮询帧 → 发布      │◀────────────────────────────────────────────│  写帧                 │
└────────────────────┘         App Group 容器                       └──────────────────────┘
```

### 第一步：配置 App Group

在**主 App** 和**扩展**两个 target 的 Signing & Capabilities 里都添加 **App Groups**，使用**同一个**标识符，例如 `group.com.your.app`。

主 App 侧配错会在调用时立刻抛 `ConnectError.screenShareGroupUnavailable`。扩展侧配错则不会有任何报错 —— Darwin 通知不依赖 App Group 照常握手成功，但帧传不过来，表现为**对端一直黑屏**。这是最常见的接入故障。

### 第二步：创建扩展 target

**File → New → Target → Broadcast Upload Extension**。扩展的 Bundle ID 必须以主 App 的 Bundle ID 为前缀。

给扩展 target 单独添加依赖（**扩展不能链接 `QuickVO`**，WebRTC 的体积会超出扩展内存与体积限制）：

```
https://github.com/quickvo/QVReplayKitExt.git
```

选择 product **`QVReplayKit`**。

### 第三步：实现 SampleHandler

```swift
import ReplayKit
import QVReplayKit

class SampleHandler: RPBroadcastSampleHandler, ReplaykitExtDelegate {

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        ReplaykitExt.instance.setup("group.com.your.app", self)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        ReplaykitExt.instance.processSampleBuffer(sampleBuffer, with: sampleBufferType)
    }

    override func broadcastFinished() {
        ReplaykitExt.instance.broadcastFinished()
    }

    // 主 App 要求结束时回调到这里
    func broadcastEnd(_ error: Error) {
        finishBroadcastWithError(error)
    }
}
```

### 第四步：主 App 发起

```swift
try await room.startScreenShare("group.com.your.app")
```

这一步只做准备工作：校验 App Group 可达、注册 Darwin 观察者、建立帧接收管线。**它不会拉起系统录屏。** 还需要你自己弹出系统选择器：

```swift
let picker = RPSystemBroadcastPickerView(frame: .init(x: 0, y: 0, width: 60, height: 60))
picker.preferredExtension = "com.your.app.broadcast"   // 扩展的 Bundle ID
picker.showsMicrophoneButton = false
view.addSubview(picker)
```

### 停止

**没有公开的 `stopScreenShare`。** 停止由以下任一途径发生：

- 用户在系统 UI 里停止录屏（扩展发出 `reply.stop`）
- `await room.quit()`
- 服务端下发禁止屏幕共享

### 错误

| 错误 | 原因 |
| --- | --- |
| `startScreenShareWithoutGroupId` | 传了空字符串 |
| `screenShareGroupUnavailable(String)` | App Group 容器不可达，主 App 侧未正确配置 |
| `screenForbid` | 服务端禁止了屏幕共享 |
| `noAuth` | 尚未入房 |

重复调用 `startScreenShare` 不会抛错，直接静默返回。

### 扩展内的日志（可选）

扩展进程崩溃或异常时默认只有控制台日志，不进诊断报告。要把扩展日志纳入主 App 的诊断报告，需要把 SDK 的诊断源码编进扩展 target，并在 `broadcastStarted` 里调用：

```swift
QVExtensionLogging.start(appGroup: "group.com.your.app")
```

扩展侧的日志段容量是 256 KB、最多保留 3 段，主 App 在录屏结束时把封存的段搬回自己的容器。**扩展内不安装崩溃捕获** —— 那会变成两个处理器争抢同一个 App Group 容器。

这一步是可选的，跳过不影响屏幕共享功能本身。具体要编入哪些源文件请向 SDK 团队索取清单。

---

## 房间管控

### 房间级禁用

```swift
public enum PaticipantForbidAction {
    case audioForbid(Bool)
    case videoForbid(Bool)
    case screenForbid(Bool)
}

try await room.forbidWith([.audioForbid(true), .screenForbid(true)])
```

> `forbidWith` 把同一组动作**下发给房间内所有参与者**，不是只对某一个人。

### 单人禁用

对某个参与者操作，直接设置属性。这些 setter 是**服务端指令**，不是本地静音：

```swift
participant.audioForbid = true
participant.videoForbid = true
participant.screenForbid = true
```

服务端确认后通过 `RTCParticipantDelegate.forbid(_:_:)` 回来。被禁的如果是本端，SDK 会自动停止对应的本地采集。

### 状态回调

```swift
func roomForbidSetDidChange(_ room: RTCRoom,
                            _ current: Set<RoomForbid>,           // .audio | .video | .screen
                            _ latestActions: [RoomForbidLatestAction])
func roomAdminDidChange(_ room: RTCRoom, _ admin: [String])       // 管理员 userId 列表
```

```swift
public struct RoomForbidLatestAction: Sendable {
    public let action: RoomForbid
    public let forbid: Bool
}
```

房间级禁用生效时，**不在管理员列表里的用户**会被 SDK 自动停止对应的本地采集。

**管理员的增删没有客户端 API**，列表完全由服务端下发。

---

## 语音识别与翻译

识别开关和语言设置是**两个独立的 API**。

```swift
// 开 / 关本端语音识别
try await room.setLocalSpeechRecognition(true)

// 设置语言与翻译目标
try await room.updateSpeech(RoomSpeechOption(
    lang: RoomSpeechLanguage.zh.rawValue,
    targetLang: RoomSpeechLanguage.en.rawValue,
    translate: true
))
```

> `RoomSpeechOption.open` 已废弃且**被忽略**。它保留只是为了让旧代码继续编译。识别开关只能通过 `setLocalSpeechRecognition(_:)` 改 —— 因为很多调用方习惯用硬编码的 `open: true` 构造这个结构体，如果转发这个字段，一次单纯的语言切换就会顺带把识别打开。

### 支持的语言

`RoomSpeechLanguage`（20 种，`rawValue` 即语言代码）：

`zh` 中文 · `en` 英语 · `yue` 粤语 · `ja` 日语 · `ko` 韩语 · `fr` 法语 · `de` 德语 · `es` 西班牙语 · `it` 意大利语 · `ru` 俄语 · `pt` 葡萄牙语 · `hi` 印地语 · `ar` 阿拉伯语 · `th` 泰语 · `vi` 越南语 · `nl` 荷兰语 · `sv` 瑞典语 · `fi` 芬兰语 · `pl` 波兰语 · `tr` 土耳其语

`RoomSpeechLanguage.displayName` 给出本地化名称，`RoomSpeechLanguages.all` 给出完整列表，可直接用于语言选择 UI。

### 接收结果

```swift
func speechString(_ participant: RTCParticipant, _ string: RoomSpeechData)

public struct RoomSpeechData {
    public var string: String       // 识别原文
    public var time: Int64
    public var translate: String?   // 译文，未开启翻译时为 nil
}
```

---

## 白板

SDK 负责白板房间的生命周期与状态同步，**白板的绘制界面由你自己实现**（通常是一个 `WKWebView`）。

```swift
try await room.createWhiteboard(whiteboardId)
try await room.joinWhiteboard(whiteboardId)
try await room.quitWhiteboard(whiteboardId)
try await room.destroyWhiteboard(whiteboardId)

room.whiteboardId       // 当前白板 id，空字符串表示未加入
room.whiteboardURL      // 白板服务根地址，从信令地址推导，整场会话不变
```

```swift
func whiteboardStateChanged(_ room: RTCRoom, _ whiteboardId: String)
```

收到回调后读取 `room.whiteboardId` 与 `room.whiteboardURL`，据此加载或卸载你的白板界面。`whiteboardURL` 为空字符串表示未入房、会话已结束，或地址推导失败。

---

## 直播 CDN

`scence: .live` 的房间，服务端会下发 CDN 播放地址：

```swift
func liveDidSetPlaybackUrls(_ room: RTCRoom, _ urls: RoomLivePlaybackUrls)

public struct RoomLivePlaybackUrls: Sendable {
    public var urls: [RoomLiveUrlData]

    public struct RoomLiveUrlData: Sendable { /* location / billing / urls */ }

    public enum RoomLiveLocation: Int, CaseIterable, Sendable {
        case chinaMainland, global, overseas
    }
    public enum RoomLiveBilling: Int, CaseIterable, Sendable {
        case flow, time
    }
}
```

地址集合按区域（国内 / 全球 / 海外）与计费方式（流量 / 时长）分组，每组内含 flv、m3u8、rtmp、rtmps 等多种协议地址。

> **当前限制：这个功能目前对接入方不可用。** `RoomLiveUrlData` 的三个字段（`location`、`billing`、`urls`）都没有标记 `public`，在发布出去的 `.swiftinterface` 里它是一个**空结构体**：
>
> ```swift
> public struct RoomLiveUrlData : Swift.Sendable {
> }
> ```
>
> 也就是说 `liveDidSetPlaybackUrls` 会正常回调，你也能拿到数组和它的长度，但数组里每一项都读不出任何内容。需要直播播放地址的话请联系 SDK 团队，此项待修复。

---

## 网络与质量监控

### 参与者维度

```swift
func network(_ participant: RTCParticipant, _ net: NetMonitorValue)
```

`up`、`donw`、延迟或 RTT 发生变化时触发。也可以随时读 `participant.netMonitor`。

```swift
public struct NetMonitorValue {
    public var up: RTCStatisLevel          // 上行质量
    public var donw: RTCStatisLevel        // 下行质量（拼写为 donw）
    public var netUp: Float?               // 上行码率
    public var netDown: Float?
    public var lost: Double                // 上行丢包率
    public var downlost: Double            // 下行丢包率
    public var RoundTripTime: Float?
    public var uplinkDelayMs: Float?
    public var downlinkDelayMs: Float?
    public var frameHeight: Int?
    public var frameWith: Int?             // 拼写为 frameWith
    public var fps: Int?
    public var bitrate: Double?
    public var codecA: String?             // 音频编码
    public var codecV: String?             // 视频编码
    public var mid: String?
}

public enum RTCStatisLevel: Int {
    case none, veryBad, bad, generally, good, veryGood
}
```

底层统计周期 500 ms。

### 说话状态与音量

```swift
participant.audiollevel      // Float，0...1
participant.isSpeaking       // audiollevel > 0.02
participant.volume           // 远端播放音量 0...10，默认 5，可写
```

`speaking(_:_:)` 在说话状态翻转时回调。房间级的 `updateAudioLevel` 需要先设置 `RTCRoomConfig.config.audio.audioLevelMonitor`，见[采集配置](#采集配置)。

### 设备网络

```swift
RTCEngine.engine.netStatus = { status in }   // .reachable | .unReachable
RTCEngine.engine.netType   = { type in }     // .wifi | .cellular | .other
```

也提供 Combine 形式的 `statusSubject` / `typeSubject`。

---

## P2P

P2P 由**服务端下发指令驱动**，客户端不主动发起。服务端判定两端适合直连时下发 `P2PAvailablePeer`，SDK 建立直连并把该路流从 SFU 切走；连接失败或服务端下发断开时自动回落 SFU。

服务端可以设置「仅 WiFi 使用 P2P」，此时切到蜂窝网络会关闭所有 P2P 连接。

### 强制回落 SFU

```swift
try await room.unsubscribeP2P("user_a")
```

断开与该用户的 P2P 摄像头连接，改从 SFU 拉流。

### 统计与调试

```swift
participant.p2pConnectType     // PeerConnectionType: .none | .p2p_ing | .p2p
participant.cameraP2P          // 摄像头是否走 P2P
participant.sceenP2P           // 屏幕共享是否走 P2P（拼写为 sceen）
participant.getP2PRStatis()    // [NetMonitorValue] 接收侧
participant.getP2PSStatis()    // [NetMonitorValue] 发送侧
participant.dcRemoteStats      // [String: DCRemoteStats] 对端上报的质量分
participant.candidateProtocol  // 本地 ICE 候选协议
```

```swift
public protocol RTCParticipantDebugDelegate: AnyObject {
    func p2pChange(_ participant: RTCParticipant)   // P2P 连接状态变化
    func debugInfo(_ participant: RTCParticipant)   // 统计刷新，约每 500 ms
}
```

`debugInfo` 只在设置了 `debugDelegate` 时才计算并回调。它频率高、开销不小，**只在调试面板打开时设置，用完置 nil**。

---

## 美颜与自定义视频处理

三种模式，按需选一种。

### 一、使用内置美颜（默认）

`RTCRoomConfig.config.video.filter` 默认为 `true`，SDK 内部走 gpupixel 管线。gpupixel 本身没有对外暴露参数接口，具体的美颜强度调节请联系 SDK 团队。

### 二、完全关闭

```swift
RTCRoomConfig.config.video.filter = false
```

采集帧直通，不经 GL 处理，功耗最低。

### 三、接管处理

实现 `RoomVideoCaptureDelegate` 并挂到本地参与者上：

```swift
room.localPartipant.videoCaptureDelegate = self

public protocol RoomVideoCaptureDelegate: AnyObject {
    func processMode() -> RoomVideoRrocessMode
    func getCaputureBuffer(buffer: CVPixelBuffer, rotation: RoomVideoRotation)
    func setCaputureBuffer() -> (buffer: CVPixelBuffer, rotation: RoomVideoRotation)?
}

public enum RoomVideoRrocessMode {
    case readOnly     // 只观察，SDK 仍然执行内置处理
    case readWrite    // 你返回处理后的帧，SDK 跳过内置处理
}
```

`.readOnly` 下 SDK 调 `getCaputureBuffer` 把原始帧给你看一眼，然后照常走内置管线。`.readWrite` 下 SDK 调 `setCaputureBuffer` 取你的帧，返回非 `nil` 就完全跳过内置处理。

入房前的独立预览用 `LocalPreviewViewDelegate.getCaputureBuffer(buffer:rotation:)`，那是另一条通路。

---

## 断线重连

SDK 内置统一重连状态机，**重连期间不需要你做任何事** —— 不需要重新订阅，不需要重新挂载渲染视图。重建连接后 SDK 会自行重新发布、重新订阅，并在 P2P 轨道重新附着时再次回调 `addVideoTrack`。

重连过程通过状态回调体现：

```
媒体断开 ──▶ roomDetailStatus(server: .connected, rtc: .disConnect)
         ──▶ roomStatus(.connecting)
     恢复 ──▶ roomStatus(.connected)
   彻底失败 ──▶ didClose(...)
```

### 调优

`RTCReconnectPolicy` 在 `join` 时被快照，**必须在 `join` 之前设置**，通话中改动不生效。

```swift
RTCRoomConfig.config.reconnectPolicy.gracePeriodSeconds = 5
```

| 参数 | 默认 | 单位 | 含义 |
| --- | --- | --- | --- |
| `gracePeriodSeconds` | 3.0 | 秒 | 断开后先静默等待，避免抖动误判 |
| `quickRecoverTimeoutSeconds` | 5.0 | 秒 | 快速恢复尝试的超时 |
| `rebuildTimeoutSeconds` | 5.0 | 秒 | 单次重建的超时 |
| `relayTimeoutSeconds` | 40.0 | 秒 | 中继链路超时 |
| `maxRebuildAttempts` | 1 | 次 | 重建次数上限 |
| `rebuildDeadlineSeconds` | 40.0 | 秒 | 重建总期限 |
| `socketReadyTimeoutSeconds` | 5.0 | 秒 | 信令就绪超时 |
| `socketConnectTimeoutSeconds` | 10.0 | 秒 | 信令连接超时 |
| `socketPongTimeoutMisses` | 3 | 次 | 心跳连续丢失多少次判定断开（约 30 秒） |
| `socketReconnectBackoffSeconds` | `[0, 1, 2, 4, 8]` | 秒 | 信令重连退避序列 |
| `socketReconnectTimeoutSeconds` | 41.0 | 秒 | 信令重连总超时 |
| `subscribeRetryMaxAttempts` | 3 | 次 | 订阅重试次数 |
| `subscribeRetryBackoffSeconds` | `[1, 2, 4]` | 秒 | 订阅重试退避 |
| `episodeMaxSeconds` | 40.0 | 秒 | 单次重连事件总时长上限 |
| `relayFirstOnNetworkChange` | `false` | — | 网络切换时是否优先直接走中继 |

`suspensionGapSeconds` 已废弃且被忽略。

---

## 诊断与崩溃上报

SDK 内置日志落盘、崩溃捕获与上报通道。**这一节涉及数据出境，接入前请完整阅读。**

### 默认行为

| 子系统 | 默认 | 说明 |
| --- | --- | --- |
| 日志落盘 | **默认开启** | 首次写日志时自动启动，无需调用任何 API |
| 崩溃捕获 | **默认关闭**，需显式 opt-in | 会替换进程级信号与异常处理器 |
| 报告上传 | **默认开启** | `RTCEngine.create` 时会投递积压报告 |
| 常规日志段上传 | **默认关闭** | 只有出错 / 崩溃的段才上传 |

也就是说：**不做任何配置的情况下，SDK 会在出现错误或崩溃时把日志段上传到 QuickVO 的服务器。** 关闭方式：

```swift
RTCEngine.engine.uploadLog = false
```

### 启用崩溃捕获

```swift
QVDiagnostics.install()              // 使用 .default
QVDiagnostics.install(.all)          // 额外包含僵尸对象检测
QVDiagnostics.install([.crashes, .metrics])
```

尽早调用，通常在 `application(_:didFinishLaunchingWithOptions:)`。返回 `Bool` 表示是否安装成功；重复调用会被忽略（KSCrash 不支持不重启就重新配置）。

```swift
public struct QVDiagnosticsOptions: OptionSet, Sendable {
    public static let crashes: QVDiagnosticsOptions       // 信号 / Mach 异常 / OC / C++ 异常
    public static let termination: QVDiagnosticsOptions   // 无崩溃报告的终止：内存杀、过热、强杀
    public static let watchdog: QVDiagnosticsOptions      // 主线程卡死，唯一会常驻线程的选项
    public static let metrics: QVDiagnosticsOptions       // 设备与系统状态
    public static let zombies: QVDiagnosticsOptions       // 僵尸对象，会 swizzle dealloc

    public static let `default`: QVDiagnosticsOptions     // crashes + termination + watchdog + metrics
    public static let all: QVDiagnosticsOptions           // default + zombies
}

QVDiagnostics.isInstalled            // 只读
```

> **崩溃捕获是显式 opt-in 而日志不是**，原因是崩溃捕获要替换进程级的信号与异常处理器 —— 一个 SDK 不该在宿主没要求的情况下悄悄拿走这些。

### 与其他崩溃收集器共存

**如果你的 App 已经集成 Firebase Crashlytics、Sentry、Bugsnag 等，不要调用 `QVDiagnostics.install()`。** 两套崩溃收集器会争抢同一组信号与 Mach 异常处理器，谁后安装谁生效，先安装的那套会丢报告，具体表现取决于安装顺序，不可靠。

不启用崩溃捕获，日志落盘与终止原因分类**照常工作** —— 它们靠的是崩溃前写下的状态和下次启动时的推断，不依赖信号处理器。

### 自定义上报通道

默认上报到 QuickVO 的接收端（`logEnvironment` 决定是开发环境还是生产环境）。要改投自己的服务，实现 `QVReportUploader`：

```swift
public protocol QVReportUploader: AnyObject {
    func upload(_ request: QVUploadRequest, completion: @escaping (QVUploadOutcome) -> Void)
}

public struct QVUploadRequest {
    public let artifactID: String
    public let kind: QVReportKind
    public let artifactURL: URL              // 已压缩的报告文件，请流式读取
    public let attributes: [String: String]
}

public enum QVUploadOutcome {
    case delivered              // 成功，本地删除
    case retriable(String)      // 可重试，按退避排队
    case permanent(String)      // 永久失败，不再重试
}

QVDiagnostics.setReportUploader(myUploader)   // 传 nil 恢复默认
```

**只有投递是可注入的，调度不可注入** —— 队列、退避、保留策略与配额留在 SDK 内，因为磁盘是 SDK 在占。

`artifactURL` 指向的文件可能有几 MB，请流式上传，不要整体读进内存。

### 手动触发报告

```swift
// 封存当前日志段并排队，不强制立即联网
QVDiagnostics.captureReport(note: "user reported audio issue")

// 立即上传全部积压，忽略退避与 uploadLog 开关，带进度
QVDiagnostics.uploadReportsNow(note: "user feedback") { progress in
    // 主队列回调
} completion: { result in
    // 主队列回调
    // result.delivered / .failed / .deferred / .alreadyInFlight
}

// 按 SDK 自己的节奏投递
QVDiagnostics.deliverPendingReports()

// 让没有错误的常规日志段也上传（默认关闭）
QVDiagnostics.setUploadsRoutineSegments(true)
```

> 不要把 `captureReport` 接到每通电话结束的地方。一台设备一天打十通电话就产生十份报告，而正常情况下大约每 9 MB 日志才产生一份。它应该挂在「用户反馈」这类明确的用户动作上。

### 磁盘占用

| 项目 | 主 App | 屏幕共享扩展 |
| --- | --- | --- |
| 存储位置 | `Library/QVDiagnostics/` | `<App Group 容器>/QVDiagnostics/` |
| 单段容量 | 10 MB（其中 1 MB 预留给崩溃现场） | 256 KB |
| 软配额 | 64 MB，超出开始淘汰 | 最多 3 段 |
| 硬上限 | 96 MB，达到即暂停写入 | — |
| 常规报告保留 | 14 天 | — |

存储刻意不放在 `Caches/` 下，因为 iOS 会在磁盘紧张时清空 Caches，而那正是最需要日志的时候。

**一个例外：崩溃、卡死、OOM 三类报告不计入 64 / 96 MB 配额，且投递成功前不会删除。** 也就是说如果设备长期无法上传（例如你关掉了 `uploadLog` 又没实现自定义通道），这部分占用没有上界。

### 隐私与合规

上传内容包含：

- **压缩后的日志段** —— SDK 日志行（时间、级别、源文件与行号、消息）、会话 UUID、设备型号、App 版本与构建号、系统版本、主二进制 UUID、内存与热状态采样，以及崩溃现场（堆栈、线程状态、二进制镜像列表）
- **HTTP 查询参数** —— `app_id`、`user_id`（房间用户 ID）、`ins_id`（报告 ID）、`type`、`desc`（不超过 200 字符的摘要）、`origin=ios`

日志行内的用户标识、Token、密码、Cookie、签名、API Key 等敏感字段在写入时就已做脱敏（哈希指纹而非明文）。但**上传的查询参数里 `user_id` 是完整值**。

填写 App Store 隐私清单时，至少需要披露：设备标识符（硬件型号）、App 与系统版本、诊断日志、崩溃数据，以及数据被发送至 QuickVO 服务器（若注入了自定义通道则是你自己的服务器）。

---

## 崩溃符号化

**SDK 帧的符号化依赖你自己 App 的 dSYM，请务必留存每一个发布版本的 dSYM。**

`QuickVO.xcframework` 是静态库，产物是一个 `ar` 归档。静态归档不经过链接，因此它既没有 `LC_UUID`，也不会生成 dSYM ——`dwarfdump --uuid` 对它返回空。SDK 代码是被链接进**你的 App 二进制**的，所以运行时标识这段代码的 UUID 是你 App 的 UUID，能够解析它的也只有你 App 的 dSYM。

`build-manifest.json` 里没有 UUID 字段，原因就是不存在可填的 UUID。它用版本号加 commit 标识构建，供你把一份崩溃报告对上当时链接的是哪个 SDK 版本。

两点需要预期：

- **SDK 帧只能还原到函数名，没有文件与行号。** 静态库出厂前已被 strip，不携带 DWARF，所以你的 dSYM 里没有 SDK 的行号信息。这是设计结果而非符号化失败，符号化工具不应把它报成错误。
- **你自己代码的帧照常有文件与行号**，因为那部分调试信息由你的构建产生。

如果启用了诊断上报，报告会携带崩溃时已加载的二进制镜像及其 UUID（含 App 主镜像），按该 UUID 匹配 dSYM 即可，不要用版本号或构建号去匹配——同一版本号可能对应多次构建。

---

## 错误码

所有错误都实现 `RoomError`（`LocalizedError` + `CustomStringConvertible`），可直接读 `localizedDescription`。

```swift
public enum ConnectError: RoomError {
    case connectError(Int32, String? = nil)      // 服务端业务错误码
    case connectFailure(Int32)                   // 信令连接失败
    case connectTimeOut(String? = nil)           // 超时，关联值是接口名
    case disConnected                            // 请求期间连接已断开
    case publishStreamFailure([RoomTrackType])
    case subscribeStreamFailure([RoomUserSubData])
    case unSubscribeStreamFailure([RoomUserSubData])
    case trackNotPublished([RoomUserSubData])    // 订阅了对方还没发布的轨道
    case startScreenShareWithoutGroupId
    case screenShareGroupUnavailable(String)     // App Group 容器不可达
    case screenForbid
    case noAuth                                  // 无权限：userId 为空 / 未入房 / 无发布订阅权
    case joined                                  // 重复加入
    case notInRoom
    case roomReleased                            // RTCRoom 已释放后仍被调用
    case simulcastNoSFUTrack                     // 切层时找不到已订阅的 SFU 轨道
    case endpointNotConfigured                   // 未配置信令地址
}
```

### 抛出 vs 回调

区分清楚这两条通路，否则会漏掉错误：

- **`join` 前的校验错误**（`noAuth`、`endpointNotConfigured`、`joined`）在联网之前**同步抛出**，`try await room.join(...)` 能直接捕获。
- **发布 / 订阅类错误**（`publishStreamFailure`、`subscribeStreamFailure`、`trackNotPublished`）通常**不会**让发起的那个调用抛错，而是走 `RTCRoomDelegate.roomError(_:)`。只 `try` 不实现 `roomError`，这些错误会静静消失。

---

## 已知限制

| 限制 | 影响 | 状态 |
| --- | --- | --- |
| xcframework 只有 `ios-arm64` 切片 | **无法在模拟器上编译运行** | 既定形态 |
| 无 SwiftUI 封装 | 需自行包 `UIViewRepresentable` | — |
| 无公开的 `stopScreenShare` | 只能由用户停止录屏或退房触发 | — |
| 无自定义消息通道 | DataChannel 全部内部使用，不能发业务消息 | — |
| `RoomLiveUrlData` 在对外接口里是空结构体 | **直播 CDN 地址功能对接入方不可用** | 待修复 |
| 管理员增删无客户端 API | 只能服务端操作 | — |
| 音频 AEC / NS / AGC 绑定在音频轨创建时 | 通话中改动不生效 | — |
| 内置美颜参数不可调 | gpupixel 未对外暴露参数 | — |

---

## API 拼写说明

下列拼写错误已固化在公开 API 中，改动会破坏所有接入方，因此保留。**它们不是文档笔误，请照抄。**

| 实际拼写 | 本应是 |
| --- | --- |
| `partipant` / `localPartipant` | `participant` |
| `RTCRoom(delegat:)` | `delegate:` |
| `scence:`（初始化标签） | `scene:` |
| `enalbleSimulcast` | `enableSimulcast` |
| `simucast` | `simulcast` |
| `defaultAuioSpeakerOn` | `defaultAudioSpeakerOn` |
| `addAuidoTrack` / `RoomAuidoTrack` / `RoomAuidioTool` | `Audio` |
| `camerPosion` / `RTCCameraPosion` | `cameraPosition` |
| `RTCCameraPosion.font` | `.front` |
| `audiollevel` | `audioLevel` |
| `NetMonitorValue.donw` | `down` |
| `NetMonitorValue.frameWith` | `frameWidth` |
| `sceenP2P` | `screenP2P` |
| `RoomVideoRrocessMode` | `RoomVideoProcessMode` |
| `getCaputureBuffer` / `setCaputureBuffer` | `Capture` |
| `PaticipantForbidAction` | `Participant` |
| `renderFisrtFrame` | `renderFirstFrame` |
| `RTCParticipantAtion` | `Action` |

---

## 版本与迁移

当前版本 **1.8.0**。

**1.8.0 的变化：** 相对 1.7.9 公开接口是纯增量的，60 个新声明、零删除、零签名变更，全部属于新增的诊断与崩溃上报子系统。另有一个新的错误枚举 case `ConnectError.screenShareGroupUnavailable(String)` —— 如果你对 `ConnectError` 做了没有 `default` 的穷举 `switch`，需要补一个分支。

- **[升级指南](docs/MIGRATION-1.8.0.md)** —— 按起点版本分两条路。**从 1.7.4 及以后升级没有破坏性变更**；从 1.7.3 或更早升级则有 4 处编译期破坏（`RTCConfig` 删除、信令地址改由 `RTCEngine` 持有等），那些变更实际随 1.7.4 发布。

每次发布随包提供 `build-manifest.json`，记录版本、构建号、commit、构建时间、工具链版本与链接形态，用于把线上问题对回具体构建。

```json
{ "module": "QuickVO", "version": "1.8.0", "commit": "d8a3bab…", "treeClean": true, … }
```

> 1.7.x 期间 `MARKETING_VERSION` 一直停在 `1.0`，那段时间发出的每一份 manifest 都写着一个从未发布过的版本号。1.8.0 起该字段与发行仓的 git tag 保持一致。

架构分析、DataChannel 流程等设计文档保留在 SDK 源码仓库，未随发布包分发，需要时向 SDK 团队索取。

---

## License

Copyright © QuickVO. All rights reserved.
