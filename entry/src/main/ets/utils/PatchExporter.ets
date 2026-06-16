/**
 * AegisDiff — PatchExporter（Unified Diff / Patch 导出）
 *
 * 支持导出格式：
 *   1. Unified Diff 格式（标准 patch）
 *   2. 纯差异统计摘要
 *   3. 合并结果文本
 *
 * 导出目标：
 *   - 剪贴板
 *   - 文件（通过 FileContentService）
 */
import { pasteboard } from '@kit.BasicServicesKit';
import {
  DiffChunk,
  DiffChunkType,
  DiffLine,
  DiffType
} from '../model/DiffModels';

/** 导出选项 */
export interface ExportOptions {
  format: 'unified' | 'stats' | 'plain'; // 导出格式
  headerA?: string;   // 文件A名称
  headerB?: string;   // 文件B名称
  includeTimestamps: boolean;
  contextLines: number; // unified diff 上下文行数，默认 3
}

const DEFAULT_EXPORT_OPTIONS: ExportOptions = {
  format: 'unified',
  includeTimestamps: true,
  contextLines: 3,
};

/**
 * PatchExporter — 统一 patch / diff 导出工具
 */
export class PatchExporter {
  /**
   * 从 DiffChunk 列表生成 Unified Diff 文本
   */
  static generateUnifiedDiff(
    chunks: DiffChunk[],
    linesA: DiffLine[],
    linesB: DiffLine[],
    options?: ExportOptions
  ): string {
    const opt = { ...DEFAULT_EXPORT_OPTIONS, ...options };
    const lines: string[] = [];

    // 头部
    lines.push(`--- ${opt.headerA || 'a/file'}` + (opt.includeTimestamps ? `	${new Date().toISOString()}` : ''));
    lines.push(`+++ ${opt.headerB || 'b/file'}` + (opt.includeTimestamps ? `	${new Date().toISOString()}` : ''));

    // 处理每个 chunk
    for (const chunk of chunks) {
      if (chunk.chunkType === DiffChunkType.EQUAL) continue;

      const hunk = this.buildHunk(chunk, linesA, linesB, opt.contextLines);
      if (hunk === null) continue;

      lines.push(hunk.header);
      for (const ol of hunk.body) {
        lines.push(ol);
      }
    }

    return lines.join('\n');
  }

  /**
   * 从原始文本和差异结果生成 Unified Diff
   * 将连续的非未变更行（含前后 context）归并为 hunk，确保 header 计数与 body 一致。
   */
  static generateFromRawDiff(
    oldText: string,
    newText: string,
    diffLines: DiffLine[],
    options?: ExportOptions
  ): string {
    const opt = { ...DEFAULT_EXPORT_OPTIONS, ...options };
    const headerA = opt.headerA || 'original';
    const headerB = opt.headerB || 'modified';
    const lines: string[] = [];

    lines.push(`--- ${headerA}` + (opt.includeTimestamps ? `\t${new Date().toISOString()}` : ''));
    lines.push(`+++ ${headerB}` + (opt.includeTimestamps ? `\t${new Date().toISOString()}` : ''));

    const context = opt.contextLines;
    // 先找出所有变化行的索引
    const changeIdx: number[] = [];
    for (let i = 0; i < diffLines.length; i++) {
      if (diffLines[i].type !== DiffType.UNCHANGED) changeIdx.push(i);
    }
    if (changeIdx.length === 0) return lines.join('\n');

    // 把连续变化（间隔 <= 2*context）合并为一个 hunk
    let hunkStartIdx = changeIdx[0];
    let hunkEndIdx = changeIdx[0];
    const flushHunk = (startIdx: number, endIdx: number) => {
      const leadStart = Math.max(0, startIdx - context);
      const trailEnd = Math.min(diffLines.length - 1, endIdx + context);
      const body: string[] = [];
      let oldCount = 0, newCount = 0;
      let oldStart = -1, newStart = -1;
      for (let i = leadStart; i <= trailEnd; i++) {
        const dl = diffLines[i];
        let prefix = ' ';
        if (dl.type === DiffType.ADDED) { prefix = '+'; if (newStart < 0) newStart = dl.lineNumberB; }
        else if (dl.type === DiffType.DELETED) { prefix = '-'; if (oldStart < 0) oldStart = dl.lineNumberA; }
        else if (dl.type === DiffType.MODIFIED) {
          // MODIFIED 拆成一对 -/+
          body.push(`-${dl.oldContent || dl.content}`); oldCount++;
          body.push(`+${dl.content}`); newCount++;
          if (oldStart < 0) oldStart = dl.lineNumberA;
          if (newStart < 0) newStart = dl.lineNumberB;
          continue;
        } else {
          if (oldStart < 0) oldStart = dl.lineNumberA;
          if (newStart < 0) newStart = dl.lineNumberB;
        }
        body.push(`${prefix}${dl.content}`);
        if (prefix === ' ' || prefix === '-') oldCount++;
        if (prefix === ' ' || prefix === '+') newCount++;
      }
      if (oldStart < 0) oldStart = 1;
      if (newStart < 0) newStart = 1;
      lines.push(`@@ -${oldStart},${oldCount} +${newStart},${newCount} @@`);
      for (const b of body) lines.push(b);
    };

    for (let k = 1; k < changeIdx.length; k++) {
      if (changeIdx[k] - hunkEndIdx <= 2 * context) {
        hunkEndIdx = changeIdx[k];
      } else {
        flushHunk(hunkStartIdx, hunkEndIdx);
        hunkStartIdx = changeIdx[k];
        hunkEndIdx = changeIdx[k];
      }
    }
    flushHunk(hunkStartIdx, hunkEndIdx);

    return lines.join('\n');
  }

  /**
   * 生成统计摘要
   */
  static generateStats(chunks: DiffChunk[]): string {
    let added = 0;
    let deleted = 0;
    let modified = 0;
    let unchanged = 0;

    for (const chunk of chunks) {
      switch (chunk.chunkType) {
        case DiffChunkType.INSERT:
          added += chunk.countB;
          break;
        case DiffChunkType.DELETE:
          deleted += chunk.countA;
          break;
        case DiffChunkType.REPLACE:
          modified += Math.max(chunk.countA, chunk.countB);
          break;
        case DiffChunkType.EQUAL:
          unchanged += chunk.countA;
          break;
      }
    }

    return `Diff Statistics
================
+ Added:    ${added} lines
- Deleted:  ${deleted} lines
~ Modified: ${modified} lines
= Same:     ${unchanged} lines
----------------
Total:      ${added + deleted + modified + unchanged} lines`;
  }

  /**
   * 导出到剪贴板（返回是否成功，避免静默失败）
   */
  static exportToClipboard(content: string): boolean {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      pasteboard.getSystemPasteboard().setData(data);
      return true;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('PatchExporter: 剪贴板不可用:', msg);
      return false;
    }
  }

  /**
   * 将差异统计摘要导出到剪贴板
   */
  static exportStatsToClipboard(chunks: DiffChunk[]): boolean {
    const stats = this.generateStats(chunks);
    return this.exportToClipboard(stats);
  }

  /**
   * 将 Unified Diff 导出到剪贴板
   */
  static exportUnifiedToClipboard(
    chunks: DiffChunk[],
    linesA: DiffLine[],
    linesB: DiffLine[],
    options?: ExportOptions
  ): boolean {
    const patch = this.generateUnifiedDiff(chunks, linesA, linesB, options);
    return this.exportToClipboard(patch);
  }

  // ========= 内部方法 =========

  /**
   * 构建单个 hunk：生成 body 行，并从 body 反推 header 计数，
   * 保证 @@ -a,b +c,d @@ 与实际输出行严格一致（context 行对 A/B 对称计入）。
   */
  private static buildHunk(
    chunk: DiffChunk,
    linesA: DiffLine[],
    linesB: DiffLine[],
    contextLines: number
  ): { header: string; body: string[] } | null {
    const body: string[] = [];
    let oldCount = 0;
    let newCount = 0;

    // 前导上下文（公共未变更行，A/B 共享）
    const leadStart = Math.max(0, chunk.startA - contextLines);
    for (let i = leadStart; i < chunk.startA && i < linesA.length; i++) {
      body.push(` ${linesA[i].content}`);
      oldCount++; newCount++;
    }

    // 差异行
    if (chunk.chunkType === DiffChunkType.DELETE) {
      for (let i = chunk.startA; i < chunk.startA + chunk.countA && i < linesA.length; i++) {
        body.push(`-${linesA[i].content}`);
        oldCount++;
      }
    } else if (chunk.chunkType === DiffChunkType.INSERT) {
      for (let i = chunk.startB; i < chunk.startB + chunk.countB && i < linesB.length; i++) {
        body.push(`+${linesB[i].content}`);
        newCount++;
      }
    } else if (chunk.chunkType === DiffChunkType.REPLACE) {
      for (let i = chunk.startA; i < chunk.startA + chunk.countA && i < linesA.length; i++) {
        body.push(`-${linesA[i].content}`);
        oldCount++;
      }
      for (let i = chunk.startB; i < chunk.startB + chunk.countB && i < linesB.length; i++) {
        body.push(`+${linesB[i].content}`);
        newCount++;
      }
    }

    // 后置上下文（公共未变更行，A/B 共享）
    const trailStartA = chunk.startA + chunk.countA;
    const trailEnd = Math.min(linesA.length, trailStartA + contextLines);
    for (let i = trailStartA; i < trailEnd; i++) {
      body.push(` ${linesA[i].content}`);
      oldCount++; newCount++;
    }

    if (oldCount === 0 && newCount === 0) return null;

    const oldStart = Math.max(1, leadStart + 1);
    const newStart = Math.max(1, Math.max(0, chunk.startB - contextLines) + 1);
    return { header: `@@ -${oldStart},${oldCount} +${newStart},${newCount} @@`, body };
  }
}