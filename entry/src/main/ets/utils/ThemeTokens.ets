/**
 * AegisDiff — 主题 Tokens 与全局常量
 * 所有 UI 颜色、尺寸、间距均从此文件引用，禁止 magic number
 */

// ==================== 主题颜色类型 ====================

export class ThemeColorMap {
  diffAddedBackground: string = '';
  diffAddedGutterBackground: string = '';
  diffAddedForeground: string = '';
  diffDeletedBackground: string = '';
  diffDeletedGutterBackground: string = '';
  diffDeletedForeground: string = '';
  diffModifiedBackground: string = '';
  diffModifiedGutterBackground: string = '';
  diffUnchangedBackground: string = '';
  pageBackground: string = '';
  surfaceBackground: string = '';
  textPrimary: string = '';
  textSecondary: string = '';
  gutterTextColor: string = '';
  dividerColor: string = '';
  highlightFlashColor: string = '';
  toolbarBackground: string = '';
}

// ==================== Diff 着色 Tokens（Light 模式） ====================

export function getLightColors(): ThemeColorMap {
  let c = new ThemeColorMap();
  c.diffAddedBackground = '#E6FFEC';
  c.diffAddedGutterBackground = '#C6F0D0';
  c.diffAddedForeground = '#1A7F37';
  c.diffDeletedBackground = '#FFEBE9';
  c.diffDeletedGutterBackground = '#F0C8C4';
  c.diffDeletedForeground = '#BE2E2E';
  c.diffModifiedBackground = '#FFF3D4';
  c.diffModifiedGutterBackground = '#F0DFA0';
  c.diffUnchangedBackground = '#FFFFFF';
  c.pageBackground = '#F5F5F5';
  c.surfaceBackground = '#FFFFFF';
  c.textPrimary = '#1C1C1C';
  c.textSecondary = '#666666';
  c.gutterTextColor = '#999999';
  c.dividerColor = '#E0E0E0';
  c.highlightFlashColor = '#FFD54F';
  c.toolbarBackground = '#FFFFFF';
  return c;
}

// ==================== Diff 着色 Tokens（Dark 模式） ====================

export function getDarkColors(): ThemeColorMap {
  let c = new ThemeColorMap();
  c.diffAddedBackground = '#1A3A2A';
  c.diffAddedGutterBackground = '#0F2A1C';
  c.diffAddedForeground = '#6FE08A';
  c.diffDeletedBackground = '#3A1A1A';
  c.diffDeletedGutterBackground = '#2A0F0F';
  c.diffDeletedForeground = '#F06A6A';
  c.diffModifiedBackground = '#3A3010';
  c.diffModifiedGutterBackground = '#2A2008';
  c.diffUnchangedBackground = '#1A1A1A';
  c.pageBackground = '#0D0D0D';
  c.surfaceBackground = '#1A1A1A';
  c.textPrimary = '#E8E8E8';
  c.textSecondary = '#999999';
  c.gutterTextColor = '#666666';
  c.dividerColor = '#333333';
  c.highlightFlashColor = '#4A3800';
  c.toolbarBackground = '#1A1A1A';
  return c;
}

// ==================== Diff 着色 Tokens（Monokai 模式） ====================

export function getMonokaiColors(): ThemeColorMap {
  let c = new ThemeColorMap();
  c.diffAddedBackground = '#232D1A';
  c.diffAddedGutterBackground = '#1A2412';
  c.diffAddedForeground = '#A6E22E';
  c.diffDeletedBackground = '#351B1B';
  c.diffDeletedGutterBackground = '#241212';
  c.diffDeletedForeground = '#F92672';
  c.diffModifiedBackground = '#33301A';
  c.diffModifiedGutterBackground = '#242012';
  c.diffUnchangedBackground = '#272822';
  c.pageBackground = '#1E1F1C';
  c.surfaceBackground = '#272822';
  c.textPrimary = '#F8F8F2';
  c.textSecondary = '#75715E';
  c.gutterTextColor = '#75715E';
  c.dividerColor = '#3E3D32';
  c.highlightFlashColor = '#49483E';
  c.toolbarBackground = '#272822';
  return c;
}

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
