/**
 * AegisDiff — DiffSearchBar（搜索栏组件）
 *
 * 支持：关键字输入、搜索、上/下一个结果导航、结果计数。
 */
import { ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors } from '../utils/ThemeTokens';

@Component
export struct DiffSearchBar {
  @State searchKeyword: string = '';
  @Prop totalMatches: number = 0;
  @Prop currentMatchIndex: number = 0;
  @Prop isMonokai: boolean = false;
  @Prop isDark: boolean = false;
  onSearch?: (keyword: string) => void;
  onNavigateNext?: () => void;
  onNavigatePrev?: () => void;
  onClose?: () => void;

  build() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('\u2715').fontSize(12).fontColor(this.getTheme().textSecondary)
      }
      .width(24).height(24).backgroundColor(Color.Transparent)
      .onClick(() => { if (this.onClose) this.onClose(); })

      TextInput({ placeholder: '搜索...', text: this.searchKeyword })
        .fontSize(12).height(28).layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: this.getTheme().dividerColor, style: BorderStyle.Solid })
        .borderRadius(14).padding({ left: 10, right: 10 })
        .onChange((v: string) => { this.searchKeyword = v; if (this.onSearch) this.onSearch(v); })
        .onSubmit((_: EnterKeyType) => { if (this.onNavigateNext) this.onNavigateNext(); })

      if (this.totalMatches > 0) {
        Text(`${this.currentMatchIndex + 1}/${this.totalMatches}`)
          .fontSize(11).fontColor(this.getTheme().textSecondary).margin({ left: 6, right: 4 })
      }

      Button({ type: ButtonType.Circle }) {
        Text('\u25B2').fontSize(12).fontColor(this.getTheme().textPrimary)
      }
      .width(26).height(26).backgroundColor(this.getTheme().dividerColor)
      .enabled(this.totalMatches > 0)
      .onClick(() => { if (this.onNavigatePrev) this.onNavigatePrev(); })

      Button({ type: ButtonType.Circle }) {
        Text('\u25BC').fontSize(12).fontColor(this.getTheme().textPrimary)
      }
      .width(26).height(26).backgroundColor(this.getTheme().dividerColor).margin({ left: 4 })
      .enabled(this.totalMatches > 0)
      .onClick(() => { if (this.onNavigateNext) this.onNavigateNext(); })
    }
    .width('100%').height(40).padding({ left: 8, right: 8 })
    .backgroundColor(this.getTheme().surfaceBackground).border({ width: { bottom: 1 }, color: this.getTheme().dividerColor })
  }

  private getTheme(): ThemeColorMap {
    if (this.isMonokai) return getMonokaiColors();
    if (this.isDark) return getDarkColors();
    return getLightColors();
  }
}
