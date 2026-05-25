/**
 * AegisDiff — SideBySideDiffView 组件
 */
import { DiffLine } from '../model/DiffModels';
import { DiffLineItem } from './DiffLineItem';

@Component
export struct SideBySideDiffView {
  @Prop leftLines: DiffLine[] = [];
  @Prop rightLines: DiffLine[] = [];
  @Prop codeFontSize: number = 14;
  @Link highlightedBlockIndex: number;
  @Link currentNavIndex: number;

  build() {
    Row() {
      Column() {
        Text('原始 (A)')
          .fontSize(12).fontColor('#666666').width('100%').height(28)
          .textAlign(TextAlign.Center).backgroundColor('#FAFAFA')

        Scroll() {
          Column() {
            ForEach(this.leftLines, (line: DiffLine, index: number) => {
              DiffLineItem({ diffLine: line, codeFontSize: this.codeFontSize })
            }, (line: DiffLine, index: number) => `l_${index}`)
          }
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('50%').height('100%')

      Column().width(1).height('100%').backgroundColor('#E0E0E0')

      Column() {
        Text('修改后 (B)')
          .fontSize(12).fontColor('#666666').width('100%').height(28)
          .textAlign(TextAlign.Center).backgroundColor('#FAFAFA')

        Scroll() {
          Column() {
            ForEach(this.rightLines, (line: DiffLine, index: number) => {
              DiffLineItem({ diffLine: line, codeFontSize: this.codeFontSize })
            }, (line: DiffLine, index: number) => `r_${index}`)
          }
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }.width('50%').height('100%')
    }.width('100%').layoutWeight(1)
  }
}
