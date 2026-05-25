/**
 * AegisDiff — 响应式断点工具
 * 使用 mediaquery 监听窗口宽度变化，存入 AppStorage
 */
import { mediaquery } from '@kit.ArkUI';

// HarmonyOS 标准断点
export enum Breakpoint {
  SM = 'sm',   // [320, 600) vp — 手机
  MD = 'md',   // [600, 840) vp — 折叠屏展开态 / 平板竖屏
  LG = 'lg',   // [840, +∞) vp — 平板横屏 / 桌面
}

const BREAKPOINT_KEY = 'currentBreakpoint';

export class BreakpointUtil {
  private smListener: mediaquery.MediaQueryListener | null = null;
  private mdListener: mediaquery.MediaQueryListener | null = null;
  private lgListener: mediaquery.MediaQueryListener | null = null;
  private uiContext: UIContext;

  constructor(uiContext: UIContext) {
    this.uiContext = uiContext;
  }

  /** 注册断点监听 */
  register(): void {
    this.smListener = this.uiContext.getMediaQuery()
      .matchMediaSync('(320vp<=width<600vp)');
    this.mdListener = this.uiContext.getMediaQuery()
      .matchMediaSync('(600vp<=width<840vp)');
    this.lgListener = this.uiContext.getMediaQuery()
      .matchMediaSync('(840vp<=width)');

    this.sync(); // 立即同步一次

    const onSm = (r: mediaquery.MediaQueryResult) => { if (r.matches) this.set(Breakpoint.SM); };
    const onMd = (r: mediaquery.MediaQueryResult) => { if (r.matches) this.set(Breakpoint.MD); };
    const onLg = (r: mediaquery.MediaQueryResult) => { if (r.matches) this.set(Breakpoint.LG); };

    this.smListener.on('change', onSm);
    this.mdListener.on('change', onMd);
    this.lgListener.on('change', onLg);
  }

  /** 解除监听 */
  unregister(): void {
    this.smListener?.off('change');
    this.mdListener?.off('change');
    this.lgListener?.off('change');
  }

  /** 同步当前断点 */
  private sync(): void {
    if (this.lgListener?.matches) { this.set(Breakpoint.LG); return; }
    if (this.mdListener?.matches) { this.set(Breakpoint.MD); return; }
    this.set(Breakpoint.SM);
  }

  private set(bp: Breakpoint): void {
    AppStorage.setOrCreate(BREAKPOINT_KEY, bp);
  }
}
