/**
 * AegisDiff — DiffViewModel
 * 核心状态管理层，通过 @Provide 注入整个页面树
 * 管理文本输入、Diff 计算、视图切换、差异导航
 */
import { DiffEngine } from '../engine/DiffEngine';
import { DiffBlockLocator, DiffBlock } from '../engine/DiffBlockLocator';
import {
  DiffResult,
  DiffOptions,
  ViewMode,
  DiffStats
} from '../model/DiffModels';

const defaultOptions: DiffOptions = {
  ignoreBlankLines: false,
  enableCharDiff: false
};

export class DiffViewModel {
  // ========== 输入状态 ==========
  textA: string = '';
  textB: string = '';

  // ========== 计算结果 ==========
  diffResult: DiffResult | null = null;

  // ========== 视图状态 ==========
  viewMode: ViewMode = ViewMode.UNIFIED;
  currentDiffBlockIndex: number = 0;
  isComputing: boolean = false;
  inputPanelVisible: boolean = true;

  // ========== 差异块缓存 ==========
  diffBlocks: DiffBlock[] = [];
  highlightedBlockIndex: number = -1;

  /**
   * 执行 Diff 计算
   */
  runDiff(): void {
    if (this.textA.length === 0 && this.textB.length === 0) {
      return;
    }

    this.isComputing = true;

    try {
      this.diffResult = DiffEngine.computeDiff(this.textA, this.textB, defaultOptions);
      this.diffBlocks = DiffBlockLocator.locateBlocks(this.diffResult.unifiedLines);
      this.currentDiffBlockIndex = 0;
    } catch (e) {
      console.error('DiffViewModel.runDiff error:', JSON.stringify(e));
    } finally {
      this.isComputing = false;
    }
  }

  /**
   * 切换视图模式
   */
  switchView(mode: ViewMode): void {
    this.viewMode = mode;
  }

  /**
   * 差异导航
   */
  navigateToBlock(index: number): void {
    if (index >= 0 && index < this.diffBlocks.length) {
      this.currentDiffBlockIndex = index;
    }
  }

  /**
   * 粘贴示例代码
   */
  pasteSample(sampleA: string, sampleB: string): void {
    this.textA = sampleA;
    this.textB = sampleB;
  }

  /**
   * 获取差异统计
   */
  get stats(): DiffStats | null {
    return this.diffResult?.stats ?? null;
  }

  /**
   * 总差异块数
   */
  get totalBlocks(): number {
    return this.diffBlocks.length;
  }
}
