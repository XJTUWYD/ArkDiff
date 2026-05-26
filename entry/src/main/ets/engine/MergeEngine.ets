/**
 * AegisDiff — 三路合并引擎
 * 基于 DiffEngine 的 Base↔Mine 和 Base↔Theirs 两组 Diff
 * 识别冲突并生成合并结果
 */
import { DiffEngine } from './DiffEngine';
import { DiffLine, DiffOptions, DiffType } from '../model/DiffModels';

export interface MergeLine {
  content: string;
  type: MergeLineType;
  mineContent: string;
  theirsContent: string;
}

export enum MergeLineType {
  UNCHANGED = 0,
  MINE_ONLY = 1,
  THEIRS_ONLY = 2,
  CONFLICT = 3,
}

export interface MergeResult {
  lines: MergeLine[];
  conflictCount: number;
  hasConflicts: boolean;
}

export class MergeEngine {
  /**
   * 执行三路合并
   * @param baseText 共同祖先
   * @param mineText 我的版本
   * @param theirsText 他人的版本
   * @returns MergeResult
   */
  static merge(baseText: string, mineText: string, theirsText: string): MergeResult {
    const options: DiffOptions = {
      ignoreBlankLines: false,
      enableCharDiff: false
    };

    const baseToMine = DiffEngine.computeDiff(baseText, mineText, options);
    const baseToTheirs = DiffEngine.computeDiff(baseText, theirsText, options);

    // 构建行索引映射：Base 行 → 对应的 Mine 行和 Theirs 行
    const mineMap = MergeEngine.buildLineMap(baseToMine.unifiedLines);
    const theirsMap = MergeEngine.buildLineMap(baseToTheirs.unifiedLines);

    // 基于映射合并
    return MergeEngine.resolveConflicts(
      baseText.split('\n'),
      mineText.split('\n'),
      theirsText.split('\n'),
      mineMap,
      theirsMap
    );
  }

  /**
   * 从 Unified Diff 行构建 Base→Target 的行映射
   * 返回 Map: baseLineIndex → targetLineIndex（-1 表示已删除）
   */
  private static buildLineMap(unifiedLines: DiffLine[]): Map<number, number> {
    const map = new Map<number, number>();
    for (const line of unifiedLines) {
      if (line.lineNumberA > 0) {
        map.set(line.lineNumberA - 1, line.lineNumberB > 0 ? line.lineNumberB - 1 : -1);
      }
    }
    return map;
  }

  /**
   * 基于映射解决冲突
   */
  private static resolveConflicts(
    baseLines: string[],
    mineLines: string[],
    theirsLines: string[],
    mineMap: Map<number, number>,
    theirsMap: Map<number, number>
  ): MergeResult {
    const result: MergeLine[] = [];
    let conflictCount = 0;

    // 收集所有涉及的 Base 行索引
    const allIndices = new Set<number>();
    for (let i = 0; i < baseLines.length; i++) {
      allIndices.add(i);
    }
    mineMap.forEach((_v, k) => allIndices.add(k));
    theirsMap.forEach((_v, k) => allIndices.add(k));

    const sortedIndices = Array.from(allIndices).sort((a, b) => a - b);

    for (const baseIdx of sortedIndices) {
      const mineIdx = mineMap.has(baseIdx) ? mineMap.get(baseIdx)! : baseIdx;
      const theirsIdx = theirsMap.has(baseIdx) ? theirsMap.get(baseIdx)! : baseIdx;

      const baseContent = baseIdx < baseLines.length ? baseLines[baseIdx] : '';
      const mineContent = mineIdx >= 0 && mineIdx < mineLines.length ? mineLines[mineIdx] : '';
      const theirsContent = theirsIdx >= 0 && theirsIdx < theirsLines.length ? theirsLines[theirsIdx] : '';

      const mineChanged = mineContent !== baseContent;
      const theirsChanged = theirsContent !== baseContent;

      if (!mineChanged && !theirsChanged) {
        // 双方均未修改
        result.push({
          content: baseContent,
          type: MergeLineType.UNCHANGED,
          mineContent: baseContent,
          theirsContent: baseContent
        });
      } else if (mineChanged && !theirsChanged) {
        // 仅 Mine 修改 → 接受 Mine
        result.push({
          content: mineContent,
          type: MergeLineType.MINE_ONLY,
          mineContent: mineContent,
          theirsContent: baseContent
        });
      } else if (!mineChanged && theirsChanged) {
        // 仅 Theirs 修改 → 接受 Theirs
        result.push({
          content: theirsContent,
          type: MergeLineType.THEIRS_ONLY,
          mineContent: baseContent,
          theirsContent: theirsContent
        });
      } else {
        // 双方都修改
        if (mineContent === theirsContent) {
          // 双方做了相同修改 → 无冲突
          result.push({
            content: mineContent,
            type: MergeLineType.MINE_ONLY,
            mineContent: mineContent,
            theirsContent: theirsContent
          });
        } else {
          // 冲突！
          conflictCount++;
          result.push({
            content: `<<<<<<< mine\n${mineContent}\n=======\n${theirsContent}\n>>>>>>> theirs`,
            type: MergeLineType.CONFLICT,
            mineContent: mineContent,
            theirsContent: theirsContent
          });
        }
      }
    }

    return {
      lines: result,
      conflictCount: conflictCount,
      hasConflicts: conflictCount > 0
    };
  }
}
