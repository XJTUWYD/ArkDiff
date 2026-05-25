/**
 * AegisDiff — 差异统计计算器
 * 根据 DiffLine 数组计算新增/删除/修改/未变更行数及相似度
 */
import { DiffLine, DiffStats, DiffType } from '../model/DiffModels';

export class StatsCalculator {
  /**
   * 根据统一视图的 DiffLine 数组计算统计信息
   * @param diffLines 统一视图的差异行数组
   * @returns DiffStats 统计结果
   */
  static calculate(diffLines: DiffLine[]): DiffStats {
    let addedCount = 0;
    let deletedCount = 0;
    let modifiedCount = 0;
    let unchangedCount = 0;
    let diffBlockCount = 0;
    let inDiffBlock = false;

    for (const line of diffLines) {
      switch (line.type) {
        case DiffType.ADDED:
          addedCount++;
          if (!inDiffBlock) {
            diffBlockCount++;
            inDiffBlock = true;
          }
          break;
        case DiffType.DELETED:
          deletedCount++;
          if (!inDiffBlock) {
            diffBlockCount++;
            inDiffBlock = true;
          }
          break;
        case DiffType.MODIFIED:
          modifiedCount++;
          if (!inDiffBlock) {
            diffBlockCount++;
            inDiffBlock = true;
          }
          break;
        case DiffType.UNCHANGED:
          unchangedCount++;
          inDiffBlock = false;
          break;
      }
    }

    // 相似度计算：基于 LCS 长度 / max(A.length, B.length)
    const totalChanged = addedCount + deletedCount + modifiedCount;
    const total = unchangedCount + totalChanged;
    let similarityPercent = 0;
    if (total > 0) {
      similarityPercent = Math.round((unchangedCount / total) * 1000) / 10;
    } else if (total === 0) {
      similarityPercent = 100.0;
    }

    return {
      addedCount,
      deletedCount,
      modifiedCount,
      unchangedCount,
      similarityPercent,
      diffBlockCount
    };
  }
}
