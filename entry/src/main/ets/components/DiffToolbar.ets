/**
 * AegisDiff — DiffToolbar（Meld 风格工具栏）
 *
 * 仅分栏视图，无统一/分栏切换，无三路合并。
 * 图标使用 Unicode 符号替代 emoji。
 */
import { ViewMode } from '../model/DiffModels';
import { ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors } from '../utils/ThemeTokens';

@Component
export struct DiffToolbar {
  @Prop viewMode: ViewMode = ViewMode.SIDE_BY_SIDE;
  @Prop isComputing: boolean = false;
  @Prop searchActive: boolean = false;
  @Prop isMonokai: boolean = false;
  @Prop isDark: boolean = false;
  onRunDiff: () => void = () => {};
  onPasteSample: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onToggleSearch: () => void = () => {};
  onExport: () => void = () => {};
  onPickFileA?: () => void;
  onPickFileB?: () => void;

  build() {
    Row() {
      if (this.onPickFileA) {
        Button('\u229E').fontSize(16).width(28).height(28).type(ButtonType.Circle).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onPickFileA) this.onPickFileA(); })
      }
      if (this.onPickFileB) {
        Button('\u229F').fontSize(16).width(28).height(28).type(ButtonType.Circle).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onPickFileB) this.onPickFileB(); })
      }

      Button(this.isComputing ? '\u2026' : '\u27F3').fontSize(16).width(28).height(28).type(ButtonType.Circle)
        .backgroundColor('#007AFF').enabled(!this.isComputing)
        .onClick(() => { this.onRunDiff(); })

      Blank()

      Button('\u267B').fontSize(14).width(28).height(28).type(ButtonType.Circle).backgroundColor(Color.Transparent)
        .onClick(() => { this.onPasteSample(); })

      Button('\u2315').fontSize(16).width(28).height(28).type(ButtonType.Circle)
        .backgroundColor(this.searchActive ? '#007AFF' : Color.Transparent)
        .onClick(() => { this.onToggleSearch(); })

      Button('\u21F1').fontSize(16).width(28).height(28).type(ButtonType.Circle).backgroundColor(Color.Transparent)
        .onClick(() => { this.onExport(); })

      Button('\u2699').fontSize(16).width(28).height(28).type(ButtonType.Circle)
        .backgroundColor(Color.Transparent).fontColor(this.getTheme().textSecondary)
        .onClick(() => { this.onOpenSettings(); })
    }
    .width('100%').height('100%').padding({ left: 4, right: 2 })
    .backgroundColor(this.getTheme().toolbarBackground)
  }

  private getTheme(): ThemeColorMap {
    if (this.isMonokai) return getMonokaiColors();
    if (this.isDark) return getDarkColors();
    return getLightColors();
  }
}
