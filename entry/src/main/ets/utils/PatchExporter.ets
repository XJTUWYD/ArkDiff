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
import pasteboard from '@ohos.pasteboard';
import { DiffChunk, ChunkType, DiffLineModel, DiffLineType } from '../model/DiffModels';

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
    linesA: DiffLineModel[],
    linesB: DiffLineModel[],
    options?: ExportOptions
  ): string {
    const opt = { ...DEFAULT_EXPORT_OPTIONS, ...options };
    const lines: string[] = [];

    // 头部
    lines.push(`--- ${opt.headerA || 'a/file'}` + (opt.includeTimestamps ? `	${new Date().toISOString()}` : ''));
    lines.push(`+++ ${opt.headerB || 'b/file'}` + (opt.includeTimestamps ? `	${new Date().toISOString()}` : ''));

    // 处理每个 chunk
    for (const chunk of chunks) {
      if (chunk.type === ChunkType.UNCHANGED) continue;

      // 计算 hunk header
      const hunkHeader = this.buildHunkHeader(chunk, linesA, linesB, opt.contextLines);
      if (hunkHeader === null) continue;

      lines.push(hunkHeader);

      // 输出上下文行和差异行
      const outputLines = this.buildHunkLines(chunk, linesA, linesB, opt.contextLines);
      for (const ol of outputLines) {
        lines.push(ol);
      }
    }

    return lines.join('\n');
  }

  /**
   * 从原始文本和差异结果生成 Unified Diff
   */
  static generateFromRawDiff(
    oldText: string,
    newText: string,
    diffLines: DiffLineModel[],
    options?: ExportOptions
  ): string {
    const opt = { ...DEFAULT_EXPORT_OPTIONS, ...options };
    const headerA = opt.headerA || 'original';
    const headerB = opt.headerB || 'modified';
    const lines: string[] = [];

    lines.push(`--- ${headerA}` + (opt.includeTimestamps ? `	${new Date().toISOString()}` : ''));
    lines.push(`+++ ${headerB}` + (opt.includeTimestamps ? `	${new Date().toISOString()}` : ''));

    // 按行类型输出
    let oldLineNum = 1;
    let newLineNum = 1;
    let hunkContext: string[] = [];
    let inHunk = false;
    let hunkOldStart = 1;
    let hunkNewStart = 1;

    for (let i = 0; i < diffLines.length; i++) {
      const dline = diffLines[i];
      let prefix = ' ';
      let oldNum = 0;
      let newNum = 0;

      switch (dline.type) {
        case DiffLineType.DELETED:
          prefix = '-';
          oldNum = oldLineNum++;
          break;
        case DiffLineType.ADDED:
          prefix = '+';
          newNum = newLineNum++;
          break;
        case DiffLineType.MODIFIED:
          // 先输出删除行再新增行
          if (inHunk) {
            hunkContext.push(`-${dline.oldContent || dline.content}`);
            hunkContext.push(`+${dline.newContent || dline.content}`);
          } else {
            // 作为单独 hunk 处理
            inHunk = true;
            hunkOldStart = oldLineNum;
            hunkNewStart = newLineNum;
            hunkContext = [
              `-${dline.oldContent || dline.content}`,
              `+${dline.newContent || dline.content}`
            ];
            oldLineNum++;
            newLineNum++;
          }
          continue;
        default:
          oldNum = oldLineNum++;
          newNum = newLineNum++;
          break;
      }

      if (inHunk && (dline.type === DiffLineType.UNCHANGED || i === diffLines.length - 1)) {
        // 输出 hunk
        lines.push(`@@ -${hunkOldStart},${hunkContext.filter(l => l.startsWith('-')).length} +${hunkNewStart},${hunkContext.filter(l => l.startsWith('+')).length} @@`);
        for (const hl of hunkContext) lines.push(hl);
        inHunk = false;
        hunkContext = [];
      }

      if (!inHunk) {
        lines.push(`${prefix}${dline.content}`);
      }
    }

    // 如果最后还有未输出的 hunk
    if (inHunk && hunkContext.length > 0) {
      lines.push(`@@ -${hunkOldStart},${hunkContext.filter(l => l.startsWith('-')).length} +${hunkNewStart},${hunkContext.filter(l => l.startsWith('+')).length} @@`);
      for (const hl of hunkContext) lines.push(hl);
    }

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
      switch (chunk.type) {
        case ChunkType.ADDED:
          added += chunk.linesB.length;
          break;
        case ChunkType.DELETED:
          deleted += chunk.linesA.length;
          break;
        case ChunkType.MODIFIED:
          modified += Math.max(chunk.linesA.length, chunk.linesB.length);
          break;
        case ChunkType.UNCHANGED:
          unchanged += chunk.linesA.length;
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
   * 导出到剪贴板
   */
  static exportToClipboard(content: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);
      pasteboard.getSystemPasteboard().setPasteData(data);
    } catch (_e) {
      // 剪贴板不可用
    }
  }

  /**
   * 将差异统计摘要导出到剪贴板
   */
  static exportStatsToClipboard(chunks: DiffChunk[]): void {
    const stats = this.generateStats(chunks);
    this.exportToClipboard(stats);
  }

  /**
   * 将 Unified Diff 导出到剪贴板
   */
  static exportUnifiedToClipboard(
    chunks: DiffChunk[],
    linesA: DiffLineModel[],
    linesB: DiffLineModel[],
    options?: ExportOptions
  ): void {
    const patch = this.generateUnifiedDiff(chunks, linesA, linesB, options);
    this.exportToClipboard(patch);
  }

  // ========= 内部方法 =========

  private static buildHunkHeader(
    chunk: DiffChunk,
    linesA: DiffLineModel[],
    linesB: DiffLineModel[],
    contextLines: number
  ): string | null {
    const startA = Math.max(0, chunk.startA - contextLines);
    const startB = Math.max(0, chunk.startB - contextLines);
    const countA = chunk.endA - chunk.startA + contextLines * 2;
    const countB = chunk.endB - chunk.startB + contextLines * 2;

    if (countA <= 0 && countB <= 0) return null;

    return `@@ -${startA + 1},${countA} +${startB + 1},${countB} @@`;
  }

  private static buildHunkLines(
    chunk: DiffChunk,
    linesA: DiffLineModel[],
    linesB: DiffLineModel[],
    contextLines: number
  ): string[] {
    const result: string[] = [];

    // 前导上下文
    for (let i = Math.max(0, chunk.startA - contextLines); i < chunk.startA; i++) {
      if (i < linesA.length) result.push(` ${linesA[i].content}`);
    }

    // 差异行
    if (chunk.type === ChunkType.DELETED) {
      for (let i = chunk.startA; i < chunk.endA; i++) {
        if (i < linesA.length) result.push(`-${linesA[i].content}`);
      }
      // 后置上下文
      for (let i = chunk.endA; i < Math.min(linesA.length, chunk.endA + contextLines); i++) {
        if (i < linesA.length) result.push(` ${linesA[i].content}`);
      }
    } else if (chunk.type === ChunkType.ADDED) {
      for (let i = chunk.startB; i < chunk.endB; i++) {
        if (i < linesB.length) result.push(`+${linesB[i].content}`);
      }
      for (let i = chunk.endB; i < Math.min(linesB.length, chunk.endB + contextLines); i++) {
        if (i < linesB.length) result.push(` ${linesB[i].content}`);
      }
    } else if (chunk.type === ChunkType.MODIFIED) {
      for (let i = chunk.startA; i < chunk.endA; i++) {
        if (i < linesA.length) result.push(`-${linesA[i].content}`);
      }
      for (let i = chunk.startB; i < chunk.endB; i++) {
        if (i < linesB.length) result.push(`+${linesB[i].content}`);
      }
      // 后置上下文
      for (let i = chunk.endA; i < Math.min(linesA.length, chunk.endA + contextLines); i++) {
        if (i < linesA.length) result.push(` ${linesA[i].content}`);
      }
    }

    return result;
  }
}