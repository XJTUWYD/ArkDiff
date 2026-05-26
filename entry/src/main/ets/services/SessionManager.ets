/**
 * AegisDiff — SessionManager（会话管理）
 *
 * 管理：
 *   1. 多标签会话（TabSession）
 *   2. 最近任务记录（RecentTask）
 *   3. 会话持久化与恢复
 *   4. 当前活动会话切换
 *
 * 设计约束：
 *   - 最多 8 个标签页同时打开
 *   - 最近任务保留 50 条
 *   - 会话按 LRU 淘汰
 */
import { DiffSessionModel, ViewModeType } from '../model/DiffModels';
import { preferences } from '@kit.ArkData';

/** 会话类型 */
export enum SessionType {
  FILE_DIFF = 'file_diff',
  DIRECTORY_DIFF = 'directory_diff',
  MERGE = 'merge',
  TEXT_DIFF = 'text_diff',
}

/** 标签会话 */
export interface TabSession {
  id: string;
  type: SessionType;
  label: string;
  createdAt: number;           // 创建时间戳
  lastActiveAt: number;        // 最后活跃时间
  // 文件对比
  filePathA?: string;
  filePathB?: string;
  textA?: string;
  textB?: string;
  // 目录对比
  dirPathA?: string;
  dirPathB?: string;
  // 合并
  basePath?: string;
  minePath?: string;
  theirsPath?: string;
  // 运行时状态
  diffSession?: DiffSessionModel;
  viewMode?: ViewModeType;
  dirty: boolean;              // 是否有未保存修改
}

/** 最近任务记录 */
export interface RecentTask {
  id: string;
  type: SessionType;
  label: string;
  timestamp: number;
  filePathA?: string;
  filePathB?: string;
  summary?: string;            // 摘要（如 "125 行差异"）
}

// ==================== 配置 ====================

const MAX_TABS = 8;
const MAX_RECENT_TASKS = 50;
const STORE_NAME = 'aegisdiff_sessions';

/**
 * SessionManager — 全局单例
 */
export class SessionManager {
  private static instance: SessionManager | null = null;

  private tabs: TabSession[] = [];
  private activeTabId: string = '';
  private recentTasks: RecentTask[] = [];
  private sessionCounter = 0;

  private listeners: Array<() => void> = [];

  static getInstance(): SessionManager {
    if (!SessionManager.instance) {
      SessionManager.instance = new SessionManager();
    }
    return SessionManager.instance;
  }

  private constructor() {
    this.loadFromStorage();
  }

  // ==================== 标签管理 ====================

  getAllTabs(): TabSession[] {
    return this.tabs;
  }

  getActiveTab(): TabSession | null {
    return this.tabs.find(t => t.id === this.activeTabId) || null;
  }

  getActiveTabId(): string {
    return this.activeTabId;
  }

  getTabById(id: string): TabSession | null {
    return this.tabs.find(t => t.id === id) || null;
  }

  tabCount(): number {
    return this.tabs.length;
  }

  canCreateTab(): boolean {
    return this.tabs.length < MAX_TABS;
  }

  /**
   * 创建新标签
   */
  createTab(label: string, type: SessionType, options?: Partial<TabSession>): TabSession {
    const id = `tab_${++this.sessionCounter}_${Date.now()}`;
    const tab: TabSession = {
      id,
      type,
      label,
      createdAt: Date.now(),
      lastActiveAt: Date.now(),
      dirty: false,
      ...options,
    };
    this.tabs.push(tab);
    this.activeTabId = id;
    this.notifyListeners();
    this.saveToStorage();
    return tab;
  }

  /**
   * 激活标签
   */
  activateTab(id: string): boolean {
    const tab = this.tabs.find(t => t.id === id);
    if (!tab) return false;
    tab.lastActiveAt = Date.now();
    this.activeTabId = id;
    this.notifyListeners();
    return true;
  }

  /**
   * 关闭标签
   */
  closeTab(id: string): boolean {
    const idx = this.tabs.findIndex(t => t.id === id);
    if (idx === -1) return false;

    this.tabs.splice(idx, 1);

    // 如果关闭的是当前活跃标签，切换到最近活跃的
    if (this.activeTabId === id) {
      if (this.tabs.length > 0) {
        // 优先切换相邻标签
        const newIdx = Math.min(idx, this.tabs.length - 1);
        this.activeTabId = this.tabs[newIdx].id;
      } else {
        this.activeTabId = '';
      }
    }

    this.notifyListeners();
    this.saveToStorage();
    return true;
  }

  /**
   * 关闭所有标签
   */
  closeAllTabs(): void {
    this.tabs = [];
    this.activeTabId = '';
    this.notifyListeners();
    this.saveToStorage();
  }

  /**
   * 关闭其他标签（保留指定 ID）
   */
  closeOtherTabs(keepId: string): void {
    this.tabs = this.tabs.filter(t => t.id === keepId);
    this.activeTabId = keepId;
    this.notifyListeners();
    this.saveToStorage();
  }

  // ==================== 最近任务 ====================

  getRecentTasks(): RecentTask[] {
    return this.recentTasks.sort((a, b) => b.timestamp - a.timestamp);
  }

  addRecentTask(task: RecentTask): void {
    // 去重
    this.recentTasks = this.recentTasks.filter(t => t.id !== task.id);
    this.recentTasks.push(task);
    // 截断
    if (this.recentTasks.length > MAX_RECENT_TASKS) {
      this.recentTasks = this.recentTasks.slice(0, MAX_RECENT_TASKS);
    }
    this.saveToStorage();
  }

  clearRecentTasks(): void {
    this.recentTasks = [];
    this.saveToStorage();
  }

  /**
   * 从当前标签创建最近任务记录
   */
  recordActiveTabAsRecent(summary?: string): void {
    const tab = this.getActiveTab();
    if (!tab) return;
    this.addRecentTask({
      id: tab.id,
      type: tab.type,
      label: tab.label,
      timestamp: Date.now(),
      filePathA: tab.filePathA,
      filePathB: tab.filePathB,
      summary,
    });
  }

  /**
   * 从最近任务重新打开
   */
  reopenRecentTask(task: RecentTask): TabSession | null {
    if (!this.canCreateTab()) return null;
    return this.createTab(task.label, task.type, {
      filePathA: task.filePathA,
      filePathB: task.filePathB,
    });
  }

  // ==================== 标签状态持久化 ====================

  private saveToStorage(): void {
    try {
      const data = {
        tabs: this.tabs.map(t => ({
          id: t.id, type: t.type, label: t.label,
          createdAt: t.createdAt, lastActiveAt: t.lastActiveAt,
          filePathA: t.filePathA, filePathB: t.filePathB,
          textA: t.textA, textB: t.textB,
          dirPathA: t.dirPathA, dirPathB: t.dirPathB,
          basePath: t.basePath, minePath: t.minePath, theirsPath: t.theirsPath,
          viewMode: t.viewMode,
          dirty: t.dirty,
        })),
        activeTabId: this.activeTabId,
        recentTasks: this.recentTasks,
        sessionCounter: this.sessionCounter,
      };

      // HarmonyOS preferences 存储
      const prefs = preferences.getPreferencesSync({ name: STORE_NAME });
      prefs.putSync('sessions', JSON.stringify(data));
      prefs.flushSync();
    } catch (_e) {
      // 存储不可用静默失败
    }
  }

  private loadFromStorage(): void {
    try {
      const prefs = preferences.getPreferencesSync({ name: STORE_NAME });
      const raw = prefs.getSync('sessions', '') as string;
      if (!raw) return;

      const data = JSON.parse(raw);
      if (data.tabs) {
        this.tabs = data.tabs.map((t: Record<string, Object>) => ({
          id: t.id as string,
          type: t.type as SessionType,
          label: t.label as string,
          createdAt: t.createdAt as number,
          lastActiveAt: t.lastActiveAt as number,
          filePathA: t.filePathA as string | undefined,
          filePathB: t.filePathB as string | undefined,
          textA: t.textA as string | undefined,
          textB: t.textB as string | undefined,
          dirPathA: t.dirPathA as string | undefined,
          dirPathB: t.dirPathB as string | undefined,
          basePath: t.basePath as string | undefined,
          minePath: t.minePath as string | undefined,
          theirsPath: t.theirsPath as string | undefined,
          viewMode: t.viewMode as ViewModeType | undefined,
          dirty: (t.dirty as boolean) || false,
        }));
      }
      if (data.activeTabId) {
        this.activeTabId = data.activeTabId;
        // 验证活跃标签仍存在
        if (!this.tabs.find(t => t.id === this.activeTabId) && this.tabs.length > 0) {
          this.activeTabId = this.tabs[0].id;
        }
      }
      if (data.recentTasks) {
        this.recentTasks = data.recentTasks as RecentTask[];
      }
      if (typeof data.sessionCounter === 'number') {
        this.sessionCounter = data.sessionCounter;
      }
    } catch (_e) {
      // 恢复失败，使用空状态
    }
  }

  // ==================== 监听器 ====================

  addListener(callback: () => void): void {
    this.listeners.push(callback);
  }

  removeListener(callback: () => void): void {
    const idx = this.listeners.indexOf(callback);
    if (idx !== -1) this.listeners.splice(idx, 1);
  }

  private notifyListeners(): void {
    for (const cb of this.listeners) {
      try { cb(); } catch (_e) { /* 忽略 */ }
    }
  }
}