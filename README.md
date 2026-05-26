# AegisDiff — 鸿蒙代码差异对比工具

> 纯 ArkTS + ArkUI + Stage 模型 | HarmonyOS 5.0+

## 简介

AegisDiff 是一款面向 HarmonyOS 开发者的轻量级移动端代码差异对比工具。内置 Myers / LCS 差分引擎，支持行级+字符级差异标注、语法高亮、三路合并、目录对比，以及 Meld 风格差异概览导航。完全离线，无 NAPI / C++ / WebView 依赖。

## 功能特性

### 🔍 核心对比

- ✅ **双引擎 Diff** — Myers 算法（大规模文本）+ LCS 算法（精细对比），自动选择最优策略
- ✅ **行级 Diff** — 新增/删除/修改/未变更四种差异类型着色（绿色/红色/黄色）
- ✅ **字符级 Diff** — 行内细粒度差异高亮，精确到字符级别
- ✅ **三路合并** — 支持 base / ours / theirs 三路合并视图
- ✅ **差异统计** — 实时显示新增/删除/修改行数、相似度百分比

### 🎨 界面与视图

- ✅ **统一视图** — 类 GitHub PR 风格 Unified View
- ✅ **分栏视图** — Side-by-Side 左右分栏对比
- ✅ **合并视图** — 冲突块可视化与逐块合并选择
- ✅ **差异概览条** — Meld 风格右侧差异位置指示器，点击跳转
- ✅ **差异块折叠** — >8 行未变更区域自动折叠，减少视觉干扰
- ✅ **多主题** — 浅色/深色/Monokai/自动 四种颜色模式

### 📂 输入方式

- ✅ **双栏输入** — 左右两栏分别输入原始代码和修改后代码
- ✅ **粘贴示例** — 一键填充 ArkTS 组件重构对比示例
- ✅ **文件导入** — 从系统文件管理器导入 .ets / .ts 文件
- ✅ **编码支持** — UTF-8 自动检测，导出 Unified Diff 格式

### 🔎 导航与辅助

- ✅ **差异导航** — 前进/后退按钮逐块遍历差异 + 快捷键 (Ctrl+N)
- ✅ **搜索高亮** — 行内关键词搜索与高亮定位 (Ctrl+F)
- ✅ **语法高亮** — ArkTS / TypeScript 关键词着色
- ✅ **同步按钮** — 分栏视图中一键同步左右差异行
- ✅ **响应式布局** — 自适应手机/平板/2in1 不同断点

### 📊 目录对比

- ✅ **文件目录对比** — 选择两个文件夹，按文件名匹配对比
- ✅ **相似度排序** — 按相似度百分比排序，快速定位差异最大的文件
- ✅ **点击跳转** — 点击文件对直接进入详情 Diff 视图

### 🔧 其他

- ✅ **设置页** — 颜色模式、字体大小、引擎策略调节
- ✅ **完全离线** — 无网络、无 NAPI / C++ / WebView 依赖
- ✅ **剪贴板导出** — 一键复制 Unified Diff 到系统剪贴板

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK API 12+
- 目标设备：2in1 / 平板 / 手机

### 安装

```bash
# 克隆项目
git clone https://gitee.com/lyndonwei/codediff.git codecompare

# 使用 DevEco Studio 打开项目
# 选择 entry 模块 → Run 'entry' 到模拟器或真机
```

### 使用说明

1. 打开应用进入 Diff 编辑页
2. 左右两栏分别粘贴原始代码和修改后代码（或点击 📋 粘贴示例）
3. 点击「执行对比」按钮（或按 Ctrl+D）
4. 查看差异结果：
   - 🟢 绿色 = 新增
   - 🔴 红色 = 删除
   - 🟡 黄色 = 修改
   - ⬜ 灰色 = 未变更
5. 使用底部导航栏或概览条逐差异块查看
6. 工具栏切换统一/分栏视图
7. 点击 ⚙ 进入设置页调整主题和字体

#### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl + D` | 执行对比 |
| `Ctrl + F` | 搜索 |
| `Ctrl + N` | 下一差异块 |

## 项目结构

```
entry/src/main/ets/
├── engine/                   # Diff 引擎层
│   ├── DiffEngine.ets             # Diff 编排器（Myers + LCS 混合策略）
│   ├── MyersEngine.ets            # Myers 差分算法（大规模文本首选）
│   ├── LcsEngine.ets              # LCS 最长公共子序列（精确对齐）
│   ├── CharDiffEngine.ets         # 字符级 Diff（行内细粒度差异）
│   ├── DiffBlockLocator.ets       # 差异块定位与跳转
│   ├── MergeEngine.ets            # 三路合并引擎
│   ├── TokenHighlighter.ets       # ArkTS / TypeScript 语法高亮
│   ├── LineParser.ets             # 行解析器
│   └── StatsCalculator.ets        # 差异统计计算
├── model/
│   └── DiffModels.ets             # 核心数据模型与类型定义
├── viewmodel/
│   └── DiffViewModel.ets          # 状态管理 ViewModel
├── components/               # 复用 UI 组件
│   ├── DiffToolbar.ets            # 顶部工具栏
│   ├── InputPanel.ets             # 双栏输入面板
│   ├── DiffNavigator.ets          # 底部差异导航栏
│   ├── DiffLineItem.ets           # 单行差异渲染
│   ├── DiffStatsBar.ets           # 差异统计横条
│   ├── DiffOverviewBar.ets        # Meld 风格差异概览条
│   ├── UnifiedDiffView.ets        # 统一视图容器
│   └── SideBySideDiffView.ets     # 分栏视图容器
├── pages/                    # 页面
│   ├── SplashPage.ets             # 启动页
│   ├── DiffEditorPage.ets         # ★ 核心 Diff 编辑页
│   ├── MergePage.ets              # 三路合并页
│   ├── FolderDiffPage.ets         # 文件夹组合对比页
│   ├── DirectoryDiffPage.ets      # 目录选择对比页
│   └── SettingsPage.ets           # 设置页
├── utils/                    # 工具函数
│   ├── ThemeTokens.ets            # 主题颜色与尺寸常量
│   ├── ThemeColors.ets            # 主题颜色管理器
│   ├── SampleDataProvider.ets     # 示例数据
│   ├── BreakpointUtil.ets         # 响应式断点工具
│   └── FileUtils.ets              # 文件读取与编码
├── entryability/
│   └── EntryAbility.ets           # 应用入口
└── entrybackupability/
    └── EntryBackupAbility.ets     # 备份恢复能力
```

## 技术架构

```
┌─────────────────────────────────┐
│       ArkUI Layer (组件层)       │
│  UnifiedView / SideBySideView   │
├─────────────────────────────────┤
│   State Management (状态管理)    │
│    DiffViewModel / @State       │
├─────────────────────────────────┤
│     Engine Layer (引擎层)        │
│  DiffEngine → Myers / LCS       │
│  CharDiffEngine / MergeEngine   │
│  TokenHighlighter / StatsCalc   │
├─────────────────────────────────┤
│  Platform Capabilities (系统)    │
│  文件选择 / 剪贴板 / 应用沙箱    │
└─────────────────────────────────┘
```

## 版本演进

| 版本 | 内容 |
|------|------|
| v1.0 | 双栏输入、行级 Diff、差异统计、导航 |
| v1.1 | Side-by-Side 视图、Myers/LCS 引擎、搜索高亮、主题设置 |
| v1.2 | 字符级 Diff、语法高亮、三路合并、文件导出 |
| v1.3 | 目录对比、差异概览条、差异块折叠、响应式布局、编码支持 |

## License

MIT
