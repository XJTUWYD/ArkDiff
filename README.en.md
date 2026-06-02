# ArkDiff — Meld-style Diff Tool for HarmonyOS

> Pure ArkTS + ArkUI + NAPI(C++) | HarmonyOS 5.0+

[中文版](README.md)

## Overview

ArkDiff is a lightweight code diff tool for HarmonyOS. Built-in C++ Myers diff engine (NAPI-accelerated), side-by-side view, inline editing, block-level sync, and Meld-style overview navigation.

## Features

### Core Diff

- **Dual-engine diff** — Auto-switch to C++ NAPI Myers for 200+ lines (10-50x faster), ArkTS LCS for smaller files
- **Line-level diff** — Add/delete/modify/unchanged with color coding (green/red/yellow)
- **Character-level diff** — Inline granular highlighting
- **In-place patch** — Edit/sync directly modifies `diffResult`, skipping full re-diff
- **Diff statistics** — Real-time counts and similarity percentage

### UI & Views

- **Side-by-side view** — Left/right split comparison (only view mode)
- **Overview bar** — Meld-style diff position indicator, click to jump
- **Gap collapsing** — Auto-collapse >8 unchanged lines
- **Multi-theme** — Light / Dark / Monokai
- **LazyForEach** — Virtual list rendering for large files

### Input

- **Meld-style empty panels** — Two blank TextAreas on launch, paste or open files directly
- **Sample code** — One-click fill with ArkTS refactoring example
- **File import** — System file picker for any text file
- **Encoding support** — UTF-8 / GBK / BOM auto-detection

### Navigation & Editing

- **Diff navigation** — ▲▼ buttons per block
- **Block-level sync** — Consecutive same-type lines share one arrow, sync entire block
- **Inline editing** — Click to edit in-place, seamless TextInput
- **Search & highlight** — Inline keyword search (Ctrl+F)
- **Syntax highlighting** — ArkTS / TypeScript / Python / Java / C/C++ / JS
- **Responsive layout** — Phone / tablet / 2-in-1 breakpoints

### Directory Comparison

- **File collection diff** — Select two file groups, compare by path
- **Sort & filter** — By name / status / similarity
- **Tree navigation** — Expand/collapse directories, click to open diff

### Export

- **Clipboard** — Copy as unified diff
- **File save** — Export as .patch
- **Undo/Redo** — 50-operation history

## Quick Start

### Prerequisites

- DevEco Studio 5.0+
- HarmonyOS SDK API 12+
- Target: 2-in-1 / tablet / phone

### Install

```bash
git clone https://github.com/XJTUWYD/ArkDiff.git
# Open in DevEco Studio, Run 'entry' to emulator or device
```

### Usage

1. Open the app, enter "Text Diff" or "File Diff"
2. Paste or open original and modified code in the two panels
3. Click ⟳ to run diff
4. Green = added, red = deleted, yellow = modified
5. Use ▲▼ to navigate diff blocks
6. Click → or ← to sync changes across sides
7. Click inline text to edit in-place
8. ⌕ to search, ⇱ to export

### Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl+S` | Run diff |
| `Ctrl+F` | Search |
| `Esc` | Cancel edit / close search |

## Project Structure

```
entry/src/main/
├── cpp/                        # C++ NAPI engine
│   ├── myers_diff.cpp               # Myers shortest edit script
│   ├── napi_init.cpp                 # NAPI bridge
│   ├── CMakeLists.txt                # Native build config
│   └── types/libmyers_diff_napi/     # TS type declarations
├── ets/
│   ├── engine/                  # Diff engine layer
│   │   ├── DiffEngine.ets            # Diff orchestrator (cache + optimized merge)
│   │   ├── MyersEngine.ets           # Myers algorithm (prefer C++ NAPI)
│   │   ├── LcsEngine.ets             # LCS (Dynamic Programming)
│   │   ├── CharDiffEngine.ets        # Char-level diff
│   │   ├── DiffBlockLocator.ets      # Block locator
│   │   ├── TokenHighlighter.ets      # Multi-language syntax highlighting
│   │   ├── LineParser.ets            # Line parser
│   │   ├── FilterRuleEngine.ets      # Filter rules
│   │   └── StatsCalculator.ets       # Stats calculator
│   ├── model/DiffModels.ets          # Core data models
│   ├── viewmodel/
│   │   └── DiffSessionViewModel.ets  # State mgmt (inline edit/block sync/undo+redo)
│   ├── components/              # UI components
│   │   ├── DiffToolbar.ets           # Toolbar
│   │   ├── DiffNavigator.ets         # Bottom navigation
│   │   ├── DiffOverviewBar.ets       # Overview bar
│   │   ├── SideBySideRenderer.ets    # SBS line renderer
│   │   └── DiffSearchBar.ets         # Search bar
│   ├── pages/                   # Pages
│   │   ├── SplashPage.ets            # Splash
│   │   ├── WorkspaceHomePage.ets     # Workspace hub
│   │   ├── DiffEditorPage.ets        # ★ Main SBS editor
│   │   ├── FolderDiffPage.ets        # File selector → editor
│   │   ├── DirectoryDiffPage.ets     # File collection diff
│   │   ├── MultiTabDiffPage.ets      # Multi-tab workspace
│   │   └── SettingsPage.ets          # Settings
│   ├── services/                # Services
│   │   ├── FileContentService.ets    # Unified file reader (encoding/BOM/GBK)
│   │   ├── SessionManager.ets        # Tab session management
│   │   └── BinaryFileHandler.ets     # Binary file handler
│   └── utils/                   # Utilities
│       ├── ThemeTokens.ets           # Theme color constants
│       ├── ThemeColors.ets           # Theme manager
│       ├── SampleDataProvider.ets    # Sample data
│       └── BreakpointUtil.ets        # Responsive breakpoints
```

## Architecture

```
┌────────────────────────────────────┐
│       ArkUI Layer                  │
│   SideBySideRenderer (LazyForEach) │
├────────────────────────────────────┤
│   ViewModel                        │
│   DiffSessionViewModel             │
├────────────────────────────────────┤
│   Engine Layer                     │
│   DiffEngine                       │
│   ├─ MyersEngine (NAPI C++)        │
│   └─ LcsEngine (ArkTS fallback)    │
│   CharDiffEngine / FilterRule      │
│   TokenHighlighter / StatsCalc     │
├────────────────────────────────────┤
│   Services                         │
│   FileContentService / SessionMgr  │
├────────────────────────────────────┤
│   Platform                         │
│   File Picker / Clipboard / AppStorage │
└────────────────────────────────────┘
```

## Performance

| Optimization | Description |
|-------------|-------------|
| C++ NAPI Myers | 200+ lines auto-switch to C++, 10-50x faster |
| LazyForEach | Only render ~30 visible rows, not full ForEach |
| Parse cache | Skip `parseLines` when text unchanged |
| In-place patch | Edit/sync modifies `diffResult` directly, no full re-diff |
| O(n²)→O(n) | `backtrack` unshift → push + reverse |

## Contributing

Pull requests welcome. Good starting points:

- 🐛 Bug fixes
- ✨ Add language syntax highlighting (edit `TokenHighlighter.ets`)
- 🎨 New theme colors (see `getMonokaiColors` in `ThemeTokens.ets`)
- ⚡ NAPI C++ performance (`myers_diff.cpp`)
- 📱 Foldable / portrait layout enhancements
- 🧪 Unit tests (`src/test/`)

Please ensure `entry` module compiles before submitting PR.

## License

ArkDiff is licensed under the **GNU Affero General Public License v3 (AGPL-3.0)**.

- Personal use, study, modification, source distribution → Free
- **Commercial use** (SaaS, embedded in commercial products) → Contact the author for a commercial license
- Modified versions used as network services must disclose source code

[View full license](LICENSE)
