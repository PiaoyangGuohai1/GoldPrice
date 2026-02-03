# GoldPrice 金价监控

<p align="center">
  <img src="Resources/AppIcon.iconset/icon_128x128.png" alt="GoldPrice Icon" width="128">
</p>

<p align="center">
  一个极简的 macOS 菜单栏应用，实时监控京东金融黄金价格。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-12.0+-blue" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/Size-181KB-green" alt="Size">
  <img src="https://img.shields.io/badge/License-MIT-purple" alt="License">
</p>

## 功能特性

- 📊 **菜单栏显示** - 实时在菜单栏显示金价
- 🪟 **悬浮窗** - 可拖拽的悬浮窗，始终置顶显示
- 🏦 **多银行支持** - 民生银行、工商银行、浙商银行
- ⏱️ **自动刷新** - 支持 3/5/10/30/60 秒刷新间隔
- 🎨 **极简设计** - 单文件 ~400 行代码，无任何依赖

## 截图

### 菜单栏
```
┌────────────────────────────────────────┐
│  ... 其他图标 ...  [金: 1101.59]  ... │
└────────────────────────────────────────┘
```

### 下拉菜单
```
┌─────────────────────────┐
│  京东金价监控            │
│  ───────────────────    │
│  显示悬浮窗         ⌘F  │
│  ───────────────────    │
│  民生银行: 1101.59 元/克 │
│  工商银行: 1102.30 元/克 │
│  浙商银行: 1100.85 元/克 │
│  ───────────────────    │
│  更新时间: 16:53:48     │
│  ───────────────────    │
│  刷新间隔            ▶  │
│  立即刷新           ⌘R  │
│  ───────────────────    │
│  退出               ⌘Q  │
└─────────────────────────┘
```

### 悬浮窗
```
┌─────────────────────────┐
│  京东金价               │
│  ─────────────────────  │
│  民生    1101.59 元     │
│  工商    1102.30 元     │
│  浙商    1100.85 元     │
│  更新: 16:53:48         │
└─────────────────────────┘
```

## 安装

### 方式一：直接下载（推荐）
1. 从 [Releases](https://github.com/PiaoyangGuohai1/GoldPrice/releases/latest) 下载 `GoldPrice-v1.0.0.zip`
2. 解压后将 `GoldPrice.app` 拖入「应用程序」文件夹
3. 首次运行：右键点击 → 打开

### 方式二：从源码编译
```bash
git clone https://github.com/PiaoyangGuohai1/GoldPrice.git
cd GoldPrice
chmod +x build.sh
./build.sh
open GoldPrice.app
```

## 使用说明

1. 启动应用后，菜单栏右侧会显示金价
2. 点击菜单栏图标可查看详细信息
3. 选择「显示悬浮窗」(⌘F) 可打开悬浮窗
4. 悬浮窗可拖拽到任意位置

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘F | 显示/隐藏悬浮窗 |
| ⌘R | 立即刷新 |
| ⌘Q | 退出应用 |

## 首次运行

由于应用未经 Apple 签名，首次运行时 macOS 可能会阻止。请按以下步骤操作：

1. 右键点击 `GoldPrice.app`
2. 选择「打开」
3. 在弹出的对话框中点击「打开」

或者在终端执行：
```bash
xattr -cr /Applications/GoldPrice.app
```

## 开机自启动

1. 打开「系统偏好设置」→「通用」→「登录项」
2. 点击「+」添加 `GoldPrice.app`

## 数据来源

金价数据来自京东金融 API：
- 民生银行积存金
- 工商银行积存金
- 浙商银行积存金

## 技术栈

| 项目 | 说明 |
|------|------|
| 语言 | Swift 5.9 |
| 框架 | AppKit (原生 macOS) |
| 代码量 | ~400 行 |
| 依赖 | 无 |
| 应用大小 | 368 KB |
| 下载大小 | 181 KB |

## 项目结构

```
GoldPrice/
├── Sources/
│   └── main.swift      # 全部源代码
├── Resources/
│   ├── AppIcon.icns    # 应用图标
│   └── AppIcon.iconset # 图标源文件
├── Info.plist          # 应用配置
├── build.sh            # 构建脚本
└── README.md
```

## 构建要求

- macOS 12.0+
- Xcode Command Line Tools

## License

MIT License

## 作者

[@PiaoyangGuohai1](https://github.com/PiaoyangGuohai1)
