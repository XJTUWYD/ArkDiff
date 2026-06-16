/**
 * ArkDiff — AnalyticsService（轻量本地埋点 + 错误捕获）
 *
 * 设计原则：
 *   - 纯本地、透明可查（用户可在设置页查看/清除，不上传任何后端）
 *   - 仅记事件名→计数聚合 + 最近的错误日志（环形截断），不记任何文件内容/隐私
 *   - 用于度量功能采用度与定位高频错误，辅助产品决策
 *
 * 持久化：经 AppStorage → PersistentStorage 落盘（key 在 EntryAbility 注册）。
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 单条错误记录 */
export interface AnalyticsError {
  /** 发生范围（页面/服务名） */
  scope: string;
  /** 错误信息（已脱敏，不含文件内容） */
  message: string;
  /** 时间戳（ms） */
  time: number;
}

const COUNTS_KEY = 'analytics_counts';
const ERRORS_KEY = 'analytics_errors';
const MAX_ERRORS = 50;
const DOMAIN = 0x0001;

export class AnalyticsService {
  private static counts: Record<string, number> = {};
  private static errors: AnalyticsError[] = [];
  private static loaded: boolean = false;

  /** 从持久存储加载（幂等，EntryAbility 启动后也可重复调用） */
  static init(): void {
    if (AnalyticsService.loaded) return;
    AnalyticsService.loaded = true;
    try {
      const c = AppStorage.get<string>(COUNTS_KEY);
      if (c) AnalyticsService.counts = JSON.parse(c) as Record<string, number>;
    } catch (_e) {
      AnalyticsService.counts = {};
    }
    try {
      const e = AppStorage.get<string>(ERRORS_KEY);
      if (e) AnalyticsService.errors = JSON.parse(e) as AnalyticsError[];
    } catch (_e) {
      AnalyticsService.errors = [];
    }
  }

  /** 记录一次事件（按名称聚合计数） */
  static track(event: string): void {
    AnalyticsService.init();
    const cur = AnalyticsService.counts[event] ?? 0;
    AnalyticsService.counts[event] = cur + 1;
    try {
      AppStorage.setOrCreate(COUNTS_KEY, JSON.stringify(AnalyticsService.counts));
    } catch (_e) {
      hilog.error(DOMAIN, 'analytics', 'track persist failed');
    }
  }

  /** 捕获一条错误（环形截断，仅保留最近 MAX_ERRORS 条） */
  static captureError(scope: string, message: string): void {
    AnalyticsService.init();
    // 截断超长 message，避免异常对象撑爆存储
    const safe = message.length > 300 ? message.substring(0, 300) : message;
    AnalyticsService.errors.unshift({ scope, message: safe, time: Date.now() });
    if (AnalyticsService.errors.length > MAX_ERRORS) {
      AnalyticsService.errors.splice(MAX_ERRORS);
    }
    try {
      AppStorage.setOrCreate(ERRORS_KEY, JSON.stringify(AnalyticsService.errors));
    } catch (_e) {
      hilog.error(DOMAIN, 'analytics', 'error persist failed');
    }
  }

  /** 便捷：从异常对象捕获（自动提取 message） */
  static captureException(scope: string, e: Object): void {
    let msg: string;
    if (e instanceof Error) {
      msg = e.message;
    } else {
      const rec = e as Record<string, Object>;
      const m = rec['message'];
      msg = m !== undefined ? String(m) : String(e);
    }
    AnalyticsService.captureError(scope, msg);
  }

  /** 获取事件计数聚合（只读视图） */
  static getCounts(): Record<string, number> {
    AnalyticsService.init();
    return AnalyticsService.counts;
  }

  /** 获取最近的错误列表（只读视图） */
  static getErrors(): AnalyticsError[] {
    AnalyticsService.init();
    return AnalyticsService.errors;
  }

  /** 清空全部统计 */
  static reset(): void {
    AnalyticsService.counts = {};
    AnalyticsService.errors = [];
    try {
      AppStorage.setOrCreate(COUNTS_KEY, '{}');
      AppStorage.setOrCreate(ERRORS_KEY, '[]');
    } catch (_e) {
      hilog.error(DOMAIN, 'analytics', 'reset failed');
    }
  }
}
