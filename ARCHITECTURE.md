# AegisDiff — 架构文档

## 整体架构

```
┌─────────────── ArkUI Layer ───────────────┐
│  SplashPage  DiffEditorPage  SettingsPage  │
│       │            │              │        │
│  ┌────┴────┐ ┌────┴────┐  ┌──────┴─────┐ │
│  │Toolbar  │ │Input    │  │Color/Slider │ │
│  │Nav      │ │Stats    │  │Toggle      │ │
│  │DiffView │ │         │  │            │ │
│  └─────────┘ └─────────┘  └────────────┘ │
├────────── State Management Layer ─────────┤
│  @State / @Prop / @Link / @Provide        │
│  DiffViewModel (数据驱动 UI 更新)           │
├────────────── Engine Layer ───────────────┤
│  LineParser → LcsEngine/MyersEngine       │
│       ↓                                   │
│  DiffEngine (编排器)                       │
│       ↓                                   │
│  DiffBlockLocator + StatsCalculator       │
├────────── Platform Capabilities ──────────┤
│  @kit.ArkUI (router)                      │
│  @kit.CoreFileKit (FilePicker)            │
└───────────────────────────────────────────┘
```

## 核心数据流

```
用户输入 textA + textB
        ↓
   DiffEngine.computeDiff(textA, textB, options)
        ↓
  LineParser.parseLines() → string[]
        ↓
  LcsEngine/MyersEngine.compute() → LcsResult
        ↓
  buildUnifiedLines() → DiffLine[]
        ↓
  buildSideBySideLines() → {leftLines, rightLines}
        ↓
  StatsCalculator.calculate() → DiffStats
        ↓
  DiffResult { unifiedLines, leftLines, rightLines, stats, elapsedMs }
        ↓
  UI: @State 更新 → DiffEditorPage 重新渲染
```

## Diff 算法选择策略

| 行数规模 | 算法 | 复杂度 |
|----------|------|--------|
| ≤ 3000 | LCS（最长公共子序列）| O(m×n) |
| > 3000 | Myers 差分算法 | O((m+n)×D) |

## 如何扩展新 Diff 算法

1. 在 `engine/` 下创建新的算法文件（如 `PatienceEngine.ets`）
2. 实现 `compute(linesA: string[], linesB: string[]): LcsResult` 接口
3. 在 `DiffEngine.selectAndRunAlgorithm()` 中添加选择逻辑
4. 在 `model/DiffModels.ets` 中更新 `LCS_MAX_LINES` 阈值常量

## 状态管理约定

- `@State`：页面级状态（textA, textB, viewMode, stats...）
- `@Prop`：父→子单向传递（组件属性）
- `@Link`：父子双向绑定（$ 语法）
- `AppStorage`：跨页面全局设置（颜色模式、字体大小）

## 性能注意事项

- 当前使用 ForEach + Scroll 实现列表渲染
- v1.1 计划迁移到 LazyForEach 虚拟列表（500+ 行场景）
- Diff 计算在主线程执行，超大文本建议使用 TaskPool 异步化
