# GoalPlanner — macOS

AI-powered goal & assignment tracker for macOS. Uses Claude to analyze goals and build step-by-step plans, with a three-column layout (sidebar, calendar, detail) and Apple Fitness-style progress rings.

---

### Notes: 
- The app download itself is available. Only observe this README if you are planning to import the raw files to Xcode and build your own version of GoalKeeper.

- This app is **only compatible with MacOS 26.0 and newer**.

---

## 🚀 Xcode Setup

### 1. Create a New Project
- Xcode → **File → New → Project**
- Choose **macOS → App**
- Language: **Swift**, Interface: **SwiftUI**
- Name: `GoalPlanner`

### 2. Add the Files
Copy all `.swift` files into your Xcode project. When dragging in, ensure "Copy items if needed" is checked.

| File | Role |
|---|---|
| `GoalPlannerApp.swift` | App entry point (replace the generated one) |
| `Models.swift` | `Goal`, `GoalStep`, `GoalType`, etc. |
| `GoalStore.swift` | ObservableObject state + UserDefaults |
| `AnthropicService.swift` | Claude API (NSImage, async/await) |
| `ProgressRingView.swift` | Activity rings |
| `ContentView.swift` | `NavigationSplitView` root |
| `SidebarView.swift` | Left column: goal list |
| `CalendarDashboardView.swift` | Middle column: calendar + rings |
| `GoalDetailView.swift` | Right column: steps + detail |
| `AddGoalView.swift` | New-goal sheet |
| `KeychainService.swift` | Stores Claude API key |
| `SettingsView.swift` | Settings menu |
| `UpdateService.swift` | Performs app updates |
| `Contents.json` | Replaces the `Contents.json' in GoalKeeper → Assets.xcassets → AppIcon.appiconset |
> Delete the auto-generated `ContentView.swift` (or replace it with ours).

### 3. Set Your API Key
Open `AnthropicService.swift` and replace:
```swift
static let apiKey = "YOUR_ANTHROPIC_API_KEY_HERE"
```
with your key from [console.anthropic.com](https://console.anthropic.com).

> **Security tip:** Store the key in a `Config.xcconfig` and reference it via `Bundle.main.infoDictionary` for production builds.

### 4. Configure the Target
In **Signing & Capabilities**, you may need:
- **App Sandbox** → enable **Outgoing Connections (Client)** for the Anthropic API
- **App Sandbox** → enable **User Selected File (Read)** for image attachment via NSOpenPanel

These are added automatically by Xcode's sandbox defaults, but double-check if API calls fail.

### 5. Set Minimum Deployment Target
- Target → **General** → Minimum Deployments → **macOS 14.0**

### 6. Build & Run
Select **My Mac** as the destination and press ▶.

---

## ✨ Features

- **3-column NavigationSplitView** — sidebar (goals), calendar (middle), detail (right)  
- **Apple Fitness-style rings** — 3 concentric rings: overall %, step completion, time urgency  
- **Claude AI analysis** — describe your goal, optionally attach a rubric or image → Claude returns an ordered JSON plan with time estimates and tips  
- **macOS-native file picker** — `NSOpenPanel` for image attachment (no PhotosUI dependency)  
- **Toolbar re-analyze** — click ✦ in the detail toolbar to regenerate the AI plan for any goal  
- **Right-click to delete** — context menu on sidebar rows  
- **⌘N keyboard shortcut** — open new-goal sheet from anywhere  
- **Persistent storage** — `UserDefaults` with JSON encoding, survives restarts  
- **Sample goals** — pre-loaded on first launch so the UI is immediately explorable

---

## 🏗 Architecture

```
GoalPlannerApp
├── GoalStore            ← ObservableObject, single source of truth
├── AnthropicService     ← async/await API, NSImage → base64
└── ContentView (NavigationSplitView)
    ├── SidebarView          ← goal list, grouped
    ├── CalendarDashboardView ← month grid, summary rings
    └── GoalDetailView       ← steps, tips, meta, re-analyze
        AddGoalView (sheet)  ← form, NSOpenPanel, AI preview
```

---

## Requirements
- macOS 14.0 (Sonoma) or later  
- Xcode 15.0+  
- Swift 5.9+  
- Anthropic API key
