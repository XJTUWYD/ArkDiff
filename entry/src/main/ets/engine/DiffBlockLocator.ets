/**
 * AegisDiff — DiffBlockLocator 引擎
 * 识别统一视图 DiffLine 数组中的差异块（连续 ADDED/DELETED/MODIFIED 行）
 * 每个块返回其起始索引，供导航使用
 */
import { DiffLine, DiffType } from '../model/DiffModels';

export interface DiffBlock {
  /** 差异块在 unifiedLines 中的起始行索引（0-based） */
  startIndex: number;
  /** 差异块包含的行数 */
  length: number;
}

export class DiffBlockLocator {
  /**
   * 从 Unified 差异行中定位所有差异块
   * @param diffLines Unified 视图的差异行数组
   * @returns 差异块数组（按出现顺序排列）
   */
  static locateBlocks(diffLines: DiffLine[]): DiffBlock[] {
    const blocks: DiffBlock[] = [];
    let i = 0;

    while (i < diffLines.length) {
      // 查找差异块的起始行
      if (DiffBlockLocator.isChangeLine(diffLines[i])) {
        const startIndex = i;
        // 向后遍历，累积连续的差异行
        while (i < diffLines.length && DiffBlockLocator.isChangeLine(diffLines[i])) {
          i++;
        }
        blocks.push({
          startIndex,
          length: i - startIndex
        });
      } else {
        i++;
      }
    }

    return blocks;
  }

  /** 判断是否为差异行（非 UNCHANGED） */
  private static isChangeLine(line: DiffLine): boolean {
    return line.type !== DiffType.UNCHANGED;
  }
}
