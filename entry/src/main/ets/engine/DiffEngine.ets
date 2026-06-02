/**
 * AegisDiff — Diff 编排器
 * 核心调度层：组合 LineParser → LCS/Myers → 结果构建 → 统计计算
 * 输出标准化的 DiffResult（包含 Unified 和 Side-by-Side 两种数据视图）
 */
import {
  DiffLine,
  DiffOptions,
  DiffResult,
  DiffType,
  LcsMatchedPair,
  LcsResult,
  DiffLine as _DiffLine
} from '../model/DiffModels';
import { LineParser } from './LineParser';
import { LcsEngine } from './LcsEngine';
import { MyersEngine } from './MyersEngine';
import { StatsCalculator } from './StatsCalculator';
import { CharDiffEngine } from './CharDiffEngine';
import { FilterRuleEngine, FilterConfig } from './FilterRuleEngine';
import { LCS_MAX_LINES } from '../utils/ThemeTokens';

class DiffSideBySideResult {
  leftLines: DiffLine[] = [];
  rightLines: DiffLine[] = [];
}

export class DiffEngine {
  /**
   * 执行完整的差异计算流程
   * @param textA 原始文本
   * @param textB 修改后文本
   * @param options 计算选项
   * @returns DiffResult 完整的差异计算结果
   */
  static computeDiff(textA: string, textB: string, options: DiffOptions): DiffResult {
    const startTime = Date.now();

    // Step 1: 解析行
    let linesA = LineParser.parseLines(textA);
    let linesB = LineParser.parseLines(textB);

    // Step 2: 可选过滤空白行
    if (options.ignoreBlankLines) {
      linesA = LineParser.filterBlankLines(linesA);
      linesB = LineParser.filterBlankLines(linesB);
    }

    // Step 2.5: 手动对齐 — 如果指定了手动对齐，分段执行 diff
    if (options.manualAlignments.size > 0) {
      return DiffEngine.computeDiffWithAlignments(linesA, linesB, options, startTime);
    }

    // Step 2.6: 构建用于比较的规范化行
    const needsNormalize = options.ignoreCase || options.ignoreWhitespace || options.ignoreAllWhitespace;
    let compareLinesA = linesA;
    let compareLinesB = linesB;
    const normConfig: FilterConfig = {
      ignoreWhitespace: options.ignoreWhitespace,
      ignoreAllWhitespace: options.ignoreAllWhitespace,
      ignoreCase: options.ignoreCase,
      ignoreBlankLines: false,
      ignorePatterns: [],
      onlyShowDiff: false,
      contextLines: 0
    };
    if (needsNormalize) {
      compareLinesA = linesA.map(l => FilterRuleEngine.normalizeLine(l, normConfig));
      compareLinesB = linesB.map(l => FilterRuleEngine.normalizeLine(l, normConfig));
    }

    // Step 3: 执行 Diff 算法
    const lcsResult = DiffEngine.selectAndRunAlgorithm(compareLinesA, compareLinesB);

    // Step 4: 构建 DiffLine[]
    const unifiedLines = DiffEngine.buildUnifiedLines(
      lcsResult, linesA, linesB, options
    );

    // Step 5: 构建 Side-by-Side 数据
    const sbsResult = DiffEngine.buildSideBySideLines(unifiedLines);
    const leftLines = sbsResult.leftLines;
    const rightLines = sbsResult.rightLines;

    // Step 6: 计算统计
    const stats = StatsCalculator.calculate(unifiedLines);

    const elapsedMs = Date.now() - startTime;

    return {
      unifiedLines,
      leftLines,
      rightLines,
      stats,
      elapsedMs
    };
  }

  /**
   * 选择合适的算法执行 LCS 计算
   */
  private static selectAndRunAlgorithm(linesA: string[], linesB: string[]): LcsResult {
    const m = linesA.length;
    const n = linesB.length;

    if (m <= LCS_MAX_LINES && n <= LCS_MAX_LINES) {
      return LcsEngine.compute(linesA, linesB);
    }
    return MyersEngine.compute(linesA, linesB);
  }

  /**
   * 支持手动对齐的分段 diff 计算
   * 将对齐点作为分割边界，在每个独立的段内执行 diff，再拼接结果
   */
  private static computeDiffWithAlignments(
    linesA: string[], linesB: string[], options: DiffOptions, startTime: number
  ): DiffResult {
    const alignments = options.manualAlignments;
    // 将对齐点按 A 侧索引排序
    const sortedAligns: number[][] = [];
    alignments.forEach((bIdx: number, aIdx: number) => {
      sortedAligns.push([aIdx, bIdx]);
    });
    sortedAligns.sort((a, b) => a[0] - b[0]);

    const allUnified: DiffLine[] = [];
    let prevEndA = 0;
    let prevEndB = 0;

    for (const pair of sortedAligns) {
      const alignA = pair[0];
      const alignB = pair[1];
      if (alignA > prevEndA || alignB > prevEndB) {
        // diff 一个段: [prevEndA, alignA) vs [prevEndB, alignB)
        const segA = linesA.slice(prevEndA, alignA);
        const segB = linesB.slice(prevEndB, alignB);
        // 规范化
        const needsNorm = options.ignoreCase || options.ignoreWhitespace || options.ignoreAllWhitespace;
        let cmpSegA = segA;
        let cmpSegB = segB;
        if (needsNorm) {
          const cfg: FilterConfig = { ignoreWhitespace: options.ignoreWhitespace, ignoreAllWhitespace: options.ignoreAllWhitespace,
            ignoreCase: options.ignoreCase, ignoreBlankLines: false, ignorePatterns: [], onlyShowDiff: false, contextLines: 0 };
          cmpSegA = segA.map(l => FilterRuleEngine.normalizeLine(l, cfg));
          cmpSegB = segB.map(l => FilterRuleEngine.normalizeLine(l, cfg));
        }
        const segLcs = DiffEngine.selectAndRunAlgorithm(cmpSegA, cmpSegB);
        const segUnified = DiffEngine.buildUnifiedLinesWithOffset(segLcs, segA, segB, prevEndA, prevEndB, options);
        allUnified.push(...segUnified);
      }
      // 添加对齐行（UNCHANGED）
      if (alignA < linesA.length && alignB < linesB.length) {
        allUnified.push(DiffEngine.makeLine(alignA + 1, alignB + 1, linesA[alignA], '', DiffType.UNCHANGED, []));
      }
      prevEndA = alignA + 1;
      prevEndB = alignB + 1;
    }

    // 最后一段: [prevEndA, end) vs [prevEndB, end)
    if (prevEndA < linesA.length || prevEndB < linesB.length) {
      const segA = linesA.slice(prevEndA);
      const segB = linesB.slice(prevEndB);
      const needsNorm = options.ignoreCase || options.ignoreWhitespace || options.ignoreAllWhitespace;
      let cmpSegA = segA;
      let cmpSegB = segB;
      if (needsNorm) {
        const cfg: FilterConfig = { ignoreWhitespace: options.ignoreWhitespace, ignoreAllWhitespace: options.ignoreAllWhitespace,
          ignoreCase: options.ignoreCase, ignoreBlankLines: false, ignorePatterns: [], onlyShowDiff: false, contextLines: 0 };
        cmpSegA = segA.map(l => FilterRuleEngine.normalizeLine(l, cfg));
        cmpSegB = segB.map(l => FilterRuleEngine.normalizeLine(l, cfg));
      }
      const segLcs = DiffEngine.selectAndRunAlgorithm(cmpSegA, cmpSegB);
      const segUnified = DiffEngine.buildUnifiedLinesWithOffset(segLcs, segA, segB, prevEndA, prevEndB, options);
      allUnified.push(...segUnified);
    }

    const sbsResult = DiffEngine.buildSideBySideLines(allUnified);
    const stats = StatsCalculator.calculate(allUnified);
    return {
      unifiedLines: allUnified,
      leftLines: sbsResult.leftLines,
      rightLines: sbsResult.rightLines,
      stats,
      elapsedMs: Date.now() - startTime
    };
  }

  /**
   * 带行号偏移的 Unified 行构建（用于手动对齐分段 diff）
   */
  private static buildUnifiedLinesWithOffset(
    lcsResult: LcsResult, linesA: string[], linesB: string[],
    offsetA: number, offsetB: number, options: DiffOptions
  ): DiffLine[] {
    const result: DiffLine[] = [];
    const matches = lcsResult.matches;
    let cursorA = 0;
    let cursorB = 0;
    let matchIdx = 0;

    while (cursorA < linesA.length || cursorB < linesB.length) {
      if (matchIdx < matches.length) {
        const match = matches[matchIdx];
        while (cursorA < linesA.length && cursorA < match.indexA) {
          result.push(DiffEngine.makeLine(offsetA + cursorA + 1, -1, linesA[cursorA], '', DiffType.DELETED, []));
          cursorA++;
        }
        while (cursorB < linesB.length && cursorB < match.indexB) {
          result.push(DiffEngine.makeLine(-1, offsetB + cursorB + 1, linesB[cursorB], '', DiffType.ADDED, []));
          cursorB++;
        }
        result.push(DiffEngine.makeLine(offsetA + cursorA + 1, offsetB + cursorB + 1, linesA[cursorA], '', DiffType.UNCHANGED, []));
        cursorA++; cursorB++; matchIdx++;
      } else {
        while (cursorA < linesA.length) {
          result.push(DiffEngine.makeLine(offsetA + cursorA + 1, -1, linesA[cursorA], '', DiffType.DELETED, []));
          cursorA++;
        }
        while (cursorB < linesB.length) {
          result.push(DiffEngine.makeLine(-1, offsetB + cursorB + 1, linesB[cursorB], '', DiffType.ADDED, []));
          cursorB++;
        }
        break;
      }
    }
    return DiffEngine.mergeAdjacentChanges(result, options);
  }

  /**
   * 由 LCS 匹配结果和行数组构建 Unified 视图的 DiffLine 数组
   * @param lcsResult LCS 匹配结果
   * @param linesA A 侧行数组（必须与 LCS 计算时使用的数组一致）
   * @param linesB B 侧行数组（必须与 LCS 计算时使用的数组一致）
   * @param options Diff 选项
   */
  private static buildUnifiedLines(
    lcsResult: LcsResult,
    linesA: string[],
    linesB: string[],
    options: DiffOptions
  ): DiffLine[] {
    const result: DiffLine[] = [];
    const matches = lcsResult.matches;

    let cursorA = 0;
    let cursorB = 0;
    let matchIdx = 0;

    while (cursorA < linesA.length || cursorB < linesB.length) {
      if (matchIdx < matches.length) {
        const match = matches[matchIdx];

        // 处理匹配对之前的差异行（A 独有的 → DELETED）
        while (cursorA < linesA.length && cursorA < match.indexA) {
          result.push(DiffEngine.makeLine(cursorA + 1, -1, linesA[cursorA], '', DiffType.DELETED, []));
          cursorA++;
        }

        // 处理匹配对之前的差异行（B 独有的 → ADDED）
        while (cursorB < linesB.length && cursorB < match.indexB) {
          result.push(DiffEngine.makeLine(-1, cursorB + 1, linesB[cursorB], '', DiffType.ADDED, []));
          cursorB++;
        }

        // 匹配行 → UNCHANGED
        result.push(DiffEngine.makeLine(cursorA + 1, cursorB + 1, linesA[cursorA], '', DiffType.UNCHANGED, []));
        cursorA++;
        cursorB++;
        matchIdx++;
      } else {
        // 剩余行处理
        while (cursorA < linesA.length) {
          result.push(DiffEngine.makeLine(cursorA + 1, -1, linesA[cursorA], '', DiffType.DELETED, []));
          cursorA++;
        }
        while (cursorB < linesB.length) {
          result.push(DiffEngine.makeLine(-1, cursorB + 1, linesB[cursorB], '', DiffType.ADDED, []));
          cursorB++;
        }
        break;
      }
    }

    // Step 4b: 后处理 — 合并相邻的 DELETE+ADD 为 MODIFIED
    return DiffEngine.mergeAdjacentChanges(result, options);
  }

  /**
   * 将连续的 DELETE 块与 ADD 块合并为 MODIFIED（块级合并）
   * 支持：1对1、1对多、多对1、多对多替换
   */
  private static mergeAdjacentChanges(lines: DiffLine[], options: DiffOptions): DiffLine[] {
    const merged: DiffLine[] = [];
    let i = 0;

    while (i < lines.length) {
      if (lines[i].type === DiffType.DELETED || lines[i].type === DiffType.ADDED) {
        // 收集连续的同类型行，形成 delete block 或 add block
        const segStart = i;
        while (i < lines.length && lines[i].type !== DiffType.UNCHANGED) {
          i++;
        }
        const segment = lines.slice(segStart, i);
        merged.push(...DiffEngine.mergeBlockSegment(segment, options));
      } else {
        merged.push(lines[i]);
        i++;
      }
    }

    return merged;
  }

  /**
   * 将一个连续的差异段（可能包含多个 DELETE 和 ADD）按块合并
   * 发现模式：DELETE group(s) followed by ADD group(s) → MODIFIED
   * 单独 DELETE → 保留 DELETED，单独 ADD → 保留 ADDED
   */
  private static mergeBlockSegment(segment: DiffLine[], options: DiffOptions): DiffLine[] {
    const result: DiffLine[] = [];

    // 将 segment 分成 delete 组和 add 组
    const deletes: number[][] = []; // start,end 对
    const adds: number[][] = [];

    let j = 0;
    while (j < segment.length) {
      const start = j;
      if (segment[j].type === DiffType.DELETED) {
        while (j < segment.length && segment[j].type === DiffType.DELETED) j++;
        deletes.push([start, j]);
      } else if (segment[j].type === DiffType.ADDED) {
        while (j < segment.length && segment[j].type === DiffType.ADDED) j++;
        adds.push([start, j]);
      } else {
        j++;
      }
    }

    // 将相邻的 delete+add 配对为 modified
    // 简单的贪心策略：deletes 和 adds 一一对应，多余的保留原类型
    let dIdx = 0;
    let aIdx = 0;
    let consumed = 0; // segment 中已处理的索引位置

    while (dIdx < deletes.length && aIdx < adds.length) {
      const dRange = deletes[dIdx];
      const aRange = adds[aIdx];

      // 将 segment 中 consumed 到 dRange[0] 之间的非 DELETE/ADD 行直接添加
      // (实际上 segment 全是 DELETE 或 ADD，不会有其他类型)
      consumed = dRange[0];

      // 配对：取 min(deletes group size, adds group size) 行做 MODIFIED
      const dSize = dRange[1] - dRange[0];
      const aSize = aRange[1] - aRange[0];
      const pairCount = Math.min(dSize, aSize);

      for (let k = 0; k < pairCount; k++) {
        const delLine = segment[dRange[0] + k];
        const addLine = segment[aRange[0] + k];
        const oldContent = delLine.content;
        const newContent = addLine.content;
        const charSegments = options.enableCharDiff
          ? CharDiffEngine.diffChars(oldContent, newContent)
          : [];

        result.push(DiffEngine.makeLine(
          delLine.lineNumberA,
          addLine.lineNumberB,
          newContent,
          oldContent,
          DiffType.MODIFIED,
          charSegments
        ));
      }

      // 剩余的删除行保留为 DELETED
      for (let k = pairCount; k < dSize; k++) {
        result.push(segment[dRange[0] + k]);
      }
      // 剩余的新增行保留为 ADDED
      for (let k = pairCount; k < aSize; k++) {
        result.push(segment[aRange[0] + k]);
      }

      consumed = Math.max(dRange[1], aRange[1]);
      dIdx++;
      aIdx++;
    }

    // 处理剩余的 delete 组
    while (dIdx < deletes.length) {
      for (let k = deletes[dIdx][0]; k < deletes[dIdx][1]; k++) {
        result.push(segment[k]);
      }
      dIdx++;
    }
    // 处理剩余的 add 组
    while (aIdx < adds.length) {
      for (let k = adds[aIdx][0]; k < adds[aIdx][1]; k++) {
        result.push(segment[k]);
      }
      aIdx++;
    }

    return result;
  }

  /**
   * 由 Unified 视图数据构建 Side-by-Side 左右列数据
   */
  private static buildSideBySideLines(unifiedLines: DiffLine[]): DiffSideBySideResult {
    const leftLines: DiffLine[] = [];
    const rightLines: DiffLine[] = [];

    for (const line of unifiedLines) {
      switch (line.type) {
        case DiffType.UNCHANGED:
          leftLines.push(DiffEngine.cloneDiffLine(line));
          rightLines.push(DiffEngine.cloneDiffLine(line));
          break;

        case DiffType.DELETED:
          leftLines.push(DiffEngine.cloneDiffLine(line));
          rightLines.push(DiffEngine.makeEmptyLine());
          break;

        case DiffType.ADDED:
          leftLines.push(DiffEngine.makeEmptyLine());
          rightLines.push(DiffEngine.cloneDiffLine(line));
          break;

        case DiffType.MODIFIED:
          let leftModified = DiffEngine.cloneDiffLine(line);
          leftModified.type = DiffType.MODIFIED;
          // 左列显示旧内容
          leftModified.content = line.oldContent;
          leftLines.push(leftModified);

          let rightModified = DiffEngine.cloneDiffLine(line);
          rightModified.type = DiffType.MODIFIED;
          rightLines.push(rightModified);
          break;
      }
    }

    let result = new DiffSideBySideResult();
    result.leftLines = leftLines;
    result.rightLines = rightLines;
    return result;
  }

  private static makeLine(
    lineA: number, lineB: number, content: string, oldContent: string,
    type: DiffType, segments: import('../model/DiffModels').CharSegment[]
  ): DiffLine {
    let line: DiffLine = {
      lineNumberA: lineA,
      lineNumberB: lineB,
      content: content,
      oldContent: oldContent,
      type: type,
      charSegments: segments
    };
    return line;
  }

  private static cloneDiffLine(line: DiffLine): DiffLine {
    let cloned: DiffLine = {
      lineNumberA: line.lineNumberA,
      lineNumberB: line.lineNumberB,
      content: line.content,
      oldContent: line.oldContent,
      type: line.type,
      charSegments: line.charSegments
    };
    return cloned;
  }

  private static makeEmptyLine(): DiffLine {
    let empty: DiffLine = {
      lineNumberA: -1,
      lineNumberB: -1,
      content: '',
      oldContent: '',
      type: DiffType.UNCHANGED,
      charSegments: []
    };
    return empty;
  }
}