/**
 * AegisDiff — 核心数据模型
 * 定义 Diff 引擎输入输出、UI 状态、全局设置的所有类型
 */

// ==================== 枚举 ====================

/** 差异类型 */
export enum DiffType {
  /** 未变更 */
  UNCHANGED = 0,
  /** 新增行（仅 B 中有） */
  ADDED = 1,
  /** 删除行（仅 A 中有） */
  DELETED = 2,
  /** 修改行（A 和 B 行内容不同但算法认定匹配） */
  MODIFIED = 3
}

/** 视图模式 */
export enum ViewMode {
  /** 统一视图（单列，标注 +/-） */
  UNIFIED = 0,
  /** 左右分栏视图 */
  SIDE_BY_SIDE = 1
}

// ==================== 核心接口 ====================

/** 单行差异行 */
export interface DiffLine {
  /** 原始文件 A 中的行号（从 1 开始，ADDED 时为 -1） */
  lineNumberA: number;
  /** 修改后文件 B 中的行号（从 1 开始，DELETED 时为 -1） */
  lineNumberB: number;
  /** 该行的文本内容（新版本，即 B 的内容） */
  content: string;
  /** MODIFIED 行对应的旧版本内容，其他类型为空字符串 */
  oldContent: string;
  /** 差异类型 */
  type: DiffType;
  /** 字符级差异段（P2 阶段使用，默认空数组） */
  charSegments: CharSegment[];
}

/** 字符级差异段（P2） */
export interface CharSegment {
  /** 段的起始字符位置（0-based） */
  start: number;
  /** 段的结束字符位置（0-based，不包含） */
  end: number;
  /** 段的差异类型 */
  type: DiffType;
}

/** Diff 计算完整结果 */
export interface DiffResult {
  /** Unified 视图排列的行列表 */
  unifiedLines: DiffLine[];
  /** Side-by-Side 视图左列行列表 */
  leftLines: DiffLine[];
  /** Side-by-Side 视图右列行列表 */
  rightLines: DiffLine[];
  /** 差异统计 */
  stats: DiffStats;
  /** Diff 算法耗时（毫秒） */
  elapsedMs: number;
}

/** 差异统计 */
export interface DiffStats {
  /** 新增行数（ADDED） */
  addedCount: number;
  /** 删除行数（DELETED） */
  deletedCount: number;
  /** 修改行数（MODIFIED） */
  modifiedCount: number;
  /** 未变更行数 */
  unchangedCount: number;
  /** 相似度百分比（0.0 ~ 100.0） */
  similarityPercent: number;
  /** 总差异块数（连续差异行组成一个块） */
  diffBlockCount: number;
}

// ==================== UI 状态模型 ====================

/** DiffViewModel 核心状态 */
export interface DiffEditorState {
  /** 原始文本 A */
  textA: string;
  /** 修改后文本 B */
  textB: string;
  /** Diff 计算结果（null 表示未执行对比） */
  diffResult: DiffResult | null;
  /** 当前视图模式 */
  viewMode: ViewMode;
  /** 当前差异导航索引（以差异块为单位），-1 表示未开始导航 */
  currentDiffBlockIndex: number;
  /** 是否正在计算中 */
  isComputing: boolean;
  /** 输入面板是否可见 */
  inputPanelVisible: boolean;
}

/** 全局设置（通过 AppStorage 持久化） */
export interface AppSettings {
  /** 颜色模式：'auto' | 'light' | 'dark' */
  colorMode: string;
  /** 代码字体大小 */
  codeFontSize: number;
  /** 是否忽略空白行 */
  ignoreBlankLines: boolean;
}

// ==================== LCS 算法相关类型 ====================

/** LCS 匹配行对 */
export interface LcsMatchedPair {
  /** 在列表 A 中的索引 */
  indexA: number;
  /** 在列表 B 中的索引 */
  indexB: number;
}

/** LCS 计算结果 */
export interface LcsResult {
  /** 匹配行对列表（按 indexA 升序） */
  matches: LcsMatchedPair[];
  /** 列表 A 的总行数 */
  lengthA: number;
  /** 列表 B 的总行数 */
  lengthB: number;
}

/** Diff 引擎选项 */
export interface DiffOptions {
  /** 是否忽略空行 */
  ignoreBlankLines: boolean;
  /** 是否启用字符级 Diff */
  enableCharDiff: boolean;
}
