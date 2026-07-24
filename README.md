<p align="center">
  <img src="./ClassicLaunchpad/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="112" height="112" alt="Classic Launchpad 图标">
</p>

<h1 align="center">Classic Launchpad</h1>

<p align="center">
  <strong>把你熟悉的经典启动台，带回 macOS 26</strong>
</p>

<p align="center">
  原生、流畅、完全本地运行的 macOS Launchpad 复刻版
</p>

<p align="center">
  <a href="README.md"><strong>简体中文</strong></a> · <a href="README_EN.md">English</a>
</p>

<p align="center">
  <a href="#download">下载安装</a> ·
  <a href="#highlights">功能亮点</a> ·
  <a href="#controls">使用指南</a> ·
  <a href="#build-from-source">源码构建</a> ·
  <a href="#privacy">隐私说明</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 26.0+">
  <img src="https://img.shields.io/badge/Swift-5.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.0">
  <img src="https://img.shields.io/badge/UI-AppKit-147EFB?style=for-the-badge" alt="AppKit">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="MIT License">
</p>

<p align="center">
  <img src="./assets/readme/launchpad-overview.jpg" width="100%" alt="Classic Launchpad 主界面">
</p>

<p align="center"><em>熟悉的全屏网格、分页圆点、桌面壁纸模糊和应用排列方式。</em></p>

<a id="highlights"></a>

## ✨ 项目亮点

Classic Launchpad 以 macOS 15 及更早版本的 Launchpad 为原型，使用 Swift、AppKit 与 Core Animation 构建。它不会替换或修改任何系统组件，也不包含账号、遥测或云端同步。

### 功能一览

| | |
| --- | --- |
| 🔍 **即时搜索**<br>按本地化名称或 Bundle Identifier 查找应用，直接输入即可开始。 | 📁 **文件夹整理**<br>叠放图标创建文件夹，支持重命名、内部排序和移出应用。 |
| 🖱️ **拖放与分页**<br>页内排序、边缘跨页拖动、触控板横向滑动和分页圆点。 | ⌨️ **完整键盘操作**<br>方向键选择、Return 打开、Escape 返回、Command + 方向键翻页。 |
| 🔄 **自动发现应用**<br>扫描标准应用目录，并通过 Spotlight 跟踪本机应用变化。 | 💾 **布局持久化**<br>自动保存顺序、页面、文件夹名称和自定义全局快捷键。 |
| ⚙️ **显示与排序**<br>可选择是否显示系统应用，并支持默认、名称、最近添加和自定义排序。 | ◲ **触发角启动**<br>可选择一个屏幕角落，支持修饰键触发、系统冲突提示及其他应用的全屏空间。 |
| ✨ **原生视觉效果**<br>从当前桌面壁纸生成模糊背景，并适配多显示器与“减弱动态效果”。 | 🗑️ **安全移除**<br>仅允许符合条件的 Mac App Store 应用在二次确认后移到废纸篓。 |

<a id="showcase"></a>

## 🪄 界面展示

<table>
  <tr>
    <td width="50%"><img src="./assets/readme/folders.jpg" alt="Classic Launchpad 文件夹"></td>
    <td width="50%"><img src="./assets/readme/edit-mode.jpg" alt="Classic Launchpad 编辑模式"></td>
  </tr>
  <tr>
    <td align="center"><strong>文件夹</strong><br>打开、重命名并整理文件夹中的应用</td>
    <td align="center"><strong>编辑模式</strong><br>拖放排序，符合条件的应用可安全移除</td>
  </tr>
</table>

<a id="download"></a>

## 📦 下载与安装

<p align="center">
  <a href="https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.dmg"><img src="https://img.shields.io/badge/下载-DMG-147EFB?style=for-the-badge&logo=apple&logoColor=white" alt="下载 DMG"></a>
  <a href="https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.zip"><img src="https://img.shields.io/badge/下载-ZIP-555555?style=for-the-badge&logo=apple&logoColor=white" alt="下载 ZIP"></a>
</p>

推荐下载 DMG，打开后将 `ClassicLaunchpad.app` 拖入“应用程序”；ZIP 适合直接解压安装。历史版本和更新说明请前往 [Releases](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases)。

> 当前安装包未使用 Apple Developer ID 签名和公证。若首次启动被 macOS 拦截，请打开“系统设置” → “隐私与安全性”，在“安全性”区域点击“仍要打开”。该操作只需执行一次。

### 系统要求

- macOS 26.0 或更高版本
- Apple Silicon 或 Intel Mac
- 安装包无需 Xcode 或第三方依赖

首次启动后，Classic Launchpad 会自动显示，并保留在 Dock 中运行。按 Control + Command + L 可随时显示或隐藏，按 Command + Q 可完全退出。

<a id="build-from-source"></a>

### 从源码构建

从源码构建需要 Xcode 26.0 或更高版本：

1. 下载或克隆本仓库。
2. 使用 Xcode 打开 `ClassicLaunchpad.xcodeproj`。
3. 选择 `ClassicLaunchpad` Scheme 和 `My Mac` 运行目标。
4. 按 Command + R 构建并运行。

也可以在项目目录执行下面的命令打开工程：

```bash
open ClassicLaunchpad.xcodeproj
```

<a id="controls"></a>

## 🎮 使用指南

### 常用操作

| 操作 | 快捷方式 |
| --- | --- |
| 显示或隐藏 Classic Launchpad | Control + Command + L（可修改） |
| 切换页面 | 触控板双指横滑，或 Command + ← / → |
| 搜索应用 | 直接输入文字 |
| 选择应用或文件夹 | 方向键 |
| 打开所选项目 | Return |
| 关闭文件夹、清空搜索或退出启动台 | Escape |
| 进入编辑模式 | 长按图标，或按住 Option |
| 整理应用 | 拖动排序、跨页移动或叠放创建文件夹 |
| 打开设置 | Command + , |
| 退出应用 | Command + Q |

点击空白区域或再次按下全局快捷键也可以关闭启动台。

<a id="restore-layout"></a>

### 设置与布局

<p align="center">
  <img src="./assets/readme/settings.png" width="560" alt="Classic Launchpad 设置界面">
</p>

在设置中可以录制新的全局快捷键、选择是否显示系统应用（默认开启），并设置应用排序方式和触发角，无需辅助功能权限。

排序方式包括“默认顺序”“按名称”“最近添加”和“自定义”。按名称排序时，中文名称会转换为拼音，与英文名称一起按 A–Z 排列。手动拖动应用、调整文件夹后会自动切换为“自定义”；从“自定义”切换到其他排序方式时会先提示确认。

触发角可以选择“关闭”“左上”“右上”“左下”或“右下”。将指针移到已启用的角落会立即显示 Classic Launchpad。选择触发角时可同时按住 Command、Option、Control 或 Shift；设置后，只有按住这些按键并将指针移到该角落，才会显示 Classic Launchpad。如果对应位置已被 macOS 系统触发角占用，应用会提示先在“桌面与程序坞”中关闭该系统触发角。

#### 恢复默认布局

在设置中点击“恢复默认布局”，可重置应用顺序、页面和文件夹，不会删除应用，也不会修改当前快捷键或 macOS 系统设置。此操作无法撤销，如需保留当前布局，请先备份 `Layout.json`。

<a id="privacy"></a>

## 🔐 本地数据与隐私

布局和快捷键配置保存在：

```text
~/Library/Application Support/QitaiClassicLaunchpad/Layout.json
```

- 应用目录扫描、Spotlight 元数据读取、搜索和布局存储均在本机完成
- 当前实现不包含网络请求、用户账号、遥测或云端同步

## 🧩 技术实现

| 模块 | 实现 |
| --- | --- |
| 界面与动画 | AppKit、Core Animation、Core Image |
| 应用发现 | 文件系统扫描、Spotlight `NSMetadataQuery` |
| 全局快捷键 | Carbon Hot Key API |
| 应用启动与删除 | `NSWorkspace` |
| 本地存储 | Codable JSON、原子写入 |

核心代码位于 `ClassicLaunchpad/`。请通过 `ClassicLaunchpad.xcodeproj` 构建可直接运行的完整 `.app`；仓库中的 `Package.swift` 主要用于通过 Swift Package Manager 检查和构建源码。

## 🤝 参与贡献

欢迎通过 Issue 报告问题或提出建议，也欢迎提交范围清晰且能通过 Xcode 构建的 Pull Request。

## 📄 许可证

本项目采用 [MIT License](./LICENSE)。

## 声明

Classic Launchpad 是独立开发的第三方项目，与 Apple Inc. 无隶属或认可关系。“Apple”“macOS”和“Launchpad”是 Apple Inc. 的商标。

<p align="center"><sub>Made for people who miss the classic Launchpad.</sub></p>
