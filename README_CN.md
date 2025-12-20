# QvPlayer for tvOS

QvPlayer 是一款专为 Apple TV (tvOS) 设计的强大且灵活的视频播放器。它结合了原生系统播放器的高效性与 FFmpeg 的多功能性，确保支持广泛的视频格式，包括 MP4、MKV、AVI 以及 AV1 等现代编码格式。

## ✨ 主要功能

*   **双播放引擎**:
    *   **系统播放器 (AVPlayer)**: 最适合标准格式 (H.264, HEVC/H.265)。利用硬件解码实现最高的电池效率和性能。
    *   **KSPlayer (FFmpeg)**: 强大的备用引擎，支持几乎所有格式 (MKV, AVI, WMV, FLV) 以及系统本身不支持的编码 (如 AV1)。
*   **Web 管理界面**: 内置 Web 服务器，允许你直接通过电脑浏览器管理播放列表和上传文件。
*   **智能编码检测**: 自动检测不支持的编码（如旧硬件上的 AV1），并建议切换到合适的播放引擎。
*   **播放列表管理**: 创建并整理你的视频收藏。
*   **原生 tvOS UI**: 使用 SwiftUI 设计，完美适配大屏幕操作体验。
*   **多语言支持**: 完全支持简体中文和英文。

## 🚀 快速开始

### 环境要求

*   Xcode 15.0 或更高版本
*   tvOS 16.0 或更高版本
*   Swift 5.9+

### 安装步骤

1.  **克隆仓库**:
    ```bash
    git clone https://github.com/yourusername/QvPlayer.git
    cd QvPlayer
    ```

2.  **打开项目**:
    在 Xcode 中打开 `QvPlayer.xcodeproj`。

3.  **解析依赖**:
    项目使用 Swift Package Manager (SPM)。Xcode 应该会自动获取所需的包：
    *   [KSPlayer](https://github.com/kingslay/KSPlayer)
    *   [FFmpegKit](https://github.com/kingslay/FFmpegKit)

4.  **构建并运行**:
    选择你的 Apple TV 模拟器或连接的设备，然后按 `Cmd + R`。

## 📖 使用指南

### 导入视频

有两种方法可以将视频导入 QvPlayer：

1.  **Web 传输 (推荐)**:
    *   在 Apple TV 上打开 QvPlayer。
    *   记下设置或主屏幕上显示的 IP 地址 (例如 `http://192.168.1.x:10001`)。
    *   在电脑浏览器中打开该 URL。
    *   将视频文件拖放到网页中，即可直接上传到 Apple TV。

2.  **iTunes 文件共享**:
    *   将 Apple TV 连接到 Mac (或使用无线调试)。
    *   打开 Finder (或旧版 macOS 上的 iTunes)。
    *   导航到 Apple TV 的“文件”选项卡。
    *   将视频文件拖入 QvPlayer 文档文件夹。

### 切换播放引擎

如果你遇到视频**有声音但无画面**（黑屏）的情况，这通常是因为该视频使用了原生播放器不支持的编码（例如 AV1）。

1.  进入 App 内的 **设置 (Settings)**。
2.  将 **播放引擎 (Player Engine)** 从 `System` 切换为 `KSPlayer`。
3.  重新开始播放。

## 🛠 技术栈

*   **语言**: Swift
*   **UI 框架**: SwiftUI
*   **架构**: MVVM
*   **核心库**:
    *   `AVKit` / `AVFoundation` (系统播放)
    *   `KSPlayer` (基于 FFmpeg 的播放)
    *   `GCDWebServer` (在 `Utilities/WebServer.swift` 中实现的自定义 Web 服务)

## 📝 许可证

本项目仅供教育和个人使用。关于第三方库 (KSPlayer, FFmpegKit) 的使用条款，请参阅它们各自的许可证。
