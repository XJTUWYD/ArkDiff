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
import { LCS_MAX_LINES } from '../utils/ThemeTokens';

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
    const { leftLines, rightLines } = DiffEngine.buildSideBySideLines(unifiedLines);

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
   *
   * 核心逻辑：
   * 1. 将匹配对映射到原始行号
   * 2. 匹配对之间：A 独有的 → DELETED，B 独有的 → ADDED
   * 3. 相邻的 DELETE+ADD 合并为 MODIFIED（当它们来自同一"概念行"时）
   */
  private static buildUnifiedLines(
    lcsResult: LcsResult,
    linesA: string[],
    linesB: string[],
    _options: DiffOptions
  ): DiffLine[] {
    const result: DiffLine[] = [];
    const matches = lcsResult.matches;

    let cursorA = 0; // 当前在原始行数组 A 中的位置
    let cursorB = 0; // 当前在原始行数组 B 中的位置
    let matchIdx = 0; // 当前处理的匹配对索引

    while (cursorA < linesA.length || cursorB < linesB.length) {
      if (matchIdx < matches.length) {
        const match = matches[matchIdx];

        // 处理匹配对之前的差异行（A 独有的 → DELETED）
        while (cursorA < linesA.length && cursorA < match.indexA) {
          result.push({
            lineNumberA: cursorA + 1,
            lineNumberB: -1,
            content: linesA[cursorA],
            type: DiffType.DELETED,
            charSegments: []
          });
          cursorA++;
        }

        // 处理匹配对之前的差异行（B 独有的 → ADDED）
        while (cursorB < linesB.length && cursorB < match.indexB) {
          result.push({
            lineNumberA: -1,
            lineNumberB: cursorB + 1,
            content: linesB[cursorB],
            type: DiffType.ADDED,
            charSegments: []
          });
          cursorB++;
        }

        // 匹配行 → UNCHANGED
        result.push({
          lineNumberA: cursorA + 1,
          lineNumberB: cursorB + 1,
          content: linesA[cursorA],
          type: DiffType.UNCHANGED,
          charSegments: []
        });
        cursorA++;
        cursorB++;
        matchIdx++;
      } else {
        // 剩余行处理
        while (cursorA < linesA.length) {
          result.push({
            lineNumberA: cursorA + 1,
            lineNumberB: -1,
            content: linesA[cursorA],
            type: DiffType.DELETED,
            charSegments: []
          });
          cursorA++;
        }
        while (cursorB < linesB.length) {
          result.push({
            lineNumberA: -1,
            lineNumberB: cursorB + 1,
            content: linesB[cursorB],
            type: DiffType.ADDED,
            charSegments: []
          });
          cursorB++;
        }
        break;
      }
    }

    // Step 4b: 后处理 — 合并相邻的 DELETE+ADD 为 MODIFIED
    return DiffEngine.mergeAdjacentChanges(result);
  }

  /**
   * 将相邻的删除+新增对合并为修改行
   * 例如：[- "line1 old", + "line1 new"] → [~ "line1 old" / "line1 new"]
   *
   * 策略：DELETED 行和紧随其后的 ADDED 行配对为 MODIFIED
   */
  private static mergeAdjacentChanges(lines: DiffLine[]): DiffLine[] {
    const merged: DiffLine[] = [];
    let i = 0;

    while (i < lines.length) {
      // 检查当前是否为 DELETED 且下一行为 ADDED
      if (
        lines[i].type === DiffType.DELETED &&
        i + 1 < lines.length &&
        lines[i + 1].type === DiffType.ADDED
      ) {
        // 合并为 MODIFIED：取删除行的行号和新增行的行号
        merged.push({
          lineNumberA: lines[i].lineNumberA,
          lineNumberB: lines[i + 1].lineNumberB,
          content: lines[i + 1].content, // 展示新版本内容
          type: DiffType.MODIFIED,
          charSegments: []
        });
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
   * 确保左右列行数一致（缺失行用空行占位）
   */
  private static buildSideBySideLines(unifiedLines: DiffLine[]): {
    leftLines: DiffLine[];
    rightLines: DiffLine[];
  } {
    const leftLines: DiffLine[] = [];
    const rightLines: DiffLine[] = [];

    // 创建空占位行
    const emptyLine = (): DiffLine => ({
      lineNumberA: -1,
      lineNumberB: -1,
      content: '',
      type: DiffType.UNCHANGED,
      charSegments: []
    });

    for (const line of unifiedLines) {
      switch (line.type) {
        case DiffType.UNCHANGED:
          // 两边都显示
          leftLines.push({ ...line });
          rightLines.push({ ...line });
          break;

        case DiffType.DELETED:
          // 仅左列显示
          leftLines.push({ ...line });
          rightLines.push(emptyLine());
          break;

        case DiffType.ADDED:
          // 仅右列显示
          leftLines.push(emptyLine());
          rightLines.push({ ...line });
          break;

        case DiffType.MODIFIED:
          // 左列显示旧值样式，右列显示新值样式
          leftLines.push({
            ...line,
            type: DiffType.MODIFIED
          });
          rightLines.push({
            ...line,
            type: DiffType.MODIFIED
          });
          break;
      }
    }

    return { leftLines, rightLines };
  }
}
