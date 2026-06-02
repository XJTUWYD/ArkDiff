# ArkDiff — 鸿蒙代码差异对比工具

> 纯 ArkTS + ArkUI + NAPI(C++) | HarmonyOS 5.0+

## 简介

AegisDiff 是一款面向 HarmonyOS 开发者的轻量级代码差异对比工具。内置 C++ Myers 差分引擎（NAPI 加速），支持分栏视图、行内编辑、块级同步、目录对比，以及 Meld 风格差异概览导航。

## 功能特性

### 核心对比

- **双引擎 Diff** — >200 行自动切换 C++ NAPI Myers（10-50x 加速），≤200 行 ArkTS LCS（精确 DP）
- **行级 Diff** — 新增/删除/修改/未变更四种差异类型着色（绿/红/黄）
- **字符级 Diff** — 行内细粒度差异高亮，精确到字符级别
- **原地 Patch** — 行内编辑/块同步直接修改 diffResult，跳过全量 re-diff
- **差异统计** — 实时显示新增/删除/修改行数、相似度百分比

### 界面与视图

- **分栏视图** — Side-by-Side 左右分栏对比（唯一的视图模式）
- **差异概览条** — Meld 风格右侧差异位置指示器，点击跳转
- **差异块折叠** — >8 行未变更区域自动折叠
- **多主题** — 浅色 / 深色 / Monokai 三种颜色模式
- **LazyForEach** — 虚拟列表渲染，大文件滚动不卡顿

### 输入方式

- **Meld 风格空栏** — 打开即显示左右两个空 TextArea，可直接粘贴或打开文件
- **粘贴示例** — 一键填充 ArkTS 组件重构对比示例
- **文件导入** — 从系统文件管理器导入任意文本文件
- **编码支持** — UTF-8 / GBK / BOM 自动检测

### 导航与辅助

- **差异导航** — ▲▼ 按钮逐块遍历差异
- **块级同步** — 连续同类型行共享一个箭头，点击一次同步整块
- **行内编辑** — 点击行即可原地编辑，无缝 TextInput 体验
- **搜索高亮** — 行内关键词搜索与定位（Ctrl+F）
- **语法高亮** — ArkTS / TypeScript / Python / Java / C/C++ / JS
- **响应式布局** — 自适应手机/平板/2in1

### 目录对比

- **文件目录对比** — 选择两组文件，按路径匹配对比
- **相似度排序** — 按名称/状态/相似度排序
- **树状导航** — 目录树展开/折叠，点击文件跳转详情

### 导出

- **剪贴板导出** — 一键复制 Unified Diff 格式
- **文件保存** — 导出为 .patch 文件
- **撤销/重做** — 50 步操作历史

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK API 12+
- 目标设备：2in1 / 平板 / 手机

### 安装

```bash
git clone https://gitee.com/lyndonwei/codediff.git
# 使用 DevEco Studio 打开，Run 'entry' 到模拟器或真机
```

### 使用说明

1. 打开应用，进入「文本临时比较」或「文件比较」
2. 左右两栏粘贴/打开原始代码和修改后代码
3. 点击 ⟳ 执行对比
4. 查看差异结果：绿色=新增，红色=删除，黄色=修改
5. 使用底部 ▲▼ 导航逐差异块查看
6. 点击 → 或 ← 同步差异到另一侧
7. 点击行内文本可原地编辑
8. ⌕ 搜索内容，⇱ 导出结果

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+S` | 执行对比 |
| `Ctrl+F` | 搜索 |
| `Esc` | 取消编辑 / 关闭搜索 |

## 项目结构

```
entry/src/main/
├── cpp/                        # C++ NAPI 原生引擎
│   ├── myers_diff.cpp               # Myers 最短编辑脚本
│   ├── napi_init.cpp                 # NAPI 桥接层
│   ├── CMakeLists.txt                # 原生构建配置
│   └── types/libmyers_diff_napi/     # TS 类型声明
├── ets/
│   ├── engine/                  # Diff 引擎层
│   │   ├── DiffEngine.ets            # Diff 编排器（解析缓存+优化合并）
│   │   ├── MyersEngine.ets           # Myers 算法（优先 C++ NAPI）
│   │   ├── LcsEngine.ets             # LCS 最长公共子序列
│   │   ├── CharDiffEngine.ets        # 字符级 Diff
│   │   ├── DiffBlockLocator.ets      # 差异块定位
│   │   ├── TokenHighlighter.ets      # 多语言语法高亮
│   │   ├── LineParser.ets            # 行解析器
│   │   ├── FilterRuleEngine.ets      # 过滤规则引擎
│   │   └── StatsCalculator.ets       # 差异统计
│   ├── model/
│   │   └── DiffModels.ets            # 核心数据模型
│   ├── viewmodel/
│   │   └── DiffSessionViewModel.ets  # 状态管理（inline edit/block sync/undo+redo）
│   ├── components/              # UI 组件
│   │   ├── DiffToolbar.ets           # 工具栏
│   │   ├── DiffNavigator.ets         # 底部导航栏
│   │   ├── DiffOverviewBar.ets       # 差异概览条
│   │   ├── SideBySideRenderer.ets    # 分栏行渲染
│   │   └── DiffSearchBar.ets         # 搜索栏
│   ├── pages/                   # 页面
│   │   ├── SplashPage.ets            # 启动页
│   │   ├── WorkspaceHomePage.ets     # 工作台入口
│   │   ├── DiffEditorPage.ets        # ★ 核心分栏编辑页
│   │   ├── FolderDiffPage.ets        # 文件选择→跳转编辑页
│   │   ├── DirectoryDiffPage.ets     # 文件集合目录对比
│   │   ├── MultiTabDiffPage.ets      # 多标签工作区
│   │   └── SettingsPage.ets          # 设置页
│   ├── services/                # 服务层
│   │   ├── FileContentService.ets    # 统一文件读取（编码检测/BOM/GBK）
│   │   ├── SessionManager.ets        # 多标签会话管理
│   │   └── BinaryFileHandler.ets     # 二进制文件处理
│   └── utils/                   # 工具
│       ├── ThemeTokens.ets           # 主题颜色常量
│       ├── ThemeColors.ets           # 主题管理器
│       ├── SampleDataProvider.ets    # 示例数据
│       └── BreakpointUtil.ets        # 响应式断点
```

## 技术架构

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
│   文件选择 / 剪贴板 / AppStorage   │
└────────────────────────────────────┘
```

## 性能优化

| 优化项 | 说明 |
|--------|------|
| C++ NAPI Myers | 200+ 行自动切 C++，10-50x 加速 |
| LazyForEach 虚拟列表 | 只渲染可视区 ~30 行，非全量 ForEach |
| 解析行缓存 | textA/textB 未变时跳过 `parseLines` |
| 原地 Patch | 编辑/同步不跑全量 `computeDiff`，直接修改 `diffResult` |
| O(n²)→O(n) | `backtrack` unshift → push + reverse |
| mergeAdjacent 单次遍历 | 消除中间数组分配 |

## 参与贡献

欢迎提交 Pull Request，一起完善这个项目。可以从以下方向入手：

- 🐛 修复已知 Bug
- ✨ 新增语言语法高亮（在 `TokenHighlighter.ets` 添加关键词集）
- 🎨 贡献新主题配色（在 `ThemeTokens.ets` 参考 `getMonokaiColors` 模板）
- ⚡ NAPI C++ 性能优化（`myers_diff.cpp`）
- 📱 折叠屏 / 竖屏适配增强
- 🧪 补充单元测试（`src/test/`目录）

PR 前请确保 `entry` 模块编译通过（DevEco Studio → Build → Make Module）。

## License

ArkDiff 采用 **GNU Affero General Public License v3 (AGPL-3.0)**。

- 个人使用、学习、研究、修改、分发源码 → 自由
- 将 ArkDiff 或衍生作品用于**商业目的**（包括 SaaS、嵌入商业产品）→ 请先联系作者获取商业授权
- 网络服务使用修改版必须公开源码

[查看完整许可证](LICENSE)

---

[English Version](README.en.md)
