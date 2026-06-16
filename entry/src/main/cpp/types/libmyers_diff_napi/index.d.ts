/**
 * NAPI 模块类型声明 — libmyers_diff_napi.so
 *
 * C++ Myers 差分引擎桥接层，提供比 ArkTS 版本快 10-50x 的行级 diff。
 */

/** LCS 匹配对 */
export interface NativeMatch {
  indexA: number;
  indexB: number;
}

/** computeDiff 返回结果 */
export interface NativeDiffResult {
  matches: NativeMatch[];
  lengthA: number;
  lengthB: number;
}

/**
 * 执行 Myers 行级差异计算
 * @param linesA 原始文本行数组
 * @param linesB 修改后文本行数组
 * @returns LCS 匹配结果，包含所有匹配行对
 */
export const computeDiff: (linesA: string[], linesB: string[]) => NativeDiffResult;

/** 默认导出（消费方使用 default import） */
declare const nativeMyers: { computeDiff: typeof computeDiff };
export default nativeMyers;
