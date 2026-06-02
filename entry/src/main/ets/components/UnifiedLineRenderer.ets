/**
 * AegisDiff — UnifiedLineRenderer（统一视图行渲染组件）
 *
 * 从 DiffEditorPage 中提取，负责渲染 Unified 视图中的单行。
 * 支持：语法高亮、字符级 diff、搜索高亮、行内编辑。
 */
import { CharSegment } from '../model/DiffModels';
import { TokenHighlighter, Token } from '../engine/TokenHighlighter';
import { ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors } from '../utils/ThemeTokens';

@Component
export struct UnifiedLineRenderer {
  @Prop typeNum: number = 0;
  @Prop content: string = '';
  @Prop linenoA: number = -1;
  @Prop linenoB: number = -1;
  @Prop searchKeyword: string = '';
  @Prop isSearchMatch: boolean = false;
  @Prop isMonokai: boolean = false;
  @Prop isHighlighted: boolean = false;
  @Prop charSegments: CharSegment[] = [];
  @Prop isEditing: boolean = false;
  @Prop isDark: boolean = false;
  @Link editBuffer: string;
  onLineClick?: () => void;
  onEditSubmit?: (value: string) => void;
  onEditCancel?: () => void;

  build() {
    Row() {
      Text(this.linenoA > 0 ? `${this.linenoA}` : '')
        .fontSize(10).fontColor(this.getTheme().gutterTextColor)
        .width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.linenoB > 0 ? `${this.linenoB}` : '')
        .fontSize(10).fontColor(this.getTheme().gutterTextColor)
        .width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.getPrefix()).fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor(this.getPrefixColor()).width(14).textAlign(TextAlign.Center)
      if (this.isEditing) {
        TextInput({ text: this.editBuffer })
          .fontSize(12).fontFamily('monospace').fontColor(this.getTheme().contentColor)
          .backgroundColor(Color.Transparent).layoutWeight(1)
          .border({ width: 0 }).borderRadius(0)
          .padding(0)
          .constraintSize({ minHeight: 0 })
          .defaultFocus(true)
          .onChange((v: string) => { this.editBuffer = v; })
          .onSubmit((_: EnterKeyType) => { if (this.onEditSubmit) this.onEditSubmit(this.editBuffer); })
      } else {
        this.contentText()
      }
    }.width('100%').height(22).backgroundColor(this.getBg())
    .onClick(() => { if (!this.isEditing && this.onLineClick) this.onLineClick(); })
  }

  @Builder
  contentText() {
    if (this.charSegments.length > 0 && this.typeNum === 3) {
      Text() {
        ForEach(this.charSegments, (seg: CharSegment, idx: number) => {
          Span(this.content.substring(seg.start, seg.end))
            .fontSize(12).fontFamily('monospace')
            .fontColor(seg.type === 1 ? this.getTheme().charAddedColor : this.getTheme().contentColor)
        }, (seg: CharSegment, idx: number) => `seg_${idx}`)
      }
      .padding({ left: 6 })
    } else {
      this.syntaxText()
    }
  }

  @Builder
  syntaxText() {
    Text() {
      ForEach(TokenHighlighter.tokenize(this.content), (tok: Token, _idx: number) => {
        Span(this.content.substring(tok.start, tok.end))
          .fontSize(12).fontFamily('monospace')
          .fontColor(TokenHighlighter.getTokenColor(tok.type, this.isMonokai))
      }, (tok: Token, _idx: number) => `tk_${_idx}`)
    }
    .padding({ left: 6 })
  }

  private getTheme(): ThemeColorMap {
    if (this.isMonokai) return getMonokaiColors();
    if (this.isDark) return getDarkColors();
    return getLightColors();
  }

  private getPrefix(): string {
    if (this.typeNum === 1) return '+';
    if (this.typeNum === 2) return '-';
    if (this.typeNum === 3) return '~';
    return ' ';
  }

  private getPrefixColor(): string {
    const t = this.getTheme();
    if (this.typeNum === 1) return t.prefixAdded;
    if (this.typeNum === 2) return t.prefixDeleted;
    if (this.typeNum === 3) return t.prefixModified;
    return t.prefixDefault;
  }

  private getBg(): string {
    const t = this.getTheme();
    if (this.isSearchMatch) return t.searchMatchBackground;
    if (this.isHighlighted) return t.highlightedBlockBackground;
    if (this.typeNum === 1) return t.diffAddedBackground;
    if (this.typeNum === 2) return t.diffDeletedBackground;
    if (this.typeNum === 3) return t.diffModifiedBackground;
    return t.diffUnchangedBackground;
  }
}
