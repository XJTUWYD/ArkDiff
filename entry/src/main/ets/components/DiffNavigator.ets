/**
 * AegisDiff — DiffNavigator 组件
 */
@Component
export struct DiffNavigator {
  @Prop totalBlocks: number = 0;
  @Prop currentIndex: number = 0;
  @Prop inputPanelVisible: boolean = true;
  onNavigateTo: (index: number) => void = () => {};
  onToggleInput: () => void = () => {};

  build() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text(this.inputPanelVisible ? '^' : 'v').fontSize(14).fontColor('#666666')
      }
      .width(32).height(32).backgroundColor(Color.Transparent)
      .onClick(() => { this.onToggleInput(); })

      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('<').fontSize(16)
            .fontColor(this.currentIndex > 0 ? '#1C1C1C' : '#999999')
        }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .enabled(this.currentIndex > 0)
        .onClick(() => {
          if (this.currentIndex > 0) { this.onNavigateTo(this.currentIndex - 1); }
        })

        Text(`${this.currentIndex + 1} / ${this.totalBlocks}`)
          .fontSize(14).fontColor('#666666').fontWeight(FontWeight.Medium)
          .width(64).textAlign(TextAlign.Center)

        Button({ type: ButtonType.Circle }) {
          Text('>').fontSize(16)
            .fontColor(this.currentIndex < this.totalBlocks - 1 ? '#1C1C1C' : '#999999')
        }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .enabled(this.currentIndex < this.totalBlocks - 1)
        .onClick(() => {
          if (this.currentIndex < this.totalBlocks - 1) { this.onNavigateTo(this.currentIndex + 1); }
        })
      }
      .layoutWeight(1).justifyContent(FlexAlign.Center)

      Row().width(32).height(32)
    }
    .width('100%').height('100%').padding({ left: 8, right: 8 })
    .backgroundColor('#FFFFFF')
  }
}
