/**
 * AegisDiff — DiffOverviewBar（差异概览条，Meld风格）
 * 在滚动区域右侧显示差异块的位置指示器
 */
import { DiffBlock } from '../engine/DiffBlockLocator';

@Component
export struct DiffOverviewBar {
  @Prop blocks: DiffBlock[] = [];
  @Prop totalLines: number = 0;
  @Prop isMonokai: boolean = false;
  @Prop activeIdx: number = 0;
  onJumpToBlock: (idx: number) => void = () => {};

  build() {
    Column() {
      ForEach(this.blocks, (block: DiffBlock, idx: number) => {
        Column() {
          Blank()
        }
        .width(6)
        .height(`${this.blockHeightPct(block)}%`)
        .borderRadius(3)
        .backgroundColor(this.blockColor(block))
        .margin({ top: `${this.blockTopPct(block)}%` })
        .onClick(() => { this.onJumpToBlock(idx); })
      }, (block: DiffBlock, idx: number) => `ob_${idx}`)
    }
    .width(8).height('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ top: 2, bottom: 2 })
    .backgroundColor(this.isMonokai ? '#1E1E1E' : '#F5F5F5')
  }

  private blockTopPct(block: DiffBlock): number {
    if (this.totalLines <= 0) return 0;
    return Math.max(0, (block.startLine / this.totalLines) * 100);
  }

  private blockHeightPct(block: DiffBlock): number {
    if (this.totalLines <= 0) return 0;
    return Math.max(0.5, ((block.endLine - block.startLine + 1) / this.totalLines) * 100);
  }

  private blockColor(block: DiffBlock): string {
    if (block.blockType === 1) return this.isMonokai ? '#A6E22E' : '#1A7F37';
    if (block.blockType === 2) return this.isMonokai ? '#F92672' : '#BE2E2E';
    return this.isMonokai ? '#E6DB74' : '#D4A017';
  }
}
