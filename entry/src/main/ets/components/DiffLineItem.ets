/**
 * AegisDiff — DiffLineItem 组件
 */
import { DiffLine, DiffType } from '../model/DiffModels';

@Component
export struct DiffLineItem {
  @Prop diffLine: DiffLine;
  @Prop isHighlighted: boolean = false;
  @Prop codeFontSize: number = 14;

  build() {
    Row() {
      Row() {
        Text(this.getPrefix())
          .fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(this.getPrefixColor())
          .width(16).textAlign(TextAlign.Center)

        Text(this.getLineNums())
          .fontSize(12).fontColor('#999999')
          .textAlign(TextAlign.End).layoutWeight(1)
      }
      .width(52).height(24)
      .backgroundColor(this.getGutterBg())
      .padding({ left: 4, right: 4 })

      Text(this.diffLine.content)
        .fontSize(this.codeFontSize)
        .fontColor('#1C1C1C')
        .fontFamily('monospace')
        .maxLines(1).textOverflow({ overflow: TextOverflow.None })
        .padding({ left: 8, right: 8 }).height(24)
    }
    .width('100%').height(24)
    .backgroundColor(this.getBg())
  }

  private getPrefix(): string {
    switch (this.diffLine.type) {
      case DiffType.ADDED: return '+';
      case DiffType.DELETED: return '-';
      case DiffType.MODIFIED: return '~';
      default: return ' ';
    }
  }

  private getLineNums(): string {
    const a = this.diffLine.lineNumberA > 0 ? `${this.diffLine.lineNumberA}` : '';
    const b = this.diffLine.lineNumberB > 0 ? `${this.diffLine.lineNumberB}` : '';
    return a || b || '';
  }

  private getBg(): string {
    if (this.isHighlighted) return '#FFD54F';
    switch (this.diffLine.type) {
      case DiffType.ADDED: return '#E6FFEC';
      case DiffType.DELETED: return '#FFEBE9';
      case DiffType.MODIFIED: return '#FFF3D4';
      default: return '#FFFFFF';
    }
  }

  private getGutterBg(): string {
    switch (this.diffLine.type) {
      case DiffType.ADDED: return '#C6F0D0';
      case DiffType.DELETED: return '#F0C8C4';
      case DiffType.MODIFIED: return '#F0DFA0';
      default: return 'transparent';
    }
  }

  private getPrefixColor(): string {
    switch (this.diffLine.type) {
      case DiffType.ADDED: return '#1A7F37';
      case DiffType.DELETED: return '#BE2E2E';
      case DiffType.MODIFIED: return '#D4A017';
      default: return '#999999';
    }
  }
}
