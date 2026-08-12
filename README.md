<div align="center">

# QuickVO iOS SDK

**面向 iOS 的实时音视频（RTC）SDK，基于 WebRTC 构建，支持 SFU / P2P 混合组网。**

[![Platform](https://img.shields.io/badge/platform-iOS%2013.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)](https://swift.org)
[![Xcode](https://img.shields.io/badge/Xcode-15.4-blue.svg)](https://developer.apple.com/xcode/)
[![WebRTC](https://img.shields.io/badge/WebRTC-137.0.1-green.svg)](https://webrtc.org)

</div>

---

## 简介

QuickVO 是一套面向 iOS 的实时音视频通话 SDK。它在 WebRTC 之上封装了一套简洁的房间（Room）模型：开发者只需创建 `RTCRoom`、加入房间并实现委托回调，即可快速集成 1v1 通话、多人会议、直播连麦等场景，无需直接与底层 WebRTC / 信令细节打交道。

SDK 内部采用 **SFU（服务端转发）+ P2P（点对点）混合组网**，根据网络与场景自动选择最优链路，并内置断线重连、屏幕共享、美颜、实时语音识别与翻译等能力。

## 特性

- 🎥 **音视频通话** — 音频、视频轨道独立发布 / 订阅，支持前后摄像头切换、扬声器 / 听筒切换。
- 🌐 **SFU + P2P 混合组网** — 按网络与场景在服务端转发与点对点直连之间自动切换。
- 🎬 **多场景支持** — 通信（1v1）、会议（meeting）、直播（live）、会控（conference）。
- 🔁 **自动断线重连** — 统一重连状态机，重连策略可通过 `RTCReconnectPolicy` 调优。
- 🖥️ **屏幕共享** — 基于 ReplayKit + App Group 的系统级屏幕共享（`QVReplayKitExt`）。
- 💄 **美颜滤镜** — 集成 [gpupixel](https://github.com/pixpark/gpupixel) 的视频前处理管线。
- 🗣️ **实时语音识别与翻译** — 服务端语音转写（Speech-to-Text）及多语言翻译。
- 📡 **直播 CDN** — 直播场景下自动返回国内 / 海外 / 全球 CDN 播放地址。
- 📐 **Simulcast 大小流** — 按订阅端能力自适应分辨率。
- 🎛️ **房间管理** — 禁言 / 禁视频 / 禁屏幕共享、管理员管理、白板（Whiteboard）协同。
- 📊 **网络与音量监控** — 实时网络质量、说话状态、音量等级回调。

## 环境要求

| 项目 | 要求 |
| --- | --- |
| iOS | 13.0+ |
| Swift | 5.0 |
| Xcode | 15.4 |
| 架构 | 真机 arm64 |

## 依赖

SDK 通过 Swift Package Manager 管理以下依赖（详见 `project.yml`）：

| 依赖 | 用途 |
| --- | --- |
| [WebRTC-iOS](https://github.com/motian30/WebRTC-iOS) | WebRTC 核心（137.0.1） |
| [Starscream](https://github.com/daltoniam/Starscream) | WebSocket 信令 |
| [swift-protobuf](https://github.com/apple/swift-protobuf) | 信令 Protobuf 编解码 |
| [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) | 日志 |
| [SwiftNATDetector](https://github.com/motian30/SwiftNATDetector) | NAT 类型探测 |
| [GzipSwift](https://github.com/1024jp/GzipSwift) | 数据压缩 |
| gpupixel | 美颜 / 视频前处理 |
| QVReplayKitExt | 屏幕共享帧共享内存契约 |

## 构建

项目工程文件由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `project.yml` 生成。

```bash
# 1. 生成 Xcode 工程
xcodegen generate

# 2. 打开工作空间
open QuickVO.xcworkspace
```

### 打包 XCFramework

使用根目录的 `build.sh` 归档并生成可分发的 `QuickVO.xcframework`（真机 arm64）：

```bash
./build.sh
```

产物输出到 `build/QuickVO.xcframework`，并自动移动到上级 `../QuickVO` 目录。

## 快速开始

> 从 1.7.x 升级请先看 [升级到 1.8.0](docs/MIGRATION-1.8.0.md)：`RTCConfig` 已删除，信令地址改由 `RTCEngine` 持有。

### 1. 创建引擎

引擎是进程级的，整个 App 只需创建一次。**信令地址配在这里，不是配在房间上**——没有内置默认地址，未配置时 `join` 会抛 `ConnectError.endpointNotConfigured`。

```swift
import QuickVO

// 地址启动时已知
RTCEngine.create("your_app_id", socketURL: URL(string: "wss://your-signal-server/websocket")!)

// 地址需要从自己的服务器取，就先创建、后补上；configure 对之后所有房间生效
RTCEngine.create("your_app_id")
RTCEngine.engine.configure(socketURL: url)
```

beta 包可以把 SDK 自身日志发到开发环境：`RTCEngine.create(appId, socketURL: url, logEnvironment: .development)`。

### 2. 创建房间并设置委托

房间不持有地址，join 时从引擎取一份快照，整场会话不变。按通话新建即可。

```swift
let room = RTCRoom(delegat: self)
```

### 3. 加入房间

```swift
let option = RoomLocalOption(
    userId: "user_123",
    defaultStartCamera: true,   // 加入即开启摄像头
    subscribeType: .auto,       // 自动订阅
    publishType: .auto,         // 自动发布
    scence: .communication      // 场景：1v1 通信
)

try await room.join(token, "roomId", option)
```

### 4. 实现房间委托

```swift
extension MyViewController: RTCRoomDelegate {
    // 房间连接状态变化
    func roomStatus(_ status: RTCRoomConnect) { }

    // 有成员加入 / 离开
    func didJoin(_ room: RTCRoom, _ participant: RTCParticipant) { }
    func didLeave(_ room: RTCRoom, _ participant: RTCParticipant) { }

    // 房间关闭
    func didClose(_ room: RTCRoom, _ code: Int?, _ desc: String?) { }

    // 错误 / Token 过期
    func roomError(_ error: Error) { }
    func tokenExpired() { }
}
```

### 5. 渲染音视频轨道

为每个 `RTCParticipant` 设置委托，接收其音视频轨道：

```swift
participant.delegate = self

extension MyViewController: RTCParticipantDelegate {
    func addVideoTrack(_ participant: RTCParticipant, _ track: RoomVideoTrack) {
        // 将 track 渲染到视图上
    }
    func speaking(_ participant: RTCParticipant, _ speaking: Bool) { }
    func network(_ participant: RTCParticipant, _ net: NetMonitorValue) { }
}
```

### 6. 控制本地音视频

本地控制统一通过 `room.localPartipant`：

```swift
room.localPartipant.enableMicrophone(true)   // 开 / 关麦克风
room.localPartipant.enableCamera(true)       // 开 / 关摄像头
room.localPartipant.switchCamera()           // 切换前后摄像头
room.localPartipant.enableSpeaker(true)      // 扬声器 / 听筒
await room.localPartipant.startPreview(view) // 本地预览
```

### 7. 退出房间

```swift
await room.quit()
```

## 进阶能力

```swift
// 手动订阅 / 取消订阅
try await room.subscribe(userData)
try await room.unSubscribe(userData)

// 屏幕共享（需配置 App Group）
try await room.startScreenShare("group.com.your.app")

// 房间管控（禁言 / 禁视频等）
try await room.forbidWith([.audioForbid(true)])

// 实时语音识别 / 翻译
await room.updateSpeech(RoomSpeechOption(open: true, translate: true))

// 白板协同
try await room.createWhiteboard(whiteboardId)
try await room.joinWhiteboard(whiteboardId)
```

## 项目结构

```
QuickVO/
├── Public/       # 对外公开 API（RTCParticipant、RoomTrack、视图等）
├── RoomEngine/   # 房间引擎（RTCRoom 入口、委托、定义）
├── Control/      # 房间控制（音视频、订阅、发布、P2P、白板等）
├── RTC/          # WebRTC 封装、重连状态机、音视频采集
├── Local/        # 本地参与者、摄像头采集、音频会话
├── Server/       # HTTP / 房间服务接口
├── Socket/       # WebSocket 信令客户端
├── Net/          # 网络监测
├── Config/       # 配置（房间参数、音视频采集参数、语言）
├── Broadcast/    # 屏幕共享（ReplayKit）
└── pb/           # Protobuf 生成代码
```

## 文档

- [升级到 1.8.0](docs/MIGRATION-1.8.0.md) — 从 1.7.x 升级的破坏性变更与迁移步骤

架构分析、DataChannel 流程等设计文档保留在 SDK 源码仓库，未随发布包分发；需要时向 SDK 团队索取。此前这里列出的五个 `docs/` 链接指向的是源码仓库的路径，在本仓库中始终无法访问。

## License

Copyright © QuickVO. All rights reserved.
