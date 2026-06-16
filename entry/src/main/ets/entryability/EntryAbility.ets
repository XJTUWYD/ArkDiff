import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BreakpointUtil } from '../utils/BreakpointUtil';
import { AnalyticsService } from '../services/AnalyticsService';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private breakpointUtil: BreakpointUtil | null = null;
  private mainUiContext: UIContext | null = null;
  /** 启动时若通过"分享文本"唤起，暂存待处理的分享内容 */
  private pendingSharedText: string = '';

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 将关键设置/会话状态绑定到持久化存储，使其跨重启保留。
    // 必须在任何 @StorageLink 访问前调用（此处早于 loadContent）。
    try {
      PersistentStorage.persistProp('colorMode', 'auto');
      PersistentStorage.persistProp('codeFontSize', 14);
      PersistentStorage.persistProp('ignoreBlankLines', false);
      PersistentStorage.persistProp('ignoreCase', false);
      PersistentStorage.persistProp('ignoreWhitespace', false);
      PersistentStorage.persistProp('multiTab_recentFiles', '[]');
      PersistentStorage.persistProp('multiTab_openTabs', '[]');
      PersistentStorage.persistProp('onboardingShown', false);
      PersistentStorage.persistProp('analytics_counts', '{}');
      PersistentStorage.persistProp('analytics_errors', '[]');
    } catch (e) {
      hilog.error(DOMAIN, 'testTag', 'PersistentStorage init failed: %{public}s', JSON.stringify(e));
    }
    AnalyticsService.init();
    // 处理"分享文本"唤起：提取分享内容
    this.pendingSharedText = this.extractSharedText(want);
    if (this.pendingSharedText.length > 0) {
      AppStorage.setOrCreate('pendingSharedText', this.pendingSharedText);
      AnalyticsService.track('share_received');
      hilog.info(DOMAIN, 'testTag', 'Launched via share with %d chars', this.pendingSharedText.length);
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /** 应用已运行时再次被"分享"唤起 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const text = this.extractSharedText(want);
    if (text.length === 0) return;
    AppStorage.setOrCreate('pendingSharedText', text);
    // 若 UI 已就绪，直接跳到工作台让用户立即处理分享内容
    try {
      if (this.mainUiContext) {
        this.mainUiContext.getRouter().pushUrl({ url: 'pages/MultiTabDiffPage' });
      }
    } catch (e) {
      hilog.error(DOMAIN, 'testTag', 'Navigate on share failed: %{public}s', JSON.stringify(e));
    }
  }

  /** 从分享 Want 中提取文本（不同来源 key 不一，做防御性扫描） */
  private extractSharedText(want: Want): string {
    const params = want.parameters as Record<string, Object> | undefined;
    if (!params) return '';
    const keys = ['content', 'text', 'shareText', 'sharedText', 'rawText', 'android.intent.extra.TEXT'];
    for (const k of keys) {
      const v = params[k];
      if (typeof v === 'string' && v.length > 0) return v;
    }
    return '';
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 通过"分享文本"唤起时，直接进入工作台处理分享内容，跳过启动页
    const entryPage = this.pendingSharedText.length > 0 ? 'pages/MultiTabDiffPage' : 'pages/SplashPage';
    windowStage.loadContent(entryPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // 页面加载完成后注册断点监听
      try {
        const mainWindow = windowStage.getMainWindowSync();
        const uiContext = mainWindow.getUIContext();
        this.mainUiContext = uiContext;
        this.breakpointUtil = new BreakpointUtil(uiContext);
        this.breakpointUtil.register();
      } catch (e) {
        hilog.error(DOMAIN, 'testTag', 'Breakpoint register failed: %{public}s', JSON.stringify(e));
      }
    });
  }

  onWindowStageDestroy(): void {
    this.breakpointUtil?.unregister();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}