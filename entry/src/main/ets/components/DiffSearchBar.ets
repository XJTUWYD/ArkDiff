/**
 * AegisDiff — DiffSearchBar（搜索栏组件）
 *
 * 从 DiffEditorPage 中提取的搜索 UI 与逻辑。
 * 支持：关键字输入、搜索、上/下一个结果导航、结果计数。
 */
@Component
export struct DiffSearchBar {
  @State searchKeyword: string = '';
  @Prop totalMatches: number = 0;
  @Prop currentMatchIndex: number = 0;
  onSearch?: (keyword: string) => void;
  onNavigateNext?: () => void;
  onNavigatePrev?: () => void;
  onClose?: () => void;

  build() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('✕').fontSize(12).fontColor('#999999')
      }
      .width(24).height(24).backgroundColor(Color.Transparent)
      .onClick(() => { if (this.onClose) this.onClose(); })

      TextInput({ placeholder: '搜索...', text: this.searchKeyword })
        .fontSize(12).height(28).layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: '#E0E0E0', style: BorderStyle.Solid })
        .borderRadius(14).padding({ left: 10, right: 10 })
        .onChange((v: string) => {
          this.searchKeyword = v;
          if (this.onSearch) this.onSearch(v);
        })
        .onSubmit((_: EnterKeyType) => {
          if (this.onNavigateNext) this.onNavigateNext();
        })

      if (this.totalMatches > 0) {
        Text(`${this.currentMatchIndex + 1}/${this.totalMatches}`)
          .fontSize(11).fontColor('#999999').margin({ left: 6, right: 4 })
      }

      Button({ type: ButtonType.Circle }) {
        Text('↑').fontSize(14).fontColor('#333333')
      }
      .width(26).height(26).backgroundColor('#F0F0F0')
      .enabled(this.totalMatches > 0)
      .onClick(() => { if (this.onNavigatePrev) this.onNavigatePrev(); })

      Button({ type: ButtonType.Circle }) {
        Text('↓').fontSize(14).fontColor('#333333')
      }
      .width(26).height(26).backgroundColor('#F0F0F0').margin({ left: 4 })
      .enabled(this.totalMatches > 0)
      .onClick(() => { if (this.onNavigateNext) this.onNavigateNext(); })
    }
    .width('100%').height(40).padding({ left: 8, right: 8 })
    .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })
  }
}