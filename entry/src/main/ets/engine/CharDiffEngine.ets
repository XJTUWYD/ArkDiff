/**
 * AegisDiff — CharDiffEngine（字符级差异引擎）
 * 对 MODIFIED 行进行字符级 LCS 计算，产出 CharSegment[] 用于行内高亮
 */
import { CharSegment, DiffType } from '../model/DiffModels';

export class CharDiffEngine {
  /**
   * 计算两个字符串的字符级差异段
   * @param oldStr 旧版本字符串
   * @param newStr 新版本字符串
   * @returns CharSegment[] 标注了每个字符范围的差异类型
   */
  static diffChars(oldStr: string, newStr: string): CharSegment[] {
    if (oldStr === newStr) {
      return [];
    }

    const m = oldStr.length;
    const n = newStr.length;
    if (m === 0 && n === 0) return [];

    // 构建 LCS DP 表（滚动数组：仅保留上一行，降低内存）
    let prev = new Array<number>(n + 1).fill(0);
    // 同时保留完整表用于回溯（回溯需要随机访问）；规模较大时回退到两行回溯
    // 这里用完整表以保证回溯正确性，行级字符 diff 的 m*n 一般较小
    const dp: number[][] = [prev.slice()];
    for (let i = 1; i <= m; i++) {
      let row = new Array<number>(n + 1).fill(0);
      for (let j = 1; j <= n; j++) {
        if (oldStr.charAt(i - 1) === newStr.charAt(j - 1)) {
          row[j] = prev[j - 1] + 1;
        } else {
          row[j] = Math.max(prev[j], row[j - 1]);
        }
      }
      dp.push(row);
      prev = row;
    }

    // 回溯提取 LCS 匹配索引（push + reverse，避免 O(n²) unshift）
    const lcsIndicesNew: number[] = []; // 匹配字符在 newStr 中的索引
    let i = m;
    let j = n;
    while (i > 0 && j > 0) {
      if (oldStr.charAt(i - 1) === newStr.charAt(j - 1)) {
        lcsIndicesNew.push(j - 1);
        i--;
        j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    lcsIndicesNew.reverse();

    // 基于 LCS + newStr 构建 CharSegment[]
    // segments 基于 newStr 的索引，标注每个字符是 UNCHANGED 还是 ADDED
    const segments: CharSegment[] = [];
    let segStart = 0;
    let segType: DiffType = DiffType.UNCHANGED;

    // newStr 中所有与 LCS 匹配的字符 → UNCHANGED，否则 → ADDED
    const lcsSet = new Set<number>(lcsIndicesNew);

    for (let pos = 0; pos < n; pos++) {
      let currentType: DiffType = lcsSet.has(pos) ? DiffType.UNCHANGED : DiffType.ADDED;
      if (pos === 0) {
        segType = currentType;
        segStart = 0;
      } else if (currentType !== segType) {
        segments.push({ start: segStart, end: pos, type: segType });
        segStart = pos;
        segType = currentType;
      }
    }
    // 最后一段
    if (n > 0) {
      segments.push({ start: segStart, end: n, type: segType });
    }

    return segments;
  }
}
