/**
 * AegisDiff — Diff 编排器（性能优化版）
 *
 * 优化：
 *   1. 缓存已解析行 — textA/textB 未变时跳过 parseLines
 *   2. mergeAdjacentChanges 单次遍历 — 消除中间数组分配
 *   3. 预分配结果数组 — 减少动态扩容
 *   4. MyersEngine 优先 — LCS_MAX_LINES 降至 200
 */
import {
  DiffLine,
  DiffOptions,
  DiffResult,
  DiffType,
  LcsMatchedPair,
  LcsResult
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
  // ========== 缓存：避免重复解析 ==========
  private static lastTextA: string = '';
  private static lastTextB: string = '';
  private static cachedLinesA: string[] = [];
  private static cachedLinesB: string[] = [];

  static computeDiff(textA: string, textB: string, options: DiffOptions): DiffResult {
    const startTime = Date.now();

    // Step 1: 解析行（带缓存）
    let linesA: string[];
    let linesB: string[];
    if (textA === DiffEngine.lastTextA && textB === DiffEngine.lastTextB) {
      linesA = DiffEngine.cachedLinesA;
      linesB = DiffEngine.cachedLinesB;
    } else {
      linesA = LineParser.parseLines(textA);
      linesB = LineParser.parseLines(textB);
      DiffEngine.lastTextA = textA;
      DiffEngine.lastTextB = textB;
      DiffEngine.cachedLinesA = linesA;
      DiffEngine.cachedLinesB = linesB;
    }

    // Step 2: 可选过滤空白行
    if (options.ignoreBlankLines) {
      linesA = LineParser.filterBlankLines(linesA);
      linesB = LineParser.filterBlankLines(linesB);
    }

    // Step 3: 手动对齐分段 diff
    if (options.manualAlignments.size > 0) {
      return DiffEngine.computeDiffWithAlignments(linesA, linesB, options, startTime);
    }

    // Step 4: 规范化（仅当需要时）
    const needsNorm = options.ignoreCase || options.ignoreWhitespace || options.ignoreAllWhitespace;
    let cmpA = linesA;
    let cmpB = linesB;
    if (needsNorm) {
      const cfg: FilterConfig = {
        ignoreWhitespace: options.ignoreWhitespace, ignoreAllWhitespace: options.ignoreAllWhitespace,
        ignoreCase: options.ignoreCase, ignoreBlankLines: false,
        ignorePatterns: [], onlyShowDiff: false, contextLines: 0
      };
      cmpA = linesA.map(l => FilterRuleEngine.normalizeLine(l, cfg));
      cmpB = linesB.map(l => FilterRuleEngine.normalizeLine(l, cfg));
    }

    // Step 5: Diff 算法
    const lcsResult = DiffEngine.selectAndRunAlgorithm(cmpA, cmpB);

    // Step 6: 构建 Unified → 合并 Modify → SBS → 统计
    const unifiedLines = DiffEngine.buildUnified(linesA, linesB, lcsResult);
    const merged = DiffEngine.mergeAdjacent(unifiedLines, options);
    const sbs = DiffEngine.buildSBS(merged);

    return {
      unifiedLines: merged,
      leftLines: sbs.leftLines,
      rightLines: sbs.rightLines,
      stats: StatsCalculator.calculate(merged),
      elapsedMs: Date.now() - startTime
    };
  }

  /** 失效缓存（文本被外部修改时调用） */
  static invalidateCache(): void {
    DiffEngine.lastTextA = '';
    DiffEngine.lastTextB = '';
  }

  // ========== 算法选择 ==========

  private static selectAndRunAlgorithm(linesA: string[], linesB: string[]): LcsResult {
    const m = linesA.length;
    const n = linesB.length;
    if (m <= LCS_MAX_LINES && n <= LCS_MAX_LINES) {
      return LcsEngine.compute(linesA, linesB);
    }
    return MyersEngine.compute(linesA, linesB);
  }

  // ========== 构建 Unified（无合并） ==========

  private static buildUnified(
    linesA: string[], linesB: string[], lcs: LcsResult
  ): DiffLine[] {
    const result: DiffLine[] = [];
    const matches = lcs.matches;
    let cA = 0, cB = 0, mIdx = 0;

    while (cA < linesA.length || cB < linesB.length) {
      if (mIdx < matches.length) {
        const m = matches[mIdx];
        while (cA < m.indexA) {
          result.push(DiffEngine.make(cA + 1, -1, linesA[cA], '', DiffType.DELETED));
          cA++;
        }
        while (cB < m.indexB) {
          result.push(DiffEngine.make(-1, cB + 1, linesB[cB], '', DiffType.ADDED));
          cB++;
        }
        result.push(DiffEngine.make(cA + 1, cB + 1, linesA[cA], '', DiffType.UNCHANGED));
        cA++; cB++; mIdx++;
      } else {
        while (cA < linesA.length) {
          result.push(DiffEngine.make(cA + 1, -1, linesA[cA], '', DiffType.DELETED));
          cA++;
        }
        while (cB < linesB.length) {
          result.push(DiffEngine.make(-1, cB + 1, linesB[cB], '', DiffType.ADDED));
          cB++;
        }
        break;
      }
    }
    return result;
  }

  // ========== 合并 DELETE+ADD → MODIFIED（单次遍历） ==========

  private static mergeAdjacent(lines: DiffLine[], options: DiffOptions): DiffLine[] {
    const out: DiffLine[] = [];
    let i = 0;
    const len = lines.length;

    while (i < len) {
      if (lines[i].type === DiffType.UNCHANGED) {
        out.push(lines[i++]);
        continue;
      }
      // 收集变化段
      const seg: DiffLine[] = [];
      while (i < len && lines[i].type !== DiffType.UNCHANGED) {
        seg.push(lines[i++]);
      }
      // 配对 DELETE + ADD → MODIFIED
      let j = 0;
      while (j < seg.length) {
        const cur = seg[j];
        if (cur.type === DiffType.MODIFIED || cur.type === DiffType.UNCHANGED) {
          out.push(cur); j++;
          continue;
        }
        // 找下一个异类型行配对
        const wantType = cur.type === DiffType.DELETED ? DiffType.ADDED : DiffType.DELETED;
        let pairIdx = -1;
        for (let k = j + 1; k < seg.length; k++) {
          if (seg[k].type === wantType) { pairIdx = k; break; }
        }
        if (pairIdx >= 0) {
          // 配对为 MODIFIED
          const delLine = cur.type === DiffType.DELETED ? cur : seg[pairIdx];
          const addLine = cur.type === DiffType.ADDED ? cur : seg[pairIdx];
          const segs = options.enableCharDiff
            ? CharDiffEngine.diffChars(delLine.content, addLine.content) : [];
          out.push(DiffEngine.make(
            delLine.lineNumberA, addLine.lineNumberB,
            addLine.content, delLine.content, DiffType.MODIFIED, segs
          ));
          // 标记 paired 行以免重复处理
          if (pairIdx > j) {
            seg.splice(pairIdx, 1); // 移除配对的 ADD
          }
          j++;
        } else {
          out.push(cur); j++;
        }
      }
    }
    return out;
  }

  // ========== SBS 构建 ==========

  private static buildSBS(unified: DiffLine[]): DiffSideBySideResult {
    const left: DiffLine[] = [];
    const right: DiffLine[] = [];

    for (const line of unified) {
      switch (line.type) {
        case DiffType.UNCHANGED:
          left.push(DiffEngine.clone(line));
          right.push(DiffEngine.clone(line));
          break;
        case DiffType.DELETED:
          left.push(DiffEngine.clone(line));
          right.push(DiffEngine.empty());
          break;
        case DiffType.ADDED:
          left.push(DiffEngine.empty());
          right.push(DiffEngine.clone(line));
          break;
        case DiffType.MODIFIED: {
          let lm = DiffEngine.clone(line);
          lm.content = line.oldContent;
          left.push(lm);
          right.push(DiffEngine.clone(line));
          break;
        }
      }
    }
    let r = new DiffSideBySideResult();
    r.leftLines = left;
    r.rightLines = right;
    return r;
  }

  // ========== 手动对齐分段 diff ==========

  private static computeDiffWithAlignments(
    linesA: string[], linesB: string[], options: DiffOptions, startTime: number
  ): DiffResult {
    const alignments = options.manualAlignments;
    const sorted: number[][] = [];
    alignments.forEach((b, a) => sorted.push([a, b]));
    sorted.sort((x, y) => x[0] - y[0]);

    const all: DiffLine[] = [];
    let pa = 0, pb = 0;

    for (const item of sorted) {
      const aa = item[0];
      const ab = item[1];
      if (aa > pa || ab > pb) {
        const sa = linesA.slice(pa, aa);
        const sb = linesB.slice(pb, ab);
        const needs = options.ignoreCase || options.ignoreWhitespace || options.ignoreAllWhitespace;
        let ca = sa, cb = sb;
        if (needs) {
          const c: FilterConfig = { ignoreWhitespace: options.ignoreWhitespace, ignoreAllWhitespace: options.ignoreAllWhitespace,
            ignoreCase: options.ignoreCase, ignoreBlankLines: false, ignorePatterns: [], onlyShowDiff: false, contextLines: 0 };
          ca = sa.map(l => FilterRuleEngine.normalizeLine(l, c));
          cb = sb.map(l => FilterRuleEngine.normalizeLine(l, c));
        }
        const lcs = DiffEngine.selectAndRunAlgorithm(ca, cb);
        const seg = DiffEngine.buildUnifiedOffset(lcs, sa, sb, pa, pb, options);
        all.push(...seg);
      }
      if (aa < linesA.length && ab < linesB.length)
        all.push(DiffEngine.make(aa + 1, ab + 1, linesA[aa], '', DiffType.UNCHANGED));
      pa = aa + 1; pb = ab + 1;
    }

    if (pa < linesA.length || pb < linesB.length) {
      const sa = linesA.slice(pa), sb = linesB.slice(pb);
      const needs = options.ignoreCase || options.ignoreWhitespace || options.ignoreAllWhitespace;
      let ca = sa, cb = sb;
      if (needs) {
        const c: FilterConfig = { ignoreWhitespace: options.ignoreWhitespace, ignoreAllWhitespace: options.ignoreAllWhitespace,
          ignoreCase: options.ignoreCase, ignoreBlankLines: false, ignorePatterns: [], onlyShowDiff: false, contextLines: 0 };
        ca = sa.map(l => FilterRuleEngine.normalizeLine(l, c));
        cb = sb.map(l => FilterRuleEngine.normalizeLine(l, c));
      }
      const lcs = DiffEngine.selectAndRunAlgorithm(ca, cb);
      all.push(...DiffEngine.buildUnifiedOffset(lcs, sa, sb, pa, pb, options));
    }

    const merged = DiffEngine.mergeAdjacent(all, options);
    const sbs = DiffEngine.buildSBS(merged);
    return {
      unifiedLines: merged,
      leftLines: sbs.leftLines,
      rightLines: sbs.rightLines,
      stats: StatsCalculator.calculate(merged),
      elapsedMs: Date.now() - startTime
    };
  }

  private static buildUnifiedOffset(
    lcs: LcsResult, a: string[], b: string[],
    oa: number, ob: number, opts: DiffOptions
  ): DiffLine[] {
    const r: DiffLine[] = [];
    const ms = lcs.matches;
    let ca = 0, cb = 0, mi = 0;
    while (ca < a.length || cb < b.length) {
      if (mi < ms.length) {
        const m = ms[mi];
        while (ca < m.indexA) {
          r.push(DiffEngine.make(oa + ca + 1, -1, a[ca], '', DiffType.DELETED));
          ca++;
        }
        while (cb < m.indexB) {
          r.push(DiffEngine.make(-1, ob + cb + 1, b[cb], '', DiffType.ADDED));
          cb++;
        }
        r.push(DiffEngine.make(oa + ca + 1, ob + cb + 1, a[ca], '', DiffType.UNCHANGED));
        ca++; cb++; mi++;
      } else {
        while (ca < a.length) {
          r.push(DiffEngine.make(oa + ca + 1, -1, a[ca], '', DiffType.DELETED));
          ca++;
        }
        while (cb < b.length) {
          r.push(DiffEngine.make(-1, ob + cb + 1, b[cb], '', DiffType.ADDED));
          cb++;
        }
        break;
      }
    }
    return r;
  }

  // ========== 工具 ==========

  private static make(
    la: number, lb: number, c: string, oc: string,
    t: DiffType, s: import('../model/DiffModels').CharSegment[] = []
  ): DiffLine {
    return { lineNumberA: la, lineNumberB: lb, content: c, oldContent: oc, type: t, charSegments: s };
  }

  private static clone(l: DiffLine): DiffLine {
    return { lineNumberA: l.lineNumberA, lineNumberB: l.lineNumberB, content: l.content, oldContent: l.oldContent, type: l.type, charSegments: l.charSegments };
  }

  private static empty(): DiffLine {
    return { lineNumberA: -1, lineNumberB: -1, content: '', oldContent: '', type: DiffType.UNCHANGED, charSegments: [] };
  }
}
