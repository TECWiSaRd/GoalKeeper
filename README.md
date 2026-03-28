# GoalKeeper — AI-Powered Goal & Assignment Tracker for macOS

GoalKeeper is a macOS app that uses Claude AI to help you plan goals, track assignments, and study smarter. It features a three-column layout inspired by Apple Calendar, activity-ring progress tracking, and a built-in update system.

---

## Features

### Goals
- Create goals with a title, description, type, priority, and optional due date
- Attach a rubric or image for Claude to analyze
- Claude breaks your goal into 4–8 ordered steps with time estimates and tips
- Track step completion — rings update in real time
- Re-analyze any goal at any time from the toolbar

### Homework Schedule
- Import a schedule by pasting text or attaching a photo
- Claude extracts all assignments, tests, and quizzes with their due dates and subjects
- Review and edit extracted items before saving
- Items are grouped by subject in the sidebar and shown as dots on the calendar

### Study Guides
- Automatically offered for tests, quizzes, and review assignments
- Claude researches the topic and generates a full structured study guide
- Three tabs: **Study Guide** (collapsible sections + key points), **Practice** (tap-to-reveal Q&A), **Tips**
- Guides are saved and persist between sessions — regenerate anytime

### Calendar
- Apple Calendar-style month grid
- Goal dots and schedule dots shown per day
- Summary rings for overall progress across active goals

### Progress Rings
- Three concentric rings per goal (like Apple Fitness):
  - **Outer** — overall completion %
  - **Middle** — steps completed
  - **Inner** — time elapsed toward due date (turns red when overdue)

### Settings
- **API Key** — securely stored in the macOS Keychain
- **AI Model** — choose between Haiku, Sonnet, and Opus
- **Updates** — check for and install updates directly in the app

### In-App Updates
- Checks your GitHub repo for a new `version.json` on every Settings open
- Downloads and installs `GoalKeeper.zip` automatically
- Replaces the existing app in-place — no duplicates

---

## How to Install (In 4 Steps!)

  1. Download [GoalKeeper.zip](./GoalKeeper.zip)

  2. Unzip the file

  3. Move GoalKeeper.app to your Applications folder

  4. Obtain a Claude API key at [platform.claude.com](https://platform.claude.com)

  5. Open the app from your Applications folder

  6. Your Mac will display an error message "MacOS cannot verify that this app is free from malware". To resolve this, go to System Settings →   Privacy & Security → scroll all the way down → click "Open Anyway" or type "xattr -cr /Applications/GoalKeeper.app" in Terminal

  7. Paste your API key in the GoalKeeper settings menu by pressing (⌘ + ,) on your keyboard

  8. While you're in the GoalKeeper settings menu, change the Claude model to your preference and check for updates

  9. You're all set!

---

## 🚀 Xcode Setup

### 1. Create a New Project
- Xcode → **File → New → Project → macOS → App**
- Language: **Swift**, Interface: **SwiftUI**
- Name: `GoalKeeper`

### 2. Add the Swift Files
Drag all `.swift` files into your Xcode project. When prompted, make sure **"Copy items if needed"** is checked.

| File | Role |
|---|---|
| `GoalPlannerApp.swift` | App entry point |
| `Models.swift` | All data models |
| `GoalStore.swift` | State + persistence |
| `AnthropicService.swift` | Claude API calls |
| `KeychainService.swift` | Secure API key + model preference storage |
| `ProgressRingView.swift` | Activity ring components |
| `ContentView.swift` | 3-column `NavigationSplitView` root |
| `SidebarView.swift` | Left column — goals + grouped schedule |
| `CalendarDashboardView.swift` | Middle column — calendar + rings |
| `GoalDetailView.swift` | Right column — goal steps + AI summary |
| `ScheduleDetailView.swift` | Right column — assignment detail + upcoming |
| `StudyGuideView.swift` | Study guide sheet with tabs |
| `AddGoalView.swift` | New goal sheet |
| `ImportScheduleView.swift` | Schedule import sheet |
| `SettingsView.swift` | API key, model picker, update checker |
| `UpdateService.swift` | GitHub update checker + ZIP installer |

> Delete the auto-generated `ContentView.swift` and `Item.swift` that Xcode creates.

### 3. Set Your API Key (at runtime)
Launch the app → **GoalKeeper → Settings (⌘,)** → paste your Anthropic API key.

Get a free key at [console.anthropic.com](https://console.anthropic.com). New accounts receive $5 in free credits.

### 4. Configure the Update URL
In `UpdateService.swift`, replace the placeholder with your GitHub raw URL:
```swift
static let manifestURL = "https://raw.githubusercontent.com/YOUR_USERNAME/GoalKeeper/main/version.json"
```

### 5. App Sandbox
Target → **Signing & Capabilities** → remove **App Sandbox** (required for the in-app update installer to replace the app binary).

### 6. Set Minimum Deployment Target
Target → **General** → Minimum Deployments → **macOS 14.0**

### 7. Build & Run
Select **My Mac** and press ▶.

---

## 🔑 API Key & Cost

GoalKeeper uses the Anthropic Claude API. Each user enters their own key in Settings — keys are stored in the macOS Keychain, never hardcoded.

**Approximate cost per request:**

| Model | Cost per analysis |
|---|---|
| Haiku (recommended) | ~$0.01 |
| Sonnet | ~$0.03–0.05 |
| Opus | ~$0.05–0.10 |

Study guides use more tokens (~4,000 max) so cost slightly more than goal analyses.

---

## 📦 Releasing Updates

1. Bump **Version** in Xcode → General (e.g. `1.0.1`)
2. Bump **Build** by 1
3. **⇧⌘K** clean → **Product → Archive → Custom → Copy App → Sign to Run Locally → Export**
4. In Terminal:
```bash
cd ~/Downloads/GoalKeeper
zip -r GoalKeeper.zip GoalKeeper.app
ls -lh GoalKeeper.zip  # confirm several MB
```
5. On GitHub, create a new Release with the version as the tag and upload `GoalKeeper.zip`
6. Edit `version.json` in your repo:
```json
{
  "version": "1.0.1",
  "url": "https://github.com/YOUR_USERNAME/GoalKeeper/releases/download/1.0.1/GoalKeeper.zip",
  "notes": "What changed in this version."
}
```

Users will see the update next time they open Settings (⌘,).

---

## 📤 Sharing with Friends

1. Export the app and zip it using the steps above
2. Send `GoalKeeper.zip` — they unzip and move `GoalKeeper.app` to `/Applications`
3. First launch only — open Terminal and run:
```bash
xattr -cr /Applications/GoalKeeper.app
```
4. Open GoalKeeper → Settings → paste their own Anthropic API key
5. Future updates happen automatically inside the app

---

## 🏗 Architecture

```
GoalKeeperApp
├── GoalStore            ← ObservableObject, single source of truth
├── AnthropicService     ← async/await API, goal analysis, schedule parsing, study guides
├── KeychainService      ← API key + model preference storage
├── UpdateService        ← GitHub version check + ZIP installer
└── ContentView (NavigationSplitView)
    ├── SidebarView               ← goals list + grouped schedule subjects
    ├── CalendarDashboardView     ← month grid, summary rings, due items
    └── Detail (routed by store.detailSelection)
        ├── GoalDetailView        ← steps, tips, rings, re-analyze
        └── ScheduleDetailView    ← assignment detail, upcoming, study guide
            └── StudyGuideView    ← tabbed study guide sheet
    AddGoalView (sheet)           ← form, rubric, image, AI preview
    ImportScheduleView (sheet)    ← paste/photo, Claude extracts items
    SettingsView (⌘,)             ← API key, model, update checker
```

---

## Requirements
- macOS 14.0 (Sonoma) or later
- Xcode 15.0+
- Swift 5.9+
- Anthropic API key ([console.anthropic.com](https://console.anthropic.com))
- GitHub account (for update distribution)
