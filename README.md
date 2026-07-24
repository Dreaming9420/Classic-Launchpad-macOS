<p align="center">
  <img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/ClassicLaunchpad/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="112" height="112" alt="Classic Launchpad 图标">
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
  <img src="https://img.shields.io/badge/macOS-26.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 26.0+">
  <img src="https://img.shields.io/badge/Swift-5.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.0">
  <img src="https://img.shields.io/badge/UI-AppKit-147EFB?style=for-the-badge" alt="AppKit">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/第三方依赖-0-31C653?style=flat-square" alt="无第三方依赖">
  <img src="https://img.shields.io/badge/数据处理-仅限本机-31C653?style=flat-square" alt="数据仅在本机处理">
  <img src="https://img.shields.io/badge/版本-1.1.0-blue?style=flat-square" alt="版本 1.1.0">
  <img src="https://img.shields.io/badge/许可证-MIT-yellow?style=flat-square" alt="MIT License">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/launchpad-overview.jpg" width="100%" alt="Classic Launchpad 主界面">
</p>

<p align="center"><em>熟悉的全屏网格、分页圆点、桌面壁纸模糊和应用排列方式。</em></p>

<a id="highlights"></a>

## ✨ 项目亮点

<table>
  <tr>
    <td width="33%" align="center">
      <h3>🖥️ 经典体验</h3>
      <p>以 macOS 15 及更早版本的 Launchpad 为原型，还原全屏网格、分页、文件夹和抖动编辑模式。</p>
    </td>
    <td width="33%" align="center">
      <h3>⚡ 原生流畅</h3>
      <p>使用 Swift、AppKit 与 Core Animation 构建，支持触控板手势、键盘导航和多显示器。</p>
    </td>
    <td width="33%" align="center">
      <h3>🔒 本地优先</h3>
      <p>没有账号、遥测或云端同步。应用扫描、搜索和布局存储全部在你的 Mac 上完成。</p>
    </td>
  </tr>
</table>

Classic Launchpad 是为 macOS 26 开发的独立第三方应用。它不会替换或修改 macOS 系统组件，只负责提供一个熟悉、可自定义的应用启动入口。

### 1.1.0 新功能

- 新增“显示系统应用”开关，默认开启
- 新增默认顺序、按名称、最近添加和自定义排序；中文名称支持按拼音 A–Z 排列
- 新增可自定义的触发角，支持四个角落、组合键触发及系统触发角冲突提示
- Classic Launchpad 现在可以显示在其他应用所在的全屏空间中

### 功能一览

| | |
| --- | --- |
| 🔍 **即时搜索**<br>按本地化名称或 Bundle Identifier 查找应用，直接输入即可开始。 | 📁 **文件夹整理**<br>叠放图标创建文件夹，支持重命名、内部排序和移出应用。 |
| 🖱️ **拖放与分页**<br>页内排序、边缘跨页拖动、触控板横向滑动和分页圆点。 | ⌨️ **完整键盘操作**<br>方向键选择、Return 打开、Escape 返回、Command + 方向键翻页。 |
| 🔄 **自动发现应用**<br>扫描标准应用目录，并通过 Spotlight 跟踪本机应用变化。 | 💾 **布局持久化**<br>自动保存顺序、页面、文件夹名称和自定义全局快捷键。 |
| ⚙️ **显示与排序**<br>可选择是否显示系统应用，并支持默认、名称、最近添加和自定义排序。 | ◲ **触发角启动**<br>可选择一个屏幕角落，支持组合键触发，并可在其他应用的全屏空间中显示。 |
| ✨ **原生视觉效果**<br>从当前桌面壁纸生成模糊背景，并适配多显示器与“减弱动态效果”。 | 🗑️ **安全移除**<br>仅允许符合条件的 Mac App Store 应用在二次确认后移到废纸篓。 |

<a id="showcase"></a>

## 🪄 界面展示

<table>
  <tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/folders.jpg" alt="Classic Launchpad 文件夹"></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/edit-mode.jpg" alt="Classic Launchpad 编辑模式"></td>
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

| 安装包 | 适用场景 | 安装方式 |
| --- | --- | --- |
| [`ClassicLaunchpad.dmg`](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.dmg) | 推荐，大多数用户 | 打开 DMG，将 `ClassicLaunchpad.app` 拖入“应用程序” |
| [`ClassicLaunchpad.zip`](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.zip) | 便携压缩包 | 解压后将 `ClassicLaunchpad.app` 拖入“应用程序” |

还可以前往 [Releases](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases) 查看所有版本、更新说明和历史安装包。

### 系统要求

- macOS 26.0 或更高版本
- 安装包无需 Xcode 或第三方依赖

首次启动后，Classic Launchpad 会自动显示。应用会在 Dock 中显示，可按 Command + Q 退出。

<a id="quick-start"></a>

### 从源码运行

从源码构建需要 Xcode 26.0 或更高版本：

1. 下载或克隆本仓库。
2. 使用 Xcode 打开 `ClassicLaunchpad.xcodeproj`。
3. 选择 `ClassicLaunchpad` Scheme 和 `My Mac` 运行目标。
4. 按 Command + R 构建并运行。

也可以在项目目录执行下面的命令打开工程：

```bash
open ClassicLaunchpad.xcodeproj
```

<details>
<summary><strong>将构建好的 App 放入“应用程序”文件夹</strong></summary>

1. 在 Xcode 中按 Command + B 完成构建。
2. 选择 `Product` → `Show Build Folder in Finder`。
3. 在对应配置的 `Products` 目录中找到 `ClassicLaunchpad.app`。
4. 将它拖入 `/Applications`。

</details>

<a id="controls"></a>

## 🎮 操作方式

| 操作 | 快捷方式 |
| --- | --- |
| 显示或隐藏 Classic Launchpad | Control + Option + Space（可修改） |
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

## ⚙️ 设置与恢复默认布局

<p align="center">
  <img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/settings.png" width="560" alt="Classic Launchpad 设置界面">
</p>

在设置中可以录制新的全局快捷键、选择是否显示系统应用，并设置应用排序方式和触发角，无需辅助功能权限。

排序方式包括“默认顺序”“按名称”“最近添加”和“自定义”。按名称排序时，中文名称会转换为拼音，与英文名称一起按 A–Z 排列。手动拖动应用、调整文件夹后会自动切换为“自定义”；从“自定义”切换到其他排序方式时会先提示确认。

触发角可以选择“关闭”“左上”“右上”“左下”或“右下”。将指针移到已启用的角落会立即显示 Classic Launchpad；按住 Command、Option、Control 或 Shift 选择时，可以设置组合键触发。如果对应位置已被 macOS 系统触发角占用，应用会提示先在“桌面与程序坞”中关闭该系统触发角。

### 如何恢复默认布局

1. 显示 Classic Launchpad。
2. 按 Command + , 打开设置。
3. 点击“恢复默认布局”。
4. 在确认窗口中点击“恢复”。

恢复完成后，启动台会立即按照当前已安装的应用重新生成布局并自动保存。

| 会恢复 | 不会改变 |
| --- | --- |
| 应用排列顺序 | 已安装的应用及其文件 |
| 页面分布 | 当前全局快捷键 |
| 文件夹及文件夹名称 | macOS 系统设置 |

恢复操作无法撤销。如果希望保留当前布局，可以事先备份 `Layout.json`。

<a id="privacy"></a>

## 🔐 本地数据与隐私

布局和快捷键配置保存在：

```text
~/Library/Application Support/QitaiClassicLaunchpad/Layout.json
```

- 应用目录扫描、Spotlight 元数据读取、搜索和布局存储均在本机完成
- 当前实现不包含网络请求、用户账号、遥测或云端同步
- 布局文件损坏时，原文件会保留为带时间戳的 `Layout.corrupt-*.json`，随后重新生成布局

### 删除应用的边界

删除按钮只会出现在同时满足以下条件的应用上：

- 位于 `/Applications` 或 `~/Applications`
- 包含 Mac App Store 收据
- 不是系统应用

删除前会再次请求确认，确认后通过 macOS 系统接口将应用移到废纸篓。其他应用不会显示删除按钮。

## 🧩 技术实现

| 模块 | 实现 |
| --- | --- |
| 界面与动画 | AppKit、Core Animation、Core Image |
| 应用发现 | 文件系统扫描、Spotlight `NSMetadataQuery` |
| 全局快捷键 | Carbon Hot Key API |
| 应用启动与删除 | `NSWorkspace` |
| 本地存储 | Codable JSON、原子写入 |

核心代码位于 `ClassicLaunchpad/`，完整 `.app` 建议通过 `ClassicLaunchpad.xcodeproj` 构建。仓库同时提供 `Package.swift`，便于使用 Swift Package Manager 检查和构建源码。

## 📌 已知限制

- 当前应用界面仅提供简体中文
- 布局数据不会在不同 Mac 之间同步
- 应用移除功能仅适用于符合条件的 Mac App Store 应用

## 🤝 参与贡献

欢迎通过 Issue 报告可复现的问题或提出改进建议，也欢迎提交范围清晰的 Pull Request。提交前请确认项目可以通过 Xcode 构建，并尽量保持改动聚焦。

## 📄 许可证

本项目采用 [MIT License](./LICENSE)。你可以使用、复制、修改和分发本项目，但必须保留原始版权与许可证声明。

## 声明

Classic Launchpad 是独立开发的第三方项目，与 Apple Inc. 无隶属或认可关系。“Apple”“macOS”和“Launchpad”是 Apple Inc. 的商标。

<p align="center"><sub>Made for people who miss the classic Launchpad.</sub></p>
