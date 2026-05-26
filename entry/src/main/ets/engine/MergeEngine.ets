/**
 * AegisDiff — 三路合并引擎（块级重构版）
 *
 * 基于 Base↔Mine 和 Base↔Theirs 两组 Diff 的 chunk 级对齐
 * 支持块级冲突识别与解决
 */
import { DiffEngine } from './DiffEngine';
import {
  DiffChunk,
  DiffChunkType,
  DiffLine,
  DiffOptions,
  DiffType,
  MergeConflictChunk
} from '../model/DiffModels';

/** 合并行的类型 */
export enum MergeLineType {
  UNCHANGED = 0,
  MINE_ONLY = 1,
  THEIRS_ONLY = 2,
  CONFLICT = 3
}

/** 合并行 */
export interface MergeLine {
  content: string;
  type: MergeLineType;
  mineContent: string;
  theirsContent: string;
  baseContent: string;
}

/** 合并结果 */
export interface MergeResult {
  lines: MergeLine[];
  conflictChunks: MergeConflictChunk[];
  conflictCount: number;
  hasConflicts: boolean;
}

/** 合并动作 */
export enum MergeAction {
  ACCEPT_MINE = 0,
  ACCEPT_THEIRS = 1,
  KEEP_BOTH = 2,
  EDIT = 3
}

export class MergeEngine {
  private static options: DiffOptions = {
    ignoreBlankLines: false,
    enableCharDiff: false
  };

  /**
   * 执行三路合并
   * @param baseText  共同祖先
   * @param mineText  我的版本
   * @param theirsText 他人的版本
   * @returns MergeResult 包含合并行和冲突块
   */
  static merge(baseText: string, mineText: string, theirsText: string): MergeResult {
    // Step 1: 执行两组 diff
    const baseToMine = DiffEngine.computeDiff(baseText, mineText, MergeEngine.options);
    const baseToTheirs = DiffEngine.computeDiff(baseText, theirsText, MergeEngine.options);

    // Step 2: 将两组 diff 转换为 chunk 列表
    const mineChunks = MergeEngine.buildChunks(baseToMine.unifiedLines);
    const theirsChunks = MergeEngine.buildChunks(baseToTheirs.unifiedLines);

    // Step 3: 块级合并
    return MergeEngine.mergeChunks(
      baseText.split('\n'),
      mineText.split('\n'),
      theirsText.split('\n'),
      mineChunks,
      theirsChunks
    );
  }

  /**
   * 从 unified diff 行构建 DiffChunk 列表
   */
  private static buildChunks(unifiedLines: DiffLine[]): DiffChunk[] {
    const chunks: DiffChunk[] = [];
    let i = 0;

    while (i < unifiedLines.length) {
      const line = unifiedLines[i];

      if (line.type === DiffType.UNCHANGED) {
        // 收集连续未改变的行
        const start = i;
        while (i < unifiedLines.length && unifiedLines[i].type === DiffType.UNCHANGED) {
          i++;
        }
        const seg = unifiedLines.slice(start, i);
        chunks.push({
          chunkType: DiffChunkType.EQUAL,
          startA: seg[0].lineNumberA,
          countA: seg.length,
          startB: seg[0].lineNumberB,
          countB: seg.length,
          lines: seg
        });
      } else {
        // 收集连续差异行（包含 INSERT 和 DELETE 的混合段）
        const start = i;
        let hasDelete = false;
        let hasAdd = false;
        while (i < unifiedLines.length && unifiedLines[i].type !== DiffType.UNCHANGED) {
          if (unifiedLines[i].type === DiffType.DELETED || unifiedLines[i].type === DiffType.MODIFIED) {
            hasDelete = true;
          }
          if (unifiedLines[i].type === DiffType.ADDED || unifiedLines[i].type === DiffType.MODIFIED) {
            hasAdd = true;
          }
          i++;
        }
        const seg = unifiedLines.slice(start, i);

        // 判断块类型
        let chunkType: DiffChunkType;
        // 找到 A 侧和 B 侧的有效行号范围
        let startA = -1;
        let startB = -1;
        let countA = 0;
        let countB = 0;

        for (const l of seg) {
          if (l.lineNumberA > 0) {
            if (startA < 0) startA = l.lineNumberA;
            countA++;
          }
          if (l.lineNumberB > 0) {
            if (startB < 0) startB = l.lineNumberB;
            countB++;
          }
        }

        if (!hasDelete && hasAdd) {
          chunkType = DiffChunkType.INSERT;
        } else if (hasDelete && !hasAdd) {
          chunkType = DiffChunkType.DELETE;
        } else {
          chunkType = DiffChunkType.REPLACE;
        }

        chunks.push({
          chunkType,
          startA: startA,
          countA: countA,
          startB: startB,
          countB: countB,
          lines: seg
        });
      }
    }

    return chunks;
  }

  /**
   * 核心三路合并：基于 chunk 对齐
   * 规则：
   * - 双方均未修改 → UNCHANGED
   * - 仅一方修改 → 接受该方
   * - 双方修改相同 → 接受任意一方
   * - 双方修改不同 → CONFLICT
   */
  private static mergeChunks(
    baseLines: string[],
    mineLines: string[],
    theirsLines: string[],
    mineChunks: DiffChunk[],
    theirsChunks: DiffChunk[]
  ): MergeResult {
    // 简化策略：从 mineChunks 和 theirsChunks 交叉应用
    // 核心逻辑：对每个 base 行区间，跟踪 mine 和 theirs 的变更

    const result: MergeLine[] = [];
    const conflictChunks: MergeConflictChunk[] = [];

    // 构建变更映射：base行号 → { mine行号, theirs行号 }
    // 使用 Diff: Base→Mine 和 Base→Theirs 的结果直接做 3-way mapping
    const baseLinesCount = baseLines.length;

    // 构建 mine 映射: baseLineIndex → mineLineIndex (-1 = deleted)
    const mineMap: Map<number, number> = new Map();
    const mineContentMap: Map<number, string> = new Map();

    for (const chunk of mineChunks) {
      if (chunk.chunkType === DiffChunkType.EQUAL || chunk.chunkType === DiffChunkType.REPLACE) {
        // 逐行映射
        const baseStart = chunk.startA - 1;
        const targetStart = chunk.startB - 1;
        if (baseStart >= 0 && targetStart >= 0) {
          const pairCount = Math.min(chunk.countA, chunk.countB);
          for (let k = 0; k < pairCount; k++) {
            mineMap.set(baseStart + k, targetStart + k);
            if (targetStart + k < mineLines.length) {
              mineContentMap.set(baseStart + k, mineLines[targetStart + k]);
            }
          }
          // 剩余的 A 行标记为已删除
          for (let k = pairCount; k < chunk.countA; k++) {
            mineMap.set(baseStart + k, -1);
          }
        }
      } else if (chunk.chunkType === DiffChunkType.DELETE) {
        // 删除块：base 中有，mine 中无
        if (chunk.startA > 0) {
          for (let k = 0; k < chunk.countA; k++) {
            mineMap.set(chunk.startA - 1 + k, -1);
          }
        }
      } else if (chunk.chunkType === DiffChunkType.INSERT) {
        // 插入块处理：在 resolveConflicts 中通过扩展映射处理
      }
    }

    // 构建 theirs 映射
    const theirsMap: Map<number, number> = new Map();
    const theirsContentMap: Map<number, string> = new Map();

    for (const chunk of theirsChunks) {
      if (chunk.chunkType === DiffChunkType.EQUAL || chunk.chunkType === DiffChunkType.REPLACE) {
        const baseStart = chunk.startA - 1;
        const targetStart = chunk.startB - 1;
        if (baseStart >= 0 && targetStart >= 0) {
          const pairCount = Math.min(chunk.countA, chunk.countB);
          for (let k = 0; k < pairCount; k++) {
            theirsMap.set(baseStart + k, targetStart + k);
            if (targetStart + k < theirsLines.length) {
              theirsContentMap.set(baseStart + k, theirsLines[targetStart + k]);
            }
          }
          for (let k = pairCount; k < chunk.countA; k++) {
            theirsMap.set(baseStart + k, -1);
          }
        }
      } else if (chunk.chunkType === DiffChunkType.DELETE) {
        if (chunk.startA > 0) {
          for (let k = 0; k < chunk.countA; k++) {
            theirsMap.set(chunk.startA - 1 + k, -1);
          }
        }
      }
    }

    // 合并：基于 base 行逐行判断（同时处理插入块）
    let conflictCount = 0;
    let baseIdx = 0;
    while (baseIdx < baseLinesCount) {
      const mineIdx = mineMap.has(baseIdx) ? mineMap.get(baseIdx)! : baseIdx;
      const theirsIdx = theirsMap.has(baseIdx) ? theirsMap.get(baseIdx)! : baseIdx;

      const baseContent = baseLines[baseIdx];
      const mineContent = mineIdx >= 0 && mineIdx < mineLines.length
        ? mineLines[mineIdx] : '';
      const theirsContent = theirsIdx >= 0 && theirsIdx < theirsLines.length
        ? theirsLines[theirsIdx] : '';

      const mineChanged = !mineMap.has(baseIdx)
        ? baseContent !== mineContent
        : mineContent !== baseContent;
      const theirsChanged = !theirsMap.has(baseIdx)
        ? baseContent !== theirsContent
        : theirsContent !== baseContent;

      if (!mineChanged && !theirsChanged) {
        // 双方均未修改
        result.push({
          content: baseContent,
          type: MergeLineType.UNCHANGED,
          mineContent: baseContent,
          theirsContent: baseContent,
          baseContent: baseContent
        });
      } else if (mineChanged && !theirsChanged) {
        // 仅 Mine 修改
        result.push({
          content: mineContent,
          type: MergeLineType.MINE_ONLY,
          mineContent: mineContent,
          theirsContent: baseContent,
          baseContent: baseContent
        });
      } else if (!mineChanged && theirsChanged) {
        // 仅 Theirs 修改
        result.push({
          content: theirsContent,
          type: MergeLineType.THEIRS_ONLY,
          mineContent: baseContent,
          theirsContent: theirsContent,
          baseContent: baseContent
        });
      } else {
        // 双方都修改
        if (mineContent === theirsContent) {
          // 双方做了相同修改 → 无冲突
          result.push({
            content: mineContent,
            type: MergeLineType.MINE_ONLY,
            mineContent: mineContent,
            theirsContent: theirsContent,
            baseContent: baseContent
          });
        } else {
          // 冲突！
          conflictCount++;
          const chunk: MergeConflictChunk = {
            startLine: result.length,
            length: 1,
            baseContent: [baseContent],
            mineContent: [mineContent],
            theirsContent: [theirsContent],
            resolution: 'unresolved',
            editedContent: ''
          };
          conflictChunks.push(chunk);

          result.push({
            content: `<<<<<<< mine\n${mineContent}\n=======\n${theirsContent}\n>>>>>>> theirs`,
            type: MergeLineType.CONFLICT,
            mineContent: mineContent,
            theirsContent: theirsContent,
            baseContent: baseContent
          });
        }
      }

      baseIdx++;
    }

    return {
      lines: result,
      conflictChunks: conflictChunks,
      conflictCount: conflictCount,
      hasConflicts: conflictCount > 0
    };
  }

  /**
   * 应用合并动作解决冲突
   * @param chunks  冲突块列表
   * @param chunkIndex 要解决的冲突块索引
   * @param action 合并动作
   * @param editedContent 手动编辑内容（仅当 action=EDIT 时使用）
   * @returns 更新后的合并行列表
   */
  static resolveConflict(
    result: MergeResult,
    chunkIndex: number,
    action: MergeAction,
    editedContent: string = ''
  ): MergeResult {
    if (chunkIndex < 0 || chunkIndex >= result.conflictChunks.length) {
      return result;
    }

    const chunk = result.conflictChunks[chunkIndex];
    let resolvedContent: string;

    switch (action) {
      case MergeAction.ACCEPT_MINE:
        resolvedContent = chunk.mineContent.join('\n');
        break;
      case MergeAction.ACCEPT_THEIRS:
        resolvedContent = chunk.theirsContent.join('\n');
        break;
      case MergeAction.KEEP_BOTH:
        resolvedContent = `${chunk.mineContent.join('\n')}\n${chunk.theirsContent.join('\n')}`;
        break;
      case MergeAction.EDIT:
        resolvedContent = editedContent;
        break;
      default:
        resolvedContent = chunk.mineContent.join('\n');
    }

    chunk.resolution = action === MergeAction.ACCEPT_MINE ? 'mine'
      : action === MergeAction.ACCEPT_THEIRS ? 'theirs'
      : action === MergeAction.KEEP_BOTH ? 'both'
      : 'edited';
    chunk.editedContent = resolvedContent;

    // 更新结果中的对应行
    const lines = [...result.lines];
    if (chunk.startLine >= 0 && chunk.startLine < lines.length) {
      lines[chunk.startLine] = {
        content: resolvedContent,
        type: MergeLineType.MINE_ONLY,
        mineContent: chunk.mineContent.join('\n'),
        theirsContent: chunk.theirsContent.join('\n'),
        baseContent: chunk.baseContent.join('\n')
      };
    }

    return {
      lines: lines,
      conflictChunks: [...result.conflictChunks],
      conflictCount: result.conflictCount - 1,
      hasConflicts: result.conflictCount - 1 > 0
    };
  }

  /**
   * 将合并结果转换为最终文本（冲突用 mine 或 theirs 替换）
   */
  static buildMergedText(result: MergeResult, preferTheirs: boolean = false): string {
    return result.lines.map(line => {
      if (line.type === MergeLineType.CONFLICT) {
        return preferTheirs ? line.theirsContent : line.mineContent;
      }
      return line.content;
    }).join('\n');
  }
}