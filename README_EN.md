<p align="center">
  <img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/ClassicLaunchpad/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="112" height="112" alt="Classic Launchpad icon">
</p>

<h1 align="center">Classic Launchpad</h1>

<p align="center">
  <strong>Bring the Launchpad you remember back to macOS 26.</strong>
</p>

<p align="center">
  A native, fluid, and fully local Launchpad recreation for macOS
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README_EN.md"><strong>English</strong></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26.0%2B-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS 26.0+">
  <img src="https://img.shields.io/badge/Swift-5.0-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="Swift 5.0">
  <img src="https://img.shields.io/badge/UI-AppKit-147EFB?style=for-the-badge" alt="AppKit">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Third--party_dependencies-0-31C653?style=flat-square" alt="No third-party dependencies">
  <img src="https://img.shields.io/badge/Data_processing-On_device-31C653?style=flat-square" alt="On-device data processing">
  <img src="https://img.shields.io/badge/Version-1.0.0-blue?style=flat-square" alt="Version 1.0.0">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT License">
</p>

<p align="center">
  <a href="#highlights">Highlights</a> ·
  <a href="#showcase">Showcase</a> ·
  <a href="#download">Download</a> ·
  <a href="#controls">Controls</a> ·
  <a href="#restore-layout">Restore Layout</a> ·
  <a href="#privacy">Privacy</a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/launchpad-overview.jpg" width="100%" alt="Classic Launchpad main screen">
</p>

<p align="center"><em>The familiar full-screen grid, page indicators, blurred wallpaper, and app layout.</em></p>

<a id="highlights"></a>

## ✨ Highlights

<table>
  <tr>
    <td width="33%" align="center">
      <h3>🖥️ Classic by Design</h3>
      <p>Inspired by Launchpad from macOS 15 and earlier, including its full-screen grid, pages, folders, and jiggle mode.</p>
    </td>
    <td width="33%" align="center">
      <h3>⚡ Native and Fluid</h3>
      <p>Built with Swift, AppKit, and Core Animation, with trackpad gestures, keyboard navigation, and multi-display support.</p>
    </td>
    <td width="33%" align="center">
      <h3>🔒 Local by Default</h3>
      <p>No accounts, telemetry, or cloud sync. App discovery, search, and layout storage stay entirely on your Mac.</p>
    </td>
  </tr>
</table>

Classic Launchpad is an independent third-party app built for macOS 26. It does not replace or modify any macOS system component; it simply provides a familiar, customizable way to launch apps.

### At a Glance

| | |
| --- | --- |
| 🔍 **Instant Search**<br>Find apps by localized name or bundle identifier. Just start typing. | 📁 **Folder Organization**<br>Stack icons into folders, rename them, reorder their contents, or move apps back out. |
| 🖱️ **Drag, Drop, and Pages**<br>Reorder within a page, drag across edges, swipe horizontally, and follow page indicators. | ⌨️ **Complete Keyboard Control**<br>Navigate with arrows, open with Return, go back with Escape, and change pages with Command + arrows. |
| 🔄 **Automatic Discovery**<br>Scans standard application locations and tracks local changes through Spotlight. | 💾 **Persistent Layout**<br>Automatically saves app order, pages, folder names, and the custom global shortcut. |
| ✨ **Native Visuals**<br>Builds a blurred background from the current desktop wallpaper and respects Reduce Motion. | 🗑️ **Safe Removal**<br>Only eligible Mac App Store apps can be moved to the Trash, always after confirmation. |

<a id="showcase"></a>

## 🪄 Showcase

<table>
  <tr>
    <td width="50%"><img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/folders.jpg" alt="Folders in Classic Launchpad"></td>
    <td width="50%"><img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/edit-mode.jpg" alt="Edit mode in Classic Launchpad"></td>
  </tr>
  <tr>
    <td align="center"><strong>Folders</strong><br>Open, rename, and organize apps inside folders</td>
    <td align="center"><strong>Edit Mode</strong><br>Drag to reorder and safely remove eligible apps</td>
  </tr>
</table>

<a id="download"></a>

## 📦 Download and Install

<p align="center">
  <a href="https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.dmg"><img src="https://img.shields.io/badge/Download-DMG-147EFB?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG"></a>
  <a href="https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.zip"><img src="https://img.shields.io/badge/Download-ZIP-555555?style=for-the-badge&logo=apple&logoColor=white" alt="Download ZIP"></a>
</p>

| Package | Best for | Installation |
| --- | --- | --- |
| [`ClassicLaunchpad.dmg`](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.dmg) | Recommended for most users | Open the DMG and drag `ClassicLaunchpad.app` into Applications |
| [`ClassicLaunchpad.zip`](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases/latest/download/ClassicLaunchpad.zip) | Portable archive | Extract it and drag `ClassicLaunchpad.app` into Applications |

Visit [Releases](https://github.com/Dreaming9420/Classic-Launchpad-macOS/releases) for every version, release notes, and previous packages.

### Requirements

- macOS 26.0 or later
- Prebuilt packages require neither Xcode nor third-party dependencies

Classic Launchpad appears automatically after its first launch. It runs as an accessory app and does not remain in the Dock.

<a id="quick-start"></a>

### Run from Source

Building from source requires Xcode 26.0 or later:

1. Download or clone this repository.
2. Open `ClassicLaunchpad.xcodeproj` in Xcode.
3. Select the `ClassicLaunchpad` scheme and the `My Mac` destination.
4. Press Command + R to build and run.

You can also open the project from its directory:

```bash
open ClassicLaunchpad.xcodeproj
```

<details>
<summary><strong>Move the built app into Applications</strong></summary>

1. Press Command + B in Xcode.
2. Select `Product` → `Show Build Folder in Finder`.
3. Find `ClassicLaunchpad.app` in the `Products` directory for the selected configuration.
4. Drag it into `/Applications`.

</details>

<a id="controls"></a>

## 🎮 Controls

| Action | Control |
| --- | --- |
| Show or hide Classic Launchpad | Control + Option + Space (customizable) |
| Change pages | Two-finger horizontal swipe, or Command + ← / → |
| Search apps | Start typing |
| Select an app or folder | Arrow keys |
| Open the selected item | Return |
| Close a folder, clear search, or dismiss Launchpad | Escape |
| Enter edit mode | Long-press an icon, or hold Option |
| Organize apps | Drag to reorder, change pages, or stack icons into a folder |
| Open Settings | Command + , |
| Quit the app | Command + Q |

Clicking the empty background or pressing the global shortcut again also dismisses Launchpad.

<a id="restore-layout"></a>

## ⚙️ Settings and Restore Default Layout

<p align="center">
  <img src="https://raw.githubusercontent.com/Dreaming9420/Classic-Launchpad-macOS/main/assets/readme/settings.png" width="560" alt="Classic Launchpad settings">
</p>

Record a new global shortcut without granting Accessibility permission.

### How to Restore the Default Layout

1. Show Classic Launchpad.
2. Press Command + , to open Settings.
3. Click “恢复默认布局” (Restore Default Layout).
4. Click “恢复” (Restore) in the confirmation dialog.

Classic Launchpad immediately regenerates and saves a layout based on the apps currently installed.

| Restored | Left unchanged |
| --- | --- |
| App order | Installed applications and their files |
| Page distribution | Current global shortcut |
| Folders and folder names | macOS system settings |

Restoring cannot be undone. Back up `Layout.json` first if you want to preserve the current layout.

<a id="privacy"></a>

## 🔐 Local Data and Privacy

The layout and shortcut configuration are stored at:

```text
~/Library/Application Support/QitaiClassicLaunchpad/Layout.json
```

- Application scanning, Spotlight metadata access, search, and layout storage all happen locally
- The current implementation contains no network requests, user accounts, telemetry, or cloud sync
- If the layout file becomes unreadable, it is preserved as a timestamped `Layout.corrupt-*.json` before a new layout is generated

### App Removal Boundaries

The remove button appears only when an app meets all of these conditions:

- It is installed in `/Applications` or `~/Applications`
- It contains a Mac App Store receipt
- It is not a system app

The app asks for confirmation before using the macOS system API to move an application to the Trash. Other apps do not display the remove button.

## 🧩 Under the Hood

| Area | Implementation |
| --- | --- |
| UI and animation | AppKit, Core Animation, Core Image |
| App discovery | File-system scanning, Spotlight `NSMetadataQuery` |
| Global shortcut | Carbon Hot Key API |
| Launch and removal | `NSWorkspace` |
| Local storage | Codable JSON with atomic writes |

The main source is under `ClassicLaunchpad/`, and the complete `.app` should be built from `ClassicLaunchpad.xcodeproj`. A `Package.swift` manifest is also included for source checks and Swift Package Manager builds.

## 📌 Known Limitations

- The app interface is currently available in Simplified Chinese only
- Layout data does not sync between Macs
- App removal is limited to eligible Mac App Store applications

## 🤝 Contributing

Reproducible bug reports and focused improvement proposals are welcome through Issues. Pull Requests should stay narrowly scoped and build successfully with Xcode before submission.

## 📄 License

This project is available under the [MIT License](./LICENSE). You may use, copy, modify, and distribute it as long as the original copyright and license notice are preserved.

## Disclaimer

Classic Launchpad is an independently developed third-party project and is not affiliated with or endorsed by Apple Inc. Apple, macOS, and Launchpad are trademarks of Apple Inc.

<p align="center"><sub>Made for people who miss the classic Launchpad.</sub></p>
