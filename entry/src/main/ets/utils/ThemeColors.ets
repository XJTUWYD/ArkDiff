/**
 * AegisDiff — 颜色主题系统
 * 单例模式，支持 Light / Dark / Monokai 三种主题
 */
import {
  ThemeColorMap,
  getLightColors,
  getDarkColors,
  getMonokaiColors,
} from './ThemeTokens';

export class ThemeColors {
  private static instance: ThemeColors | null = null;
  private _darkMode: boolean = false;
  private _isMonokai: boolean = false;
  private _cached: ThemeColorMap | null = null;

  static getInstance(): ThemeColors {
    if (!ThemeColors.instance) {
      ThemeColors.instance = new ThemeColors();
    }
    return ThemeColors.instance;
  }

  /** 设置深色模式 */
  setDarkMode(isDark: boolean): void {
    this._darkMode = isDark;
    this._isMonokai = false;
    this._cached = null;
  }

  /** 设置 Monokai 主题 */
  setMonokai(enable: boolean): void {
    this._isMonokai = enable;
    this._darkMode = false;
    this._cached = null;
  }

  /** 当前是否为深色模式 */
  get isDarkMode(): boolean {
    return this._darkMode;
  }

  /** 当前是否为 Monokai 主题 */
  get isMonokai(): boolean {
    return this._isMonokai;
  }

  /** 获取当前主题颜色 Tokens（缓存，避免每次 getter 访问都重新分配对象） */
  get colors(): ThemeColorMap {
    if (this._cached !== null) return this._cached;
    this._cached = this._isMonokai ? getMonokaiColors()
      : this._darkMode ? getDarkColors() : getLightColors();
    return this._cached;
  }

  // ========== 便捷属性（直接代理到当前主题） ==========

  get diffAddedBackground(): string { return this.colors.diffAddedBackground; }
  get diffAddedGutterBackground(): string { return this.colors.diffAddedGutterBackground; }
  get diffAddedForeground(): string { return this.colors.diffAddedForeground; }
  get diffDeletedBackground(): string { return this.colors.diffDeletedBackground; }
  get diffDeletedGutterBackground(): string { return this.colors.diffDeletedGutterBackground; }
  get diffDeletedForeground(): string { return this.colors.diffDeletedForeground; }
  get diffModifiedBackground(): string { return this.colors.diffModifiedBackground; }
  get diffModifiedGutterBackground(): string { return this.colors.diffModifiedGutterBackground; }
  get diffModifiedForeground(): string { return this.colors.diffModifiedForeground; }
  get diffUnchangedBackground(): string { return this.colors.diffUnchangedBackground; }
  get pageBackground(): string { return this.colors.pageBackground; }
  get surfaceBackground(): string { return this.colors.surfaceBackground; }
  get textPrimary(): string { return this.colors.textPrimary; }
  get textSecondary(): string { return this.colors.textSecondary; }
  get gutterTextColor(): string { return this.colors.gutterTextColor; }
  get dividerColor(): string { return this.colors.dividerColor; }
  get highlightFlashColor(): string { return this.colors.highlightFlashColor; }
  get toolbarBackground(): string { return this.colors.toolbarBackground; }
  get contentColor(): string { return this.colors.contentColor; }
  get editingBackground(): string { return this.colors.editingBackground; }
  get searchMatchBackground(): string { return this.colors.searchMatchBackground; }
  get highlightedBlockBackground(): string { return this.colors.highlightedBlockBackground; }
  get charAddedColor(): string { return this.colors.charAddedColor; }
  get prefixAdded(): string { return this.colors.prefixAdded; }
  get prefixDeleted(): string { return this.colors.prefixDeleted; }
  get prefixModified(): string { return this.colors.prefixModified; }
  get prefixDefault(): string { return this.colors.prefixDefault; }
}
