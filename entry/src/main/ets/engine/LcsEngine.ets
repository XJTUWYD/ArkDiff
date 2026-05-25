/**
 * AegisDiff — LCS（最长公共子序列）引擎
 * 标准动态规划实现，时间复杂度 O(m×n)，空间复杂度 O(m×n)
 * 用于中小规模文本的行级差异计算
 */
import { LcsMatchedPair, LcsResult } from '../model/DiffModels';
import { LCS_MAX_LINES } from '../utils/ThemeTokens';

export class LcsEngine {
  /**
   * 计算两个字符串数组的最长公共子序列
   * @param linesA 原始文本行数组
   * @param linesB 修改后文本行数组
   * @returns LcsResult 包含所有匹配行对
   */
  static compute(linesA: string[], linesB: string[]): LcsResult {
    const m = linesA.length;
    const n = linesB.length;

    // 空数组边界处理
    if (m === 0 || n === 0) {
      return {
        matches: [],
        lengthA: m,
        lengthB: n
      };
    }

    // 超过阈值时抛出提示（调用方应改用其他算法）
    if (m > LCS_MAX_LINES || n > LCS_MAX_LINES) {
      console.warn(`LcsEngine: input size (${m}x${n}) exceeds recommended limit ${LCS_MAX_LINES}`);
    }

    // 构建 DP 表：dp[i][j] = LCS 长度（linesA[0..i-1] vs linesB[0..j-1]）
    const dp: number[][] = Array.from({ length: m + 1 },
      () => new Array<number>(n + 1).fill(0));

    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        if (linesA[i - 1] === linesB[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = Math.max(dp[i - 1][j], dp[i][j - 1]);
        }
      }
    }

    // 回溯提取 LCS 匹配对
    const matches: LcsMatchedPair[] = [];
    let i = m;
    let j = n;

    while (i > 0 && j > 0) {
      if (linesA[i - 1] === linesB[j - 1]) {
        // 行内容相同 → 匹配
        matches.unshift({ indexA: i - 1, indexB: j - 1 });
        i--;
        j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return {
      matches,
      lengthA: m,
      lengthB: n
    };
  }
}
