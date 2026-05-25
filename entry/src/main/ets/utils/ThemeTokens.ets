/**
 * AegisDiff — 主题 Tokens 与全局常量
 * 所有 UI 颜色、尺寸、间距均从此文件引用，禁止 magic number
 */

// ==================== Diff 着色 Tokens（Light 模式） ====================

export const LightColors = {
  /** 新增行背景色 */
  diffAddedBackground: '#E6FFEC',
  /** 新增行行号背景色 */
  diffAddedGutterBackground: '#C6F0D0',
  /** 新增行文字颜色 */
  diffAddedForeground: '#1A7F37',
  /** 删除行背景色 */
  diffDeletedBackground: '#FFEBE9',
  /** 删除行行号背景色 */
  diffDeletedGutterBackground: '#F0C8C4',
  /** 删除行文字颜色 */
  diffDeletedForeground: '#BE2E2E',
  /** 修改行背景色 */
  diffModifiedBackground: '#FFF3D4',
  /** 修改行行号背景色 */
  diffModifiedGutterBackground: '#F0DFA0',
  /** 未变更行背景色 */
  diffUnchangedBackground: '#FFFFFF',
  /** 页面背景色 */
  pageBackground: '#F5F5F5',
  /** 卡片/面板背景色 */
  surfaceBackground: '#FFFFFF',
  /** 主要文字颜色 */
  textPrimary: '#1C1C1C',
  /** 次要文字颜色 */
  textSecondary: '#666666',
  /** 行号文字颜色 */
  gutterTextColor: '#999999',
  /** 分隔线颜色 */
  dividerColor: '#E0E0E0',
  /** 导航高亮闪烁色 */
  highlightFlashColor: '#FFD54F',
  /** Toolbar 背景色 */
  toolbarBackground: '#FFFFFF',
} as const;

// ==================== Diff 着色 Tokens（Dark 模式） ====================

export const DarkColors = {
  diffAddedBackground: '#1A3A2A',
  diffAddedGutterBackground: '#0F2A1C',
  diffAddedForeground: '#6FE08A',
  diffDeletedBackground: '#3A1A1A',
  diffDeletedGutterBackground: '#2A0F0F',
  diffDeletedForeground: '#F06A6A',
  diffModifiedBackground: '#3A3010',
  diffModifiedGutterBackground: '#2A2008',
  diffUnchangedBackground: '#1A1A1A',
  pageBackground: '#0D0D0D',
  surfaceBackground: '#1A1A1A',
  textPrimary: '#E8E8E8',
  textSecondary: '#999999',
  gutterTextColor: '#666666',
  dividerColor: '#333333',
  highlightFlashColor: '#4A3800',
  toolbarBackground: '#1A1A1A',
} as const;

// ==================== 尺寸常量 ====================

/** 代码行字体大小（vp） */
export const CODE_FONT_SIZE_DEFAULT = 14;
export const CODE_FONT_SIZE_MIN = 12;
export const CODE_FONT_SIZE_MAX = 20;

/** 行号字体大小（vp） */
export const GUTTER_FONT_SIZE = 12;

/** 行高（vp） */
export const LINE_HEIGHT = 24;

/** 行号区域宽度（vp） */
export const GUTTER_WIDTH = 52;

/** 工具栏高度（vp） */
export const TOOLBAR_HEIGHT = 48;

/** 导航栏高度（vp） */
export const NAVIGATOR_HEIGHT = 40;

/** 统计栏高度（vp） */
export const STATS_BAR_HEIGHT = 36;

/** 分隔线宽度（vp） */
export const DIVIDER_WIDTH = 1;

/** 输入面板最小高度（vp） */
export const INPUT_PANEL_MIN_HEIGHT = 120;

/** 输入面板默认高度（vp） */
export const INPUT_PANEL_DEFAULT_HEIGHT = 200;

/** 卡片圆角半径（vp） */
export const CARD_BORDER_RADIUS = 8;

/** 页面水平内边距（vp） */
export const PAGE_HORIZONTAL_PADDING = 16;

/** 页面垂直内边距（vp） */
export const PAGE_VERTICAL_PADDING = 12;

// ==================== 布局断点（vp） ====================

/** 平板/2in1 横屏最小宽度 */
export const BREAKPOINT_TABLET = 840;

/** 手机竖屏最大宽度 */
export const BREAKPOINT_PHONE = 480;

// ==================== 性能常量 ====================

/** LCS 算法最大行数阈值，超过此值切换 Myers 或简化算法 */
export const LCS_MAX_LINES = 3000;

/** LazyForEach 视口外预渲染行数 */
export const LAZY_FOR_EACH_CACHED_COUNT = 20;

/** Diff 计算超时警告阈值（毫秒） */
export const DIFF_TIMEOUT_WARNING_MS = 5000;
