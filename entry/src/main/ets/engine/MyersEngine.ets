/**
 * AegisDiff — Myers 差分引擎
 * 基于 Eugene Myers 的 O((M+N)×D) 差分算法，线性空间变体
 * 适用于大规模文本的行级差异计算
 *
 * 参考论文: "An O(ND) Difference Algorithm and Its Variations"
 */
import { LcsMatchedPair, LcsResult } from '../model/DiffModels';

export class MyersEngine {
  /**
   * 计算两个字符串数组的差异，输出 LCS 匹配对
   * @param linesA 原始文本行数组
   * @param linesB 修改后文本行数组
   * @returns LcsResult 包含所有匹配行对
   */
  static compute(linesA: string[], linesB: string[]): LcsResult {
    const m = linesA.length;
    const n = linesB.length;

    if (m === 0 || n === 0) {
      return { matches: [], lengthA: m, lengthB: n };
    }

    // 使用贪心算法查找编辑脚本，然后提取匹配对
    const edits = MyersEngine.shortestEditScript(linesA, linesB);
    const matches = MyersEngine.editsToMatches(edits, m, n);

    return {
      matches,
      lengthA: m,
      lengthB: n
    };
  }

  /**
   * Myers 最短编辑脚本
   * 返回编辑操作列表：'=' 匹配, '+' 插入, '-' 删除
   */
  private static shortestEditScript(linesA: string[], linesB: string[]): string[] {
    const m = linesA.length;
    const n = linesB.length;
    const max = m + n;

    // V 数组：V[k] 表示在对角线 k 上能到达的最远 x 坐标
    const V: number[] = new Array<number>(2 * max + 1).fill(0);
    // trace: 记录每一步的 V 数组快照，用于回溯
    const trace: number[][] = [];

    // 主循环：逐条对角线搜索
    for (let d = 0; d <= max; d++) {
      const VSnapshot = V.slice();
      trace.push(VSnapshot);

      // 对角线 k 的取值范围：[-d, -d+2, ..., d-2, d]
      for (let k = -d; k <= d; k += 2) {
        // 决定向下还是向右移动
        let x: number;
        if (k === -d || (k !== d && V[max + k - 1] < V[max + k + 1])) {
          // 向下移动（来自 k+1 对角线）
          x = V[max + k + 1];
        } else {
          // 向右移动（来自 k-1 对角线）
          x = V[max + k - 1] + 1;
        }

        let y = x - k;

        // 沿对角线贪心前进（匹配的行跳过）
        while (x < m && y < n && linesA[x] === linesB[y]) {
          x++;
          y++;
        }

        V[max + k] = x;

        // 到达终点 → 找到最短路径
        if (x >= m && y >= n) {
          return MyersEngine.backtrack(trace, m, n, d, max);
        }
      }
    }

    return [];
  }

  /**
   * 回溯 trace 数据，生成编辑操作序列
   */
  private static backtrack(trace: number[][], m: number, n: number, d: number, max: number): string[] {
    const edits: string[] = [];
    let x = m;
    let y = n;

    for (let depth = d; depth >= 0; depth--) {
      const V = trace[depth];
      const k = x - y;
      const maxK = max + k;

      // 确定前一步的 k（prevK）
      let prevK: number;
      if (k === -depth || (k !== depth && V[maxK - 1] < V[maxK + 1])) {
        prevK = k + 1;
      } else {
        prevK = k - 1;
      }

      const prevX = V[max + prevK];
      const prevY = prevX - prevK;

      // 对角线上的匹配行
      while (x > prevX && y > prevY) {
        edits.unshift('=');
        x--;
        y--;
      }

      if (depth > 0) {
        if (x === prevX) {
          // 插入行（B 中有，A 中无）
          edits.unshift('+');
        } else if (y === prevY) {
          // 删除行（A 中有，B 中无）
          edits.unshift('-');
        }
      }

      x = prevX;
      y = prevY;
    }

    return edits;
  }

  /**
   * 将编辑操作序列转换为 LCS 匹配对
   */
  private static editsToMatches(edits: string[], m: number, _n: number): LcsMatchedPair[] {
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
