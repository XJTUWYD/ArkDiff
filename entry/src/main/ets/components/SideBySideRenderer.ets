/**
 * AegisDiff — SideBySideRenderer（分栏视图行渲染组件）
 *
 * 负责渲染 Side-by-Side 视图中的单行配对。
 * 支持：左右两栏同步显示、同步按钮、行内编辑。
 */
import { ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors } from '../utils/ThemeTokens';

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
  @Prop isDark: boolean = false;
  @Prop isHighlighted: boolean = false;
  @Prop isLeftEditing: boolean = false;
  @Prop isRightEditing: boolean = false;
  @Prop isLeftBlockStart: boolean = false;
  @Prop isRightBlockStart: boolean = false;
  @Link sideEditBuffer: string;
  onSyncToRight?: () => void;
  onSyncToLeft?: () => void;
  onLeftClick?: () => void;
  onRightClick?: () => void;
  onLeftEditSubmit?: (value: string) => void;
  onRightEditSubmit?: (value: string) => void;
  onLeftEditCancel?: () => void;
  onRightEditCancel?: () => void;

  build() {
    Row() {
      // 左侧列
      Row() {
        Text(this.leftLineNo > 0 ? `${this.leftLineNo}` : '')
          .fontSize(10).fontColor(this.getTheme().gutterTextColor)
          .width(24).textAlign(TextAlign.End).fontFamily('monospace')
        if (this.isLeftEditing) {
          TextInput({ text: this.sideEditBuffer })
            .fontSize(11).fontFamily('monospace')
            .fontColor(this.getTheme().contentColor)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .border({ width: 0 }).borderRadius(0)
            .padding(0)
            .constraintSize({ minHeight: 0 })
            .defaultFocus(true)
            .onChange((v: string) => { this.sideEditBuffer = v; })
            .onSubmit((_: EnterKeyType) => {
              if (this.onLeftEditSubmit) this.onLeftEditSubmit(this.sideEditBuffer);
            })
        } else {
          Text(this.leftContent)
            .fontSize(11).fontFamily('monospace')
            .fontColor(this.getTheme().contentColor)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 4, right: 4 }).layoutWeight(1)
        }
      }.width('46%').height(22)
      .backgroundColor(this.getBg(this.leftType))
      .padding({ right: 1 })
      .onClick(() => {
        if (!this.isLeftEditing && this.onLeftClick) this.onLeftClick();
      })

      // 中间操作列
      Column() {
        if (this.isLeftEditing || this.isRightEditing) {
          Button({ type: ButtonType.Circle }) {
            Text('✕').fontSize(10).fontColor(this.getTheme().diffDeletedForeground)
          }
          .width(22).height(20).backgroundColor(Color.Transparent)
          .onClick(() => {
            if (this.isLeftEditing && this.onLeftEditCancel) this.onLeftEditCancel();
            if (this.isRightEditing && this.onRightEditCancel) this.onRightEditCancel();
          })
        } else if (this.leftType !== 0 || this.rightType !== 0) {
          if ((this.leftType === 2 || this.leftType === 3) && this.isLeftBlockStart) {
            Button({ type: ButtonType.Circle }) {
              Text('→').fontSize(10).fontColor(this.getTheme().diffAddedForeground)
            }
            .width(22).height(20).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.onSyncToRight) this.onSyncToRight(); })
          }
          if ((this.rightType === 1 || this.rightType === 3) && this.isRightBlockStart) {
            Button({ type: ButtonType.Circle }) {
              Text('←').fontSize(10).fontColor(this.getTheme().diffDeletedForeground)
            }
            .width(22).height(20).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.onSyncToLeft) this.onSyncToLeft(); })
          }
        }
      }.width(26).justifyContent(FlexAlign.Center)

      // 右侧列
      Row() {
        Text(this.rightLineNo > 0 ? `${this.rightLineNo}` : '')
          .fontSize(10).fontColor(this.getTheme().gutterTextColor)
          .width(24).textAlign(TextAlign.End).fontFamily('monospace')
        if (this.isRightEditing) {
          TextInput({ text: this.sideEditBuffer })
            .fontSize(11).fontFamily('monospace')
            .fontColor(this.getTheme().contentColor)
            .backgroundColor(Color.Transparent).layoutWeight(1)
            .border({ width: 0 }).borderRadius(0)
            .padding(0)
            .constraintSize({ minHeight: 0 })
            .defaultFocus(true)
            .onChange((v: string) => { this.sideEditBuffer = v; })
            .onSubmit((_: EnterKeyType) => {
              if (this.onRightEditSubmit) this.onRightEditSubmit(this.sideEditBuffer);
            })
        } else {
          Text(this.rightContent)
            .fontSize(11).fontFamily('monospace')
            .fontColor(this.getTheme().contentColor)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 4, right: 4 }).layoutWeight(1)
        }
      }.width('46%').height(22)
      .backgroundColor(this.getBg(this.rightType))
      .padding({ left: 1 })
      .onClick(() => {
        if (!this.isRightEditing && this.onRightClick) this.onRightClick();
      })
    }.width('100%').height(22)
  }

  private getTheme(): ThemeColorMap {
    if (this.isMonokai) return getMonokaiColors();
    if (this.isDark) return getDarkColors();
    return getLightColors();
  }

  private getBg(type: number): string {
    const t = this.getTheme();
    if (this.isSearchMatch) return t.searchMatchBackground;
    if (this.isHighlighted) return t.highlightedBlockBackground;
    if (type === 1) return t.diffAddedBackground;
    if (type === 2) return t.diffDeletedBackground;
    if (type === 3) return t.diffModifiedBackground;
    return t.diffUnchangedBackground;
  }
}
