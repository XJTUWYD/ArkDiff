# AegisDiff — 鸿蒙代码差异对比工具

> 纯 ArkTS + ArkUI + Stage 模型 | HarmonyOS 5.0+

## 简介

AegisDiff 是一款面向 HarmonyOS 开发者的轻量级移动端代码差异对比工具。支持离线 Diff 运算、行级差异标注和差异导航，让代码审查在任何场景下随时可做。

## 功能特性

- ✅ **双栏输入** — 左右两栏分别输入原始代码和修改后代码
- ✅ **行级 Diff** — 基于逐行对比算法，支持新增/删除/修改/未变更四种差异类型着色
- ✅ **差异统计** — 实时显示新增行数、删除行数、修改行数、相似度百分比
- ✅ **粘贴示例** — 一键填充 ArkTS 组件重构对比示例，即开即用
- ✅ **差异导航** — 前进/后退按钮遍历所有差异块
- ✅ **视图切换** — 支持 Unified（统一）视图
- ✅ **文件导入** — 从系统文件管理器导入 .ets/.ts 文件
- ✅ **设置页** — 颜色模式（浅色/深色/自动）、字体大小调节
- ✅ **完全离线** — 无网络依赖、无 NAPI/C++/WebView

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK API 12+
- 目标设备：2in1 / 平板 / 手机

### 安装

```bash
# 克隆项目
git clone <repo-url> codecompare

# 使用 DevEco Studio 打开项目
# 选择 entry 模块 → Run 'entry' 到模拟器或真机
```

### 使用说明

1. 打开应用进入 Diff 编辑页
2. 左右两栏分别粘贴原始代码和修改后代码（或点击 📋 粘贴示例）
3. 点击「执行对比」按钮
4. 查看差异结果：绿色=新增、红色=删除、黄色=修改
5. 使用底部导航按钮逐差异块查看
6. 点击 ⚙ 进入设置页调整颜色模式和字体大小

## 项目结构

```
entry/src/main/ets/
├── engine/              # Diff 引擎层
│   ├── LineParser.ets       # 行解析器
│   ├── LcsEngine.ets        # LCS 最长公共子序列算法
│   ├── MyersEngine.ets      # Myers 差分算法（大规模文本）
│   ├── DiffEngine.ets       # Diff 编排器
│   ├── DiffBlockLocator.ets # 差异块定位器
│   └── StatsCalculator.ets  # 统计计算器
├── model/
│   └── DiffModels.ets       # 核心数据模型（类型定义）
├── viewmodel/
│   └── DiffViewModel.ets    # 状态管理 ViewModel
├── components/          # UI 组件
│   ├── DiffToolbar.ets      # 顶部工具栏
│   ├── InputPanel.ets       # 双栏输入面板
│   ├── DiffNavigator.ets    # 底部差异导航栏
│   ├── DiffLineItem.ets     # 单行差异渲染
│   ├── UnifiedDiffView.ets  # 统一视图
│   └── SideBySideDiffView.ets # 分栏视图
├── pages/
│   ├── SplashPage.ets       # 启动页
│   ├── DiffEditorPage.ets   # ★ 核心 Diff 编辑页
│   └── SettingsPage.ets     # 设置页
└── utils/
    ├── ThemeTokens.ets      # 主题颜色与尺寸常量
    ├── ThemeColors.ets      # 主题颜色管理器
    └── SampleDataProvider.ets # 示例数据
```

## 技术架构

```
ArkUI Layer (组件层)
    ↓
State Management Layer (状态管理)
    ↓
Engine Layer (Diff 引擎)
    ↓
Platform Capabilities (系统能力)
```

## 已知限制

- MVP 阶段使用逐行对比算法（未启用 LCS 重排），行序变化时可能不够精确
- Side-by-Side 视图和 LazyForEach 虚拟列表将在 v1.1 版本完善
- 当前仅支持行级 Diff，字符级 Diff 计划在 v1.2 版本实现

## 开发计划

| 版本 | 计划 |
|------|------|
| v1.0 | MVP：双栏输入、行级Diff、差异统计、导航 |
| v1.1 | Side-by-Side 视图、LCS/Myers 算法集成、LazyForEach |
| v1.2 | 字符级 Diff、语法高亮、分享导出 |

## License

MIT
