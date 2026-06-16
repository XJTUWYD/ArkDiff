/**
 * AegisDiff — Myers 差分引擎
 * 基于 Eugene Myers 的 O((M+N)×D) 差分算法，线性空间变体
 * 优先使用 C++ 原生实现 (10-50x 加速)，不可用时回退到 ArkTS 版本
 *
 * 参考论文: "An O(ND) Difference Algorithm and Its Variations"
 */
import { LcsMatchedPair, LcsResult } from '../model/DiffModels';
import nativeMyers, { NativeDiffResult } from 'libmyers_diff_napi.so';

/** 是否成功加载原生模块 */
let nativeAvailable: boolean = false;
let nativeWarned: boolean = false;
try {
  if (nativeMyers !== undefined && nativeMyers.computeDiff !== undefined) {
    nativeAvailable = true;
    console.info('[MyersEngine] C++ 原生 diff 引擎已加载，性能加速 10-50x');
  }
} catch (_e) {
  // 原生库不可用，回退到 ArkTS 版本
}

function warnNativeUnavailable(): void {
  if (!nativeWarned) {
    nativeWarned = true;
    console.warn('[MyersEngine] ⚠ C++ 原生 diff 引擎未加载，使用 ArkTS 回退实现。大文本对比将非常慢。请检查 native 编译是否成功（build-profile.json5 → externalNativeOptions）。');
  }
}

export class MyersEngine {
  /**
   * 计算两个字符串数组的差异，输出 LCS 匹配对
   */
  static compute(linesA: string[], linesB: string[]): LcsResult {
    const m = linesA.length;
    const n = linesB.length;

    if (m === 0 || n === 0) {
      return { matches: [], lengthA: m, lengthB: n };
    }

    // 优先使用 C++ 原生实现
    if (nativeAvailable) {
      return MyersEngine.computeNative(linesA, linesB, m, n);
    }

    warnNativeUnavailable();
    // 回退到 ArkTS 实现
    return MyersEngine.computeArkTS(linesA, linesB, m, n);
  }

  // ================== C++ 原生调用 ==================

  private static computeNative(
    linesA: string[], linesB: string[], m: number, n: number
  ): LcsResult {
    try {
      const t0 = Date.now();
      const result: NativeDiffResult = nativeMyers.computeDiff(linesA, linesB) as NativeDiffResult;
      // 校验原生返回结构，避免桥接层异常导致后续 undefined 访问
      if (!result || !Array.isArray(result.matches)) {
        return MyersEngine.computeArkTS(linesA, linesB, m, n);
      }
      const matches: LcsMatchedPair[] = [];
      const arr = result.matches;
      for (let i = 0; i < arr.length; i++) {
        matches.push({ indexA: arr[i].indexA, indexB: arr[i].indexB });
      }
      // 仅在大规模或慢计算时记录，避免目录批量对比刷屏日志
      const elapsed = Date.now() - t0;
      if (elapsed > 50 || m * n > 100000) {
        console.info(`[MyersEngine] C++ Native: ${m}x${n} 行, 耗时 ${elapsed}ms`);
      }
      return { matches, lengthA: m, lengthB: n };
    } catch (_e) {
      // 异常时回退
      return MyersEngine.computeArkTS(linesA, linesB, m, n);
    }
  }

  // ================== ArkTS 实现 ==================

  private static computeArkTS(
    linesA: string[], linesB: string[], m: number, n: number
  ): LcsResult {
    const edits = MyersEngine.shortestEditScript(linesA, linesB, m, n);
    const matches = MyersEngine.editsToMatches(edits);
    return { matches, lengthA: m, lengthB: n };
  }

  private static shortestEditScript(
    linesA: string[], linesB: string[], m: number, n: number
  ): string[] {
    const max = m + n;
    const V: number[] = new Array<number>(2 * max + 1).fill(0);
    const trace: number[][] = [];

    for (let d = 0; d <= max; d++) {
      const VSnapshot = V.slice();
      trace.push(VSnapshot);

      for (let k = -d; k <= d; k += 2) {
        let x: number;
        if (k === -d || (k !== d && V[max + k - 1] < V[max + k + 1])) {
          x = V[max + k + 1];
        } else {
          x = V[max + k - 1] + 1;
        }

        let y = x - k;
        while (x < m && y < n && linesA[x] === linesB[y]) {
          x++;
          y++;
        }

        V[max + k] = x;
        if (x >= m && y >= n) {
          return MyersEngine.backtrack(trace, m, n, d, max);
        }
      }
    }

    return [];
  }

  private static backtrack(
    trace: number[][], m: number, n: number, d: number, max: number
  ): string[] {
    const edits: string[] = [];
    let x = m;
    let y = n;

    for (let depth = d; depth >= 0; depth--) {
      const V = trace[depth];
      const k = x - y;
      const maxK = max + k;

      let prevK: number;
      if (k === -depth || (k !== depth && V[maxK - 1] < V[maxK + 1])) {
        prevK = k + 1;
      } else {
        prevK = k - 1;
      }

      const prevX = V[max + prevK];
      const prevY = prevX - prevK;

      while (x > prevX && y > prevY) {
        edits.push('=');
        x--;
        y--;
      }

      if (depth > 0) {
        if (x === prevX) {
          edits.push('+');
        } else {
          edits.push('-');
        }
      }

      x = prevX;
      y = prevY;
    }

    // 用 in-place reverse 替代额外数组分配
    edits.reverse();
    return edits;
  }

  private static editsToMatches(edits: string[]): LcsMatchedPair[] {
    const matches: LcsMatchedPair[] = [];
    let indexA = 0;
    let indexB = 0;

    for (let i = 0; i < edits.length; i++) {
      switch (edits[i]) {
        case '=':
          matches.push({ indexA, indexB });
          indexA++;
          indexB++;
          break;
        case '-':
          indexA++;
          break;
        case '+':
          indexB++;
          break;
      }
    }

    return matches;
  }
}
