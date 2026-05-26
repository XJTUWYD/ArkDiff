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

    // 保留原始行数用于行号映射
    const originalLinesA = linesA;
    const originalLinesB = linesB;

    // Step 2: 可选过滤空白行
    if (options.ignoreBlankLines) {
      linesA = LineParser.filterBlankLines(linesA);
      linesB = LineParser.filterBlankLines(linesB);
    }

    // Step 3: 执行 Diff 算法
    const lcsResult = DiffEngine.selectAndRunAlgorithm(linesA, linesB);

    // Step 4: 由 LCS 匹配对 + 原始行构建 DiffLine[]
    const unifiedLines = DiffEngine.buildUnifiedLines(
      lcsResult, originalLinesA, originalLinesB, options
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

    // 行数较小 → LCS
    if (m <= LCS_MAX_LINES && n <= LCS_MAX_LINES) {
      return LcsEngine.compute(linesA, linesB);
    }
    // 行数较大 → Myers
    return MyersEngine.compute(linesA, linesB);
  }

  /**
   * 由 LCS 匹配结果和原始行构建 Unified 视图的 DiffLine 数组
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
   * 将相邻的删除+新增对合并为修改行
   */
  private static mergeAdjacentChanges(lines: DiffLine[], options: DiffOptions): DiffLine[] {
    const merged: DiffLine[] = [];
    let i = 0;

    while (i < lines.length) {
      // 检查当前是否为 DELETED 且下一行为 ADDED
      if (
        lines[i].type === DiffType.DELETED &&
        i + 1 < lines.length &&
        lines[i + 1].type === DiffType.ADDED
      ) {
        const oldContent = lines[i].content;
        const newContent = lines[i + 1].content;
        let charSegments = options.enableCharDiff
          ? CharDiffEngine.diffChars(oldContent, newContent)
          : [];

        merged.push(DiffEngine.makeLine(
          lines[i].lineNumberA,
          lines[i + 1].lineNumberB,
          newContent,
          oldContent,
          DiffType.MODIFIED,
          charSegments
        ));
        i += 2;
      } else {
        merged.push(lines[i]);
        i++;
      }
    }

    return merged;
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
