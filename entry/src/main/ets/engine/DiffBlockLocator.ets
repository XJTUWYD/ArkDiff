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
  /** 差异块主要类型（1=added, 2=deleted, 3=modified） */
  blockType: number;
  /** 起始行号（在 unifiedLines 中的 0-based 位置） */
  startLine: number;
  /** 结束行号（在 unifiedLines 中的 0-based 位置） */
  endLine: number;
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
      if (DiffBlockLocator.isChangeLine(diffLines[i])) {
        const startIndex = i;
        let blockType = diffLines[i].type === DiffType.ADDED ? 1 :
          diffLines[i].type === DiffType.DELETED ? 2 : 3;
        while (i < diffLines.length && DiffBlockLocator.isChangeLine(diffLines[i])) {
          if (blockType === 3) {
            if (diffLines[i].type === DiffType.ADDED) blockType = 1;
            else if (diffLines[i].type === DiffType.DELETED) blockType = 2;
          }
          i++;
        }
        blocks.push({
          startIndex,
          length: i - startIndex,
          blockType,
          startLine: startIndex,
          endLine: i - 1
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
