/**
 * AegisDiff — DiffToolbar 组件
 * 使用 ThemeTokens 进行颜色管理
 */
import { ViewMode } from '../model/DiffModels';
import { ThemeColorMap, ButtonColorMap, getLightColors, getDarkColors, getMonokaiColors, getLightButtonColors, getDarkButtonColors } from '../utils/ThemeTokens';

@Component
export struct DiffToolbar {
  @Prop viewMode: ViewMode = ViewMode.SIDE_BY_SIDE;
  @Prop isComputing: boolean = false;
  @Prop searchActive: boolean = false;
  @Prop isMonokai: boolean = false;
  @Prop isDark: boolean = false;
  onRunDiff: () => void = () => {};
  onSwitchView: (mode: ViewMode) => void = () => {};
  onPasteSample: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onToggleSearch: () => void = () => {};
  onOpenMerge: () => void = () => {};
  onExport: () => void = () => {};
  onPickFileA?: () => void;
  onPickFileB?: () => void;

  build() {
    Row() {
      if (this.onPickFileA) {
        Button('📄').fontSize(13).width(28).height(28).type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onPickFileA) this.onPickFileA(); })
      }
      if (this.onPickFileB) {
        Button('📄').fontSize(13).width(28).height(28).type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick(() => { if (this.onPickFileB) this.onPickFileB(); })
      }

      Button(this.isComputing ? '…' : '对比')
        .fontSize(12).height(28)
        .type(ButtonType.Capsule).backgroundColor('#007AFF')
        .borderRadius(14).enabled(!this.isComputing)
        .padding({ left: 10, right: 10 })
        .onClick(() => { this.onRunDiff(); })

      Blank()

      Row() {
        Button('统一')
          .fontSize(11).height(24).type(ButtonType.Capsule)
          .backgroundColor(this.viewMode === ViewMode.UNIFIED ? '#007AFF' :  this.getTheme().dividerColor)
          .fontColor(this.viewMode === ViewMode.UNIFIED ? Color.White : this.getTheme().textSecondary)
          .borderRadius(0).padding({ left: 6, right: 6 })
          .onClick(() => { this.onSwitchView(ViewMode.UNIFIED); })
        Button('分栏')
          .fontSize(11).height(24).type(ButtonType.Capsule)
          .backgroundColor(this.viewMode === ViewMode.SIDE_BY_SIDE ? '#007AFF' : this.getTheme().dividerColor)
          .fontColor(this.viewMode === ViewMode.SIDE_BY_SIDE ? Color.White : this.getTheme().textSecondary)
          .borderRadius(0).padding({ left: 6, right: 6 })
          .onClick(() => { this.onSwitchView(ViewMode.SIDE_BY_SIDE); })
      }
      .borderRadius(12).border({ width: 1, color: this.getTheme().dividerColor }).clip(true)

      Blank()

      Button({ type: ButtonType.Circle }) {
        Text('📋').fontSize(14)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onPasteSample(); })

      Button({ type: ButtonType.Circle }) {
        Text('🔍').fontSize(14)
      }
      .width(28).height(28)
      .backgroundColor(this.searchActive ? '#007AFF' : Color.Transparent)
      .onClick(() => { this.onToggleSearch(); })

      Button({ type: ButtonType.Circle }) {
        Text('🔀').fontSize(14)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onOpenMerge(); })

      Button({ type: ButtonType.Circle }) {
        Text('📤').fontSize(14)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onExport(); })

      Button({ type: ButtonType.Circle }) {
        Text('⚙').fontSize(14).fontColor(this.getTheme().textSecondary)
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onOpenSettings(); })
    }
    .width('100%').height('100%')
    .padding({ left: 4, right: 2 })
    .backgroundColor(this.getTheme().toolbarBackground)
  }

  private getTheme(): ThemeColorMap {
    if (this.isMonokai) return getMonokaiColors();
    if (this.isDark) return getDarkColors();
    return getLightColors();
  }
}
