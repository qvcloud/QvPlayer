# QvPlayer API 文档

QvPlayer 提供了一个内置的 HTTP 服务器，允许你远程控制播放器和管理播放列表。

**基础 URL**: `http://<Apple-TV-IP>:12345`

## 📺 播放列表管理

### 获取所有视频
获取当前的播放列表。

- **接口**: `GET /api/v1/videos` (或 `/api/v1/playlist`)
- **响应**: JSON 数组
  ```json
  [
    {
      "title": "频道名称",
      "url": "http://example.com/stream.m3u8",
      "group": "新闻"
    }
  ]
  ```

### 添加视频
在播放列表末尾添加一个新的视频流。

- **接口**: `POST /api/v1/videos`
- **Content-Type**: `application/json`
- **请求体**:
  ```json
  {
    "title": "新频道",
    "url": "http://example.com/stream.m3u8",
    "group": "电影"
  }
  ```
- **响应**: `{"success": true}`

### 更新视频
编辑播放列表中现有的视频。

- **接口**: `PUT /api/v1/videos?index={index}`
- **查询参数**:
  - `index`: 要更新的视频的索引（从 0 开始）。
- **Content-Type**: `application/json`
- **请求体**:
  ```json
  {
    "title": "更新后的名称",
    "url": "http://example.com/new_url.m3u8",
    "group": "更新后的分组"
  }
  ```
- **响应**: `{"success": true}`

### 删除视频
从播放列表中移除一个视频。

- **接口**: `DELETE /api/v1/videos?index={index}`
- **查询参数**:
  - `index`: 要删除的视频的索引（从 0 开始）。
- **响应**: `{"success": true}`

### 替换播放列表
使用 M3U 内容覆盖整个播放列表。

- **接口**: `POST /api/v1/playlist`
- **Content-Type**: `application/json` 或 `text/plain`
- **请求体 (JSON)**:
  ```json
  {
    "content": "#EXTM3U\n#EXTINF:-1,Channel 1\nhttp://..."
  }
  ```
- **请求体 (纯文本)**: 直接发送 M3U 内容字符串。
- **响应**: `{"success": true}`

---

## 🎮 播放控制

### 获取播放状态
获取当前的播放状态。

- **接口**: `GET /api/v1/status`
- **响应**:
  ```json
  {
    "isPlaying": true,
    "title": "当前视频标题",
    "currentTime": 120.5,
    "duration": 3600.0
  }
  ```

### 播放命令
控制播放状态。

- **播放**: `POST /api/v1/control/play`
- **暂停**: `POST /api/v1/control/pause`
- **切换播放/暂停**: `POST /api/v1/control/toggle`
- **播放指定视频**: `POST /api/v1/control/play_video?id={uuid}`

### 快进/快退 (Seek)
相对于当前位置快进或快退。

- **接口**: `POST /api/v1/control/seek?time={seconds}`
- **查询参数**:
  - `time`: 要跳转的秒数（正数表示快进，负数表示快退）。
- **示例**: `/api/v1/control/seek?time=30` (快进 30 秒)

---

## 📂 文件上传

### 上传视频
上传本地视频文件到 Apple TV。

- **接口**: `POST /api/v1/upload`
- **Content-Type**: `multipart/form-data`
- **请求体**: 包含名为 `file` 的文件字段的表单数据。
- **响应**:
  ```json
  {
    "success": true,
    "path": "uploaded_filename.mp4"
  }
  ```
