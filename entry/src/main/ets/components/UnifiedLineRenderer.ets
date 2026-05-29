/**
 * AegisDiff — UnifiedLineRenderer（统一视图行渲染组件）
 *
 * 从 DiffEditorPage 中提取，负责渲染 Unified 视图中的单行。
 * 支持：语法高亮、字符级 diff、搜索高亮、行内编辑。
 */
import { CharSegment } from '../model/DiffModels';
import { TokenHighlighter, Token } from '../engine/TokenHighlighter';

/** Theme 颜色配置（临时，后续统一迁移到 ThemeTokens） */
interface LineTheme {
  lineNumberColor: string;
  prefixAdded: string;
  prefixDeleted: string;
  prefixModified: string;
  prefixDefault: string;
  contentColor: string;
  bgAdded: string;
  bgDeleted: string;
  bgModified: string;
  bgDefault: string;
  bgEditing: string;
  bgSearchMatch: string;
  bgHighlighted: string;
  charAddedColor: string;
}

/** Monokai 主题色 */
const MONOKAI: LineTheme = {
  lineNumberColor: '#75715E',
  prefixAdded: '#A6E22E',
  prefixDeleted: '#F92672',
  prefixModified: '#E6DB74',
  prefixDefault: '#75715E',
  contentColor: '#F8F8F2',
  bgAdded: '#232D1A',
  bgDeleted: '#351B1B',
  bgModified: '#33301A',
  bgDefault: '#272822',
  bgEditing: '#2A2A40',
  bgSearchMatch: '#49483E',
  bgHighlighted: '#3A3A2A',
  charAddedColor: '#A6E22E'
};

/** Light 主题色 */
const LIGHT: LineTheme = {
  lineNumberColor: '#999999',
  prefixAdded: '#1A7F37',
  prefixDeleted: '#BE2E2E',
  prefixModified: '#D4A017',
  prefixDefault: '#CCCCCC',
  contentColor: '#1C1C1C',
  bgAdded: '#E6FFEC',
  bgDeleted: '#FFEBE9',
  bgModified: '#FFF3D4',
  bgDefault: '#FFFFFF',
  bgEditing: '#E3F2FD',
  bgSearchMatch: '#FFD54F',
  bgHighlighted: '#FFF9C4',
  charAddedColor: '#1A7F37'
};

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
  @Link editBuffer: string;
  onLineClick?: () => void;
  onEditSubmit?: (value: string) => void;
  onEditCancel?: () => void;

  build() {
    Row() {
      Text(this.linenoA > 0 ? `${this.linenoA}` : '')
        .fontSize(10).fontColor(this.getTheme().lineNumberColor)
        .width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.linenoB > 0 ? `${this.linenoB}` : '')
        .fontSize(10).fontColor(this.getTheme().lineNumberColor)
        .width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.getPrefix()).fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor(this.getPrefixColor()).width(14).textAlign(TextAlign.Center)
      if (this.isEditing) {
        TextInput({ text: this.editBuffer })
          .fontSize(12).fontFamily('monospace').fontColor(this.getTheme().contentColor)
          .backgroundColor(Color.Transparent).height(22).layoutWeight(1)
          .padding({ left: 6, right: 6 }).border({ width: 1, color: '#007AFF', style: BorderStyle.Dashed })
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

  private getTheme(): LineTheme {
    return this.isMonokai ? MONOKAI : LIGHT;
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
    if (this.isEditing) return t.bgEditing;
    if (this.isSearchMatch) return t.bgSearchMatch;
    if (this.isHighlighted) return t.bgHighlighted;
    if (this.typeNum === 1) return t.bgAdded;
    if (this.typeNum === 2) return t.bgDeleted;
    if (this.typeNum === 3) return t.bgModified;
    return t.bgDefault;
  }
}