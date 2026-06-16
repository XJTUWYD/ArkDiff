/**
 * ArkDiff — DiffToolbar（Meld 风格工具栏）
 *
 * 仅分栏视图，无统一/分栏切换，无三路合并。
 * 图标使用 Unicode 符号替代 emoji。
 * 文件 A/B 按钮用不同图标+颜色区分（A=folder 绿，B=doc 红，对齐全局 A/B 颜色约定）。
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
  @Prop canUndo: boolean = false;
  @Prop canRedo: boolean = false;
  onRunDiff: () => void = () => {};
  onPasteSample: () => void = () => {};
  onOpenSettings: () => void = () => {};
  onToggleSearch: () => void = () => {};
  onExport: () => void = () => {};
  onUndo: () => void = () => {};
  onRedo: () => void = () => {};
  onPickFileA?: () => void;
  onPickFileB?: () => void;

  build() {
    Row() {
      // 文件 A：folder 图标 + 绿色（对齐 A=diffAdded 绿的约定）
      if (this.onPickFileA) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.folder')).fontSize(16).fontColor([this.getTheme().diffAddedForeground])
        }
        .width(28).height(28).backgroundColor(Color.Transparent)
        .onClick(() => { if (this.onPickFileA) this.onPickFileA(); })
      }
      // 文件 B：doc 图标 + 红色（对齐 B=diffDeleted 红的约定），与 A 一眼可区分
      if (this.onPickFileB) {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.doc')).fontSize(16).fontColor([this.getTheme().diffDeletedForeground])
        }
        .width(28).height(28).backgroundColor(Color.Transparent)
        .onClick(() => { if (this.onPickFileB) this.onPickFileB(); })
      }

      // 撤销 / 重做（激活存量 undo/redo 能力）
      Button({ type: ButtonType.Circle }) {
        Text('↶').fontSize(15).fontColor(this.canUndo ? this.getTheme().textPrimary : this.getTheme().gutterTextColor)
      }
      .width(28).height(28).backgroundColor(Color.Transparent).enabled(this.canUndo)
      .onClick(() => { this.onUndo(); })

      Button({ type: ButtonType.Circle }) {
        Text('↷').fontSize(15).fontColor(this.canRedo ? this.getTheme().textPrimary : this.getTheme().gutterTextColor)
      }
      .width(28).height(28).backgroundColor(Color.Transparent).enabled(this.canRedo)
      .onClick(() => { this.onRedo(); })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph(this.isComputing ? $r('sys.symbol.ellipsis_message_1') : $r('sys.symbol.arrow_clockwise'))
          .fontSize(16).fontColor([Color.White])
      }
      .width(28).height(28).backgroundColor('#007AFF').enabled(!this.isComputing)
      .onClick(() => { this.onRunDiff(); })

      Blank()

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.doc')).fontSize(16).fontColor([this.getTheme().textPrimary])
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onPasteSample(); })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(16)
          .fontColor([this.searchActive ? Color.White : this.getTheme().textPrimary])
      }
      .width(28).height(28)
      .backgroundColor(this.searchActive ? '#007AFF' : Color.Transparent)
      .onClick(() => { this.onToggleSearch(); })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.paperplane')).fontSize(16).fontColor([this.getTheme().textPrimary])
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
      .onClick(() => { this.onExport(); })

      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.gearshape')).fontSize(16).fontColor([this.getTheme().textSecondary])
      }
      .width(28).height(28).backgroundColor(Color.Transparent)
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
