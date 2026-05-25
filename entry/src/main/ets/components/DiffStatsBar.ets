/**
 * AegisDiff — DiffStatsBar 组件
 */
import { DiffStats } from '../model/DiffModels';

@Component
export struct DiffStatsBar {
  @Prop stats: DiffStats | null = null;

  build() {
    Row() {
      if (this.stats !== null) {
        Text(`+${this.stats!.addedCount}`)
          .fontSize(13).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
          .margin({ right: 12 })
        Text(`-${this.stats!.deletedCount}`)
          .fontSize(13).fontColor('#BE2E2E').fontWeight(FontWeight.Medium)
          .margin({ right: 12 })
        Text(`~${this.stats!.modifiedCount}`)
          .fontSize(13).fontColor('#D4A017').fontWeight(FontWeight.Medium)
          .margin({ right: 16 })
        Divider().vertical(true).strokeWidth(1).color('#E0E0E0')
          .height(20).margin({ left: 4, right: 12 })
        Text(`相似度 ${this.stats!.similarityPercent}%`)
          .fontSize(13).fontColor('#666666').layoutWeight(1)
        Text(`${this.stats!.diffBlockCount} 处差异`)
          .fontSize(13).fontColor('#666666')
      }
    }
    .width('100%')
    .height(this.stats !== null ? 36 : 0)
    .padding(this.stats !== null ? { left: 16, right: 16 } : 0)
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: this.stats !== null ? 1 : 0 }, color: '#E0E0E0' })
  }
}
