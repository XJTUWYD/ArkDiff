/**
 * AegisDiff — DiffNavigator 组件
 * 差异块导航条，支持打开文件 (Meld 风格)
 */
import { ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors } from '../utils/ThemeTokens';

@Component
export struct DiffNavigator {
  @Prop totalBlocks: number = 0;
  @Prop currentIndex: number = 0;
  @Prop isMonokai: boolean = false;
  @Prop isDark: boolean = false;
  onNavigateTo: (index: number) => void = () => {};
  onPickFileA?: () => void;
  onPickFileB?: () => void;

  build() {
    Row() {
      Button('\u229E A').fontSize(10).height(24).type(ButtonType.Capsule)
        .backgroundColor(this.getTheme().diffAddedBackground)
        .fontColor(this.getTheme().diffAddedForeground)
        .borderRadius(8).padding({ left: 8, right: 8 })
        .onClick(() => { if (this.onPickFileA) this.onPickFileA(); })
      Button('\u229F B').fontSize(10).height(24).type(ButtonType.Capsule)
        .backgroundColor(this.getTheme().diffDeletedBackground)
        .fontColor(this.getTheme().diffDeletedForeground)
        .borderRadius(8).padding({ left: 8, right: 8 }).margin({ left: 4 })
        .onClick(() => { if (this.onPickFileB) this.onPickFileB(); })

      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('\u25B2').fontSize(14)
            .fontColor(this.currentIndex > 0 ? this.getTheme().textPrimary : this.getTheme().textSecondary)
        }
        .width(28).height(28).backgroundColor(Color.Transparent)
        .enabled(this.currentIndex > 0)
        .onClick(() => { if (this.currentIndex > 0) { this.onNavigateTo(this.currentIndex - 1); } })

        Text(`${this.currentIndex + 1} / ${this.totalBlocks}`)
          .fontSize(13).fontColor(this.getTheme().textSecondary).fontWeight(FontWeight.Medium)
          .width(64).textAlign(TextAlign.Center)

        Button({ type: ButtonType.Circle }) {
          Text('\u25BC').fontSize(14)
            .fontColor(this.currentIndex < this.totalBlocks - 1 ? this.getTheme().textPrimary : this.getTheme().textSecondary)
        }
        .width(28).height(28).backgroundColor(Color.Transparent)
        .enabled(this.currentIndex < this.totalBlocks - 1)
        .onClick(() => { if (this.currentIndex < this.totalBlocks - 1) { this.onNavigateTo(this.currentIndex + 1); } })
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center)

      Row().width(28).height(28)
    }
    .width('100%').height('100%').padding({ left: 8, right: 8 })
    .backgroundColor(this.getTheme().surfaceBackground)
  }

  private getTheme(): ThemeColorMap {
    if (this.isMonokai) return getMonokaiColors();
    if (this.isDark) return getDarkColors();
    return getLightColors();
  }
}
