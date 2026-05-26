/**
 * AegisDiff — SideBySideRenderer（分栏视图行渲染组件）
 *
 * 从 DiffEditorPage 中提取，负责渲染 Side-by-Side 视图中的单行配对。
 * 支持：左右两栏同步显示、同步按钮（左→右 / 右→左）。
 */
@Component
export struct SideBySideRenderer {
  @Prop leftType: number = 0;
  @Prop leftContent: string = '';
  @Prop leftLineNo: number = -1;
  @Prop rightType: number = 0;
  @Prop rightContent: string = '';
  @Prop rightLineNo: number = -1;
  @Prop isSearchMatch: boolean = false;
  @Prop isMonokai: boolean = false;
  @Prop isHighlighted: boolean = false;
  onSyncToRight?: () => void;
  onSyncToLeft?: () => void;

  build() {
    Row() {
      // 左侧列
      Row() {
        Text(this.leftLineNo > 0 ? `${this.leftLineNo}` : '')
          .fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999')
          .width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(this.leftContent)
          .fontSize(11).fontFamily('monospace')
          .fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 4, right: 4 }).layoutWeight(1)
      }.width('46%').height(22).backgroundColor(this.getBg(this.leftType))
      .padding({ right: 1 })

      // 中间操作列（同步按钮）
      Column() {
        if (this.leftType !== 0 || this.rightType !== 0) {
          if (this.leftType === 2) {
            Button({ type: ButtonType.Circle }) {
              Text('→').fontSize(10).fontColor(this.isMonokai ? '#A6E22E' : '#1A7F37')
            }
            .width(22).height(20).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.onSyncToRight) this.onSyncToRight(); })
          }
          if (this.rightType === 1) {
            Button({ type: ButtonType.Circle }) {
              Text('←').fontSize(10).fontColor(this.isMonokai ? '#F92672' : '#BE2E2E')
            }
            .width(22).height(20).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.onSyncToLeft) this.onSyncToLeft(); })
          }
        }
      }.width(26).justifyContent(FlexAlign.Center)

      // 右侧列
      Row() {
        Text(this.rightLineNo > 0 ? `${this.rightLineNo}` : '')
          .fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999')
          .width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(this.rightContent)
          .fontSize(11).fontFamily('monospace')
          .fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 4, right: 4 }).layoutWeight(1)
      }.width('46%').height(22).backgroundColor(this.getBg(this.rightType))
      .padding({ left: 1 })
    }.width('100%').height(22)
  }

  private getBg(type: number): string {
    if (this.isSearchMatch) return this.isMonokai ? '#49483E' : '#FFD54F';
    if (this.isHighlighted) return this.isMonokai ? '#3A3A2A' : '#FFF9C4';
    if (this.isMonokai) {
      if (type === 1) return '#232D1A';
      if (type === 2) return '#351B1B';
      if (type === 3) return '#33301A';
      return '#272822';
    }
    if (type === 1) return '#E6FFEC';
    if (type === 2) return '#FFEBE9';
    if (type === 3) return '#FFF3D4';
    return '#FFFFFF';
  }
}