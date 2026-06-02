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
  diffModifiedForeground: string = '';
  diffUnchangedBackground: string = '';
  pageBackground: string = '';
  surfaceBackground: string = '';
  textPrimary: string = '';
  textSecondary: string = '';
  gutterTextColor: string = '';
  dividerColor: string = '';
  highlightFlashColor: string = '';
  toolbarBackground: string = '';
  contentColor: string = '';
  editingBackground: string = '';
  searchMatchBackground: string = '';
  highlightedBlockBackground: string = '';
  charAddedColor: string = '';
  prefixAdded: string = '';
  prefixDeleted: string = '';
  prefixModified: string = '';
  prefixDefault: string = '';
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
  c.diffModifiedForeground = '#D4A017';
  c.diffUnchangedBackground = '#FFFFFF';
  c.pageBackground = '#F5F5F5';
  c.surfaceBackground = '#FFFFFF';
  c.textPrimary = '#1C1C1C';
  c.textSecondary = '#666666';
  c.gutterTextColor = '#999999';
  c.dividerColor = '#E0E0E0';
  c.highlightFlashColor = '#FFD54F';
  c.toolbarBackground = '#FFFFFF';
  c.contentColor = '#1C1C1C';
  c.editingBackground = '#E3F2FD';
  c.searchMatchBackground = '#FFD54F';
  c.highlightedBlockBackground = '#FFF9C4';
  c.charAddedColor = '#1A7F37';
  c.prefixAdded = '#1A7F37';
  c.prefixDeleted = '#BE2E2E';
  c.prefixModified = '#D4A017';
  c.prefixDefault = '#CCCCCC';
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
  c.diffModifiedForeground = '#E6DB74';
  c.diffUnchangedBackground = '#1A1A1A';
  c.pageBackground = '#0D0D0D';
  c.surfaceBackground = '#1A1A1A';
  c.textPrimary = '#E8E8E8';
  c.textSecondary = '#999999';
  c.gutterTextColor = '#666666';
  c.dividerColor = '#333333';
  c.highlightFlashColor = '#4A3800';
  c.toolbarBackground = '#1A1A1A';
  c.contentColor = '#E8E8E8';
  c.editingBackground = '#2A2A40';
  c.searchMatchBackground = '#49483E';
  c.highlightedBlockBackground = '#3A3A2A';
  c.charAddedColor = '#6FE08A';
  c.prefixAdded = '#6FE08A';
  c.prefixDeleted = '#F06A6A';
  c.prefixModified = '#E6DB74';
  c.prefixDefault = '#666666';
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
  c.diffModifiedForeground = '#E6DB74';
  c.diffUnchangedBackground = '#272822';
  c.pageBackground = '#1E1F1C';
  c.surfaceBackground = '#272822';
  c.textPrimary = '#F8F8F2';
  c.textSecondary = '#75715E';
  c.gutterTextColor = '#75715E';
  c.dividerColor = '#3E3D32';
  c.highlightFlashColor = '#49483E';
  c.toolbarBackground = '#272822';
  c.contentColor = '#F8F8F2';
  c.editingBackground = '#2A2A40';
  c.searchMatchBackground = '#49483E';
  c.highlightedBlockBackground = '#3A3A2A';
  c.charAddedColor = '#A6E22E';
  c.prefixAdded = '#A6E22E';
  c.prefixDeleted = '#F92672';
  c.prefixModified = '#E6DB74';
  c.prefixDefault = '#75715E';
  return c;
}

// ==================== 按钮语义颜色 ====================

export class ButtonColorMap {
  primaryBackground: string = '';
  primaryForeground: string = '';
  dangerBackground: string = '';
  dangerForeground: string = '';
  successBackground: string = '';
  successForeground: string = '';
  warningBackground: string = '';
  warningForeground: string = '';
  disabledBackground: string = '';
  disabledForeground: string = '';
  hoverBackground: string = '';
}

export function getLightButtonColors(): ButtonColorMap {
  let c = new ButtonColorMap();
  c.primaryBackground = '#007AFF';
  c.primaryForeground = '#FFFFFF';
  c.dangerBackground = '#E53935';
  c.dangerForeground = '#FFFFFF';
  c.successBackground = '#1A7F37';
  c.successForeground = '#FFFFFF';
  c.warningBackground = '#F5A623';
  c.warningForeground = '#FFFFFF';
  c.disabledBackground = '#C8C8C8';
  c.disabledForeground = '#888888';
  c.hoverBackground = '#F0F0F0';
  return c;
}

export function getDarkButtonColors(): ButtonColorMap {
  let c = new ButtonColorMap();
  c.primaryBackground = '#3399FF';
  c.primaryForeground = '#FFFFFF';
  c.dangerBackground = '#EF5350';
  c.dangerForeground = '#FFFFFF';
  c.successBackground = '#4CAF50';
  c.successForeground = '#FFFFFF';
  c.warningBackground = '#FFB74D';
  c.warningForeground = '#1C1C1C';
  c.disabledBackground = '#444444';
  c.disabledForeground = '#777777';
  c.hoverBackground = '#333333';
  return c;
}

// ==================== Icon System ====================

/**
 * AegisDiff 图标系统 — 语义化图标名称
 *
 * 用法示例：
 *   <Text>{{ IconTokens.FILE_COMPARE }}</Text>
 *   <Image src="{{ getIconResource(IconTokens.ARROW_DOWN) }}" />
 *
 * 设计原则：
 *   - Primary actions:   实心图标
 *   - Secondary actions: 线性图标
 *   - Navigation:        ← → ↑ ↓ 箭头
 *   - Status:            ✓ ✗ ⚠ 状态标
 *   - File ops:          📄 📁 💾 文件操作
 *
 * 所有页面和组件必须使用这些 tokens，禁止硬编码 emoji/unicode 图标。
 */
class IconTokenValues {
  // === 导航 ===
  ARROW_LEFT: string = '←';
  ARROW_RIGHT: string = '→';
  ARROW_UP: string = '↑';
  ARROW_DOWN: string = '↓';
  CHEVRON_LEFT: string = '‹';
  CHEVRON_RIGHT: string = '›';
  CHEVRON_UP: string = '⌃';
  CHEVRON_DOWN: string = '⌄';

  // === 文件操作 ===
  FILE_OPEN: string = '📄';
  FILE_SAVE: string = '💾';
  FILE_SAVE_AS: string = '📥';
  FOLDER_OPEN: string = '📁';
  FILE_COMPARE: string = '⇔';
  FILE_EXPORT: string = '↗';
  FILE_IMPORT: string = '↙';

  // === 编辑操作 ===
  COPY: string = '⧉';
  PASTE: string = '📋';
  CUT: string = '✂';
  UNDO: string = '↩';
  REDO: string = '↪';
  EDIT: string = '✎';
  DELETE: string = '✕';
  ADD: string = '＋';

  // === 视图 ===
  VIEW_UNIFIED: string = '☰';
  VIEW_SIDE_BY_SIDE: string = '◫';
  VIEW_TREE: string = '◈';
  VIEW_LIST: string = '≡';

  // === Diff / Merge ===
  DIFF_NEXT: string = '▼';
  DIFF_PREV: string = '▲';
  MERGE_ACCEPT_LEFT: string = '◀';
  MERGE_ACCEPT_RIGHT: string = '▶';
  MERGE_KEEP_BOTH: string = '⫿';
  MERGE_EDIT: string = '✎';
  SYNC_TO_LEFT: string = '«';
  SYNC_TO_RIGHT: string = '»';

  // === 搜索 ===
  SEARCH: string = '🔍';
  SEARCH_NEXT: string = '▼';
  SEARCH_PREV: string = '▲';

  // === 状态 ===
  STATUS_ADDED: string = '＋';
  STATUS_DELETED: string = '−';
  STATUS_MODIFIED: string = '~';
  STATUS_UNCHANGED: string = '=';
  STATUS_CONFLICT: string = '⚠';
  STATUS_IDENTICAL: string = '✓';
  STATUS_ONLY_A: string = '◁';
  STATUS_ONLY_B: string = '▷';

  // === 通用操作 ===
  SETTINGS: string = '⚙';
  CLOSE: string = '✕';
  REFRESH: string = '↻';
  FILTER: string = '⊡';
  EXPAND_ALL: string = '⊞';
  COLLAPSE_ALL: string = '⊟';
  MORE: string = '⋯';
  HOME: string = '⌂';
  TAB_NEW: string = '＋';

  // === 大文件/二进制 ===
  WARNING: string = '⚠';
  INFO: string = '🛈';
  BINARY_FILE: string = '⬡';

  // === 主题 ===
  THEME_LIGHT: string = '☀';
  THEME_DARK: string = '☾';
}
export const IconTokens = new IconTokenValues();

/**
 * 图标尺寸预设（vp）
 */
class IconSizeValues {
  SMALL: number = 14;
  MEDIUM: number = 16;
  LARGE: number = 20;
  XLARGE: number = 24;
  TOOLBAR: number = 18;
}
export const IconSizes = new IconSizeValues();

// ==================== 尺寸常量（Layout） ====================

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

// ==================== 间距体系（Spacing Scale） ====================

/**
 * 8pt 网格间距体系
 * 所有 margin/padding 必须使用这些值，禁止任意数字
 */
class SpacingValues {
  /** 2vp — 极小间距（图标与文字之间） */
  XS: number = 2;
  /** 4vp — 小间距（紧凑元素之间） */
  SM: number = 4;
  /** 8vp — 标准间距（控件之间） */
  MD: number = 8;
  /** 12vp — 中等间距（组之间） */
  LG: number = 12;
  /** 16vp — 大间距（区块之间） */
  XL: number = 16;
  /** 24vp — 超大间距（页面级分隔） */
  XXL: number = 24;
  /** 32vp — 页面外边距 */
  XXXL: number = 32;
}
export const Spacing = new SpacingValues();

// ==================== 动画常量 ====================

/** 过渡动画时长（ms） */
export const ANIMATION_DURATION_FAST = 150;
export const ANIMATION_DURATION_NORMAL = 250;
export const ANIMATION_DURATION_SLOW = 400;

/** 差异高亮闪烁时长（ms） */
export const HIGHLIGHT_FLASH_DURATION = 800;

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
