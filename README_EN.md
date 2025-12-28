# QvPlayer for tvOS

QvPlayer is a powerful and flexible video player designed specifically for Apple TV (tvOS). It combines the efficiency of the native system player with the versatility of FFmpeg, ensuring playback support for a wide range of video formats including MP4, MKV, AVI, and modern codecs like AV1.

## ✨ Key Features

*   **Dual Playback Engines**:
    *   **System Player (AVPlayer)**: Best for standard formats (H.264, HEVC/H.265). Uses hardware decoding for maximum battery efficiency and performance.
    *   **KSPlayer (FFmpeg)**: A robust fallback engine that supports virtually any format (MKV, AVI, WMV, FLV) and codecs that the system might not support natively (e.g., AV1).
*   **Web Management Interface**: Built-in web server allows you to manage playlists and upload files directly from your computer's browser.
    *   **Playlist Management**: Easily add, remove, or reorder items in the playback queue.
    *   **Remote Control**: Control playback (play, pause, seek) directly from the web interface.
*   **Smart Playback Queue**: 
    *   Supports **Pending/Playing/Played** status tracking.
    *   **Loop Playback**: Global setting to loop the entire queue or single videos.
    *   Automatic skipping of invalid links.
*   **Background Speed Test**: Automatically detects the availability and loading speed of live streams or video links, with real-time feedback in the UI.
*   **M3U Playlist Support**: Support for importing and managing live stream sources in M3U format.
*   **Smart Codec Detection**: Automatically detects unsupported codecs (like AV1 on older hardware) and suggests switching to the appropriate player engine.
*   **Native tvOS UI**: Designed with SwiftUI for a seamless big-screen experience, supporting the Focus Engine.
*   **Localization**: Fully localized in English and Simplified Chinese (简体中文).

## 🚀 Getting Started

### Requirements

*   Xcode 15.0 or later
*   tvOS 16.0 or later
*   Swift 5.9+

### Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/yourusername/QvPlayer.git
    cd QvPlayer
    ```

2.  **Open the project**:
    Open `QvPlayer.xcodeproj` in Xcode.

3.  **Resolve Dependencies**:
    The project uses Swift Package Manager (SPM). Xcode should automatically fetch the required packages:
    *   [KSPlayer](https://github.com/kingslay/KSPlayer)
    *   [FFmpegKit](https://github.com/kingslay/FFmpegKit)
    *   [GCDWebServer](https://github.com/swisspol/GCDWebServer)

4.  **Build and Run**:
    Select your Apple TV simulator or connected device and press `Cmd + R`.

## 📖 Usage

### Importing Videos & Live Streams

1.  **Web Transfer (Recommended)**:
    *   Open QvPlayer on your Apple TV.
    *   Note the IP address displayed on the settings or home screen (e.g., `http://192.168.1.x:10001`).
    *   Open that URL in a web browser on your computer.
    *   **Upload Files**: Drag and drop video files into the web page.
    *   **Add Links**: Enter stream URLs or upload M3U files via the web interface.

2.  **iTunes File Sharing**:
    *   Connect your Apple TV to your Mac.
    *   In Finder, navigate to the "Files" tab for the Apple TV and drag videos into the QvPlayer folder.

### Playback Queue Management

*   **Add to Queue**: Long-press a video on the home screen or click "Add to Queue" on the web interface.
*   **Auto-play**: Videos in the queue will play sequentially.
*   **Status Tracking**: The player automatically tracks which videos have been played and which are pending.

### Speed Test System

*   The app automatically tests the speed of video sources in the background.
*   Results are displayed as colors or labels on video thumbnails, helping you choose the smoothest source.

### Switching Player Engines

If you encounter a video with sound but no image (black screen):
1.  Go to **Settings** within the app.
2.  Change **Player Engine** from `System` to `KSPlayer`.

## 🛠 Tech Stack

*   **Language**: Swift 5.9+
*   **UI Framework**: SwiftUI
*   **Architecture**: MVVM + Services
*   **Core Components**:
    *   `MediaManager`: Core business logic, handling playback queue and media library.
    *   `SpeedTestManager`: Background concurrent speed test engine.
    *   `CacheManager`: Media metadata and cache management.
    *   `WebServer`: Remote management interface based on GCDWebServer.
    *   `DatabaseManager`: Lightweight persistence based on JSON/Files.

## 📸 Screenshots

For more screenshots, please check the [Screenshot/](Screenshot/) directory.

| Player | Live |
|:---:|:---:|
| <img src="Screenshot/player.png" width="400"/> | <img src="Screenshot/live.png" width="400"/> |

## 📝 License

MIT License - see the [LICENSE](LICENSE) file for details.
