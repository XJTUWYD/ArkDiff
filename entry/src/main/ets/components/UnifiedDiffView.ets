/**
 * AegisDiff — UnifiedDiffView 组件
 */
import { DiffLine } from '../model/DiffModels';
import { DiffLineItem } from './DiffLineItem';

@Component
export struct UnifiedDiffView {
  @Prop diffLines: DiffLine[] = [];
  @Prop codeFontSize: number = 14;
  @Link highlightedBlockIndex: number;
  @Link currentNavIndex: number;

  build() {
    Column() {
      if (this.diffLines.length === 0) {
        Column() {
          Text('点击「执行对比」查看差异结果')
            .fontSize(15).fontColor('#999999')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.diffLines, (line: DiffLine, index: number) => {
              DiffLineItem({ diffLine: line, codeFontSize: this.codeFontSize })
            }, (line: DiffLine, index: number) => `${index}_${line.lineNumberA}_${line.lineNumberB}`)
          }
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      }
    }
    .width('100%').layoutWeight(1)
  }
}
