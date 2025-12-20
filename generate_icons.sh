#!/bin/bash

# 定义源文件和目标目录
SOURCE="app.png"
ASSETS_DIR="QvPlayer/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

# 检查源文件是否存在
if [ ! -f "$SOURCE" ]; then
    echo "❌ 错误: 未找到 logo.png，请将图片放在项目根目录。"
    exit 1
fi

echo "🚀 开始生成 tvOS 图标资源..."

# ---------------------------------------------------------
# 1. Top Shelf Image (顶栏大图)
# 尺寸: 1920x720
# ---------------------------------------------------------
TARGET_DIR="$ASSETS_DIR/Top Shelf Image.imageset"
echo "Processing Top Shelf Image..."
# 确保目录存在
mkdir -p "$TARGET_DIR"
# 清理旧的 png 文件
rm -f "$TARGET_DIR"/*.png
# 生成图片 (使用 JPEG 格式以确保不透明，解决 Alpha 通道报错)
sips -s format jpeg -z 720 1920 "$SOURCE" --out "$TARGET_DIR/Content.jpg" > /dev/null
# 创建 Contents.json
cat > "$TARGET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Content.jpg",
      "idiom" : "tv",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ---------------------------------------------------------
# 1.1 Top Shelf Image Wide (顶栏宽图)
# 尺寸: 2320x720
# ---------------------------------------------------------
TARGET_DIR="$ASSETS_DIR/Top Shelf Image Wide.imageset"
echo "Processing Top Shelf Image Wide..."
mkdir -p "$TARGET_DIR"
rm -f "$TARGET_DIR"/*.png
sips -s format jpeg -z 720 2320 "$SOURCE" --out "$TARGET_DIR/Content.jpg" > /dev/null
cat > "$TARGET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Content.jpg",
      "idiom" : "tv",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ---------------------------------------------------------
# 2. App Icon - Front Layer (主屏幕图标 - 前景)
# 尺寸: 400x240 (1x), 800x480 (2x)
# ---------------------------------------------------------

# 更新 App Icon Stack 的 Contents.json，只保留 Front 和 Back
cat > "$ASSETS_DIR/App Icon.imagestack/Contents.json" <<EOF
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "layers" : [
    {
      "filename" : "Front.imagestacklayer"
    },
    {
      "filename" : "Back.imagestacklayer"
    }
  ]
}
EOF

TARGET_DIR="$ASSETS_DIR/App Icon.imagestack/Front.imagestacklayer/Content.imageset"
echo "Processing App Icon (Front Layer)..."
mkdir -p "$TARGET_DIR"
sips -z 240 400 "$SOURCE" --out "$TARGET_DIR/Content.png" > /dev/null
sips -z 480 800 "$SOURCE" --out "$TARGET_DIR/Content@2x.png" > /dev/null
cat > "$TARGET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Content.png",
      "idiom" : "tv",
      "scale" : "1x"
    },
    {
      "filename" : "Content@2x.png",
      "idiom" : "tv",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ---------------------------------------------------------
# 3. App Icon - Back Layer (主屏幕图标 - 背景)
# 我们生成一个纯白色的背景，防止透明穿透
# ---------------------------------------------------------
TARGET_DIR="$ASSETS_DIR/App Icon.imagestack/Back.imagestacklayer/Content.imageset"
echo "Processing App Icon (Back Layer)..."
mkdir -p "$TARGET_DIR"
# 清理旧的 png 文件
rm -f "$TARGET_DIR"/*.png

# 使用 sips 生成纯白背景 (先缩小到 1x1，再填充白色到目标尺寸)
# 1. 生成 1x1 的临时文件
sips -s format jpeg -z 1 1 "$SOURCE" --out temp_1x1.jpg > /dev/null

# 2. 填充白色到 400x240 (1x)
sips -s format jpeg -p 240 400 --padColor FFFFFF temp_1x1.jpg --out "$TARGET_DIR/Content.jpg" > /dev/null

# 3. 填充白色到 800x480 (2x)
sips -s format jpeg -p 480 800 --padColor FFFFFF temp_1x1.jpg --out "$TARGET_DIR/Content@2x.jpg" > /dev/null

# 清理临时文件
rm temp_1x1.jpg

cat > "$TARGET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Content.jpg",
      "idiom" : "tv",
      "scale" : "1x"
    },
    {
      "filename" : "Content@2x.jpg",
      "idiom" : "tv",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# ---------------------------------------------------------
# 4. App Store Icon (App Store 图标)
# 尺寸: 1280x768
# ---------------------------------------------------------

# 更新 App Store Icon Stack 的 Contents.json，只保留 Front 和 Back
cat > "$ASSETS_DIR/App Icon - App Store.imagestack/Contents.json" <<EOF
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "layers" : [
    {
      "filename" : "Front.imagestacklayer"
    },
    {
      "filename" : "Back.imagestacklayer"
    }
  ]
}
EOF

TARGET_DIR="$ASSETS_DIR/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset"
echo "Processing App Store Icon..."
mkdir -p "$TARGET_DIR"
# 清理旧的 png 文件
rm -f "$TARGET_DIR"/*.png
sips -z 768 1280 "$SOURCE" --out "$TARGET_DIR/Content.png" > /dev/null
cat > "$TARGET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Content.png",
      "idiom" : "tv",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# 处理 App Store Icon 的背景层
TARGET_DIR="$ASSETS_DIR/App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset"
mkdir -p "$TARGET_DIR"
# 清理旧的 png 文件
rm -f "$TARGET_DIR"/*.png

# 使用 sips 生成纯白背景
sips -s format jpeg -z 1 1 "$SOURCE" --out temp_1x1.jpg > /dev/null
sips -s format jpeg -p 768 1280 --padColor FFFFFF temp_1x1.jpg --out "$TARGET_DIR/Content.jpg" > /dev/null
rm temp_1x1.jpg

cat > "$TARGET_DIR/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "Content.jpg",
      "idiom" : "tv",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ 所有图标已生成完毕！请在 Xcode 中检查 Assets.xcassets。"
