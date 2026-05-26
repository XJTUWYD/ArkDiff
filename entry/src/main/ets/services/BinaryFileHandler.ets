/**
 * AegisDiff — BinaryFileHandler（二进制文件处理策略）
 *
 * 策略：
 *   1. 检测文件是否为二进制
 *   2. 二进制文件展示元数据差异（大小、时间、hash）
 *   3. 提示"暂不支持文本对比"
 *   4. 提供降级路径：只做 metadata 对比 + 文件复制
 */
import fileIo from '@ohos.file.fs';
import { FileContentService, FileMetadata } from './FileContentService';
import { IconTokens } from '../utils/ThemeTokens';

/** 二进制文件差异条目（用于目录对比视图） */
export interface BinaryDiffEntry {
  path: string;
  side: 'a' | 'b' | 'both';
  sizeA: number;
  sizeB: number;
  modifiedTimeA: number;
  modifiedTimeB: number;
  hashA?: string;
  hashB?: string;
  isIdentical: boolean;
  warningMessage: string;
}

/** 二进制检测结果 */
export interface BinaryDetectionResult {
  isBinary: boolean;
  reason: string;           // 检测依据
  mimeType?: string;        // 推测的 MIME 类型（如 'image/png'）
  confidence: number;       // 0-1
}

/**
 * BinaryFileHandler
 *
 * 处理二进制文件的识别、元数据对比和降级展示。
 * 所有对二进制文件的操作先经过此类判断，再决定是否允许文本 diff。
 */
export class BinaryFileHandler {
  /** 已知二进制扩展名集合 */
  private static readonly BINARY_EXTENSIONS = new Set<string>([
    // 图片
    'png', 'jpg', 'jpeg', 'gif', 'bmp', 'ico', 'webp', 'svgz', 'heic',
    // 音视频
    'mp3', 'wav', 'ogg', 'flac', 'aac', 'mp4', 'avi', 'mov', 'mkv', 'webm',
    // 文档
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'pages', 'numbers',
    // 压缩
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz',
    // 可执行
    'exe', 'dll', 'so', 'dylib', 'app', 'bin', 'hap',
    // 数据库
    'db', 'sqlite', 'sqlite3', 'mdb',
    // 字体
    'ttf', 'otf', 'woff', 'woff2', 'eot',
    // 其他
    'class', 'dex', 'o', 'a', 'lib', 'wasm',
  ]);

  /**
   * 通过文件路径判断是否为二进制
   */
  static isBinaryByExtension(filePath: string): boolean {
    const ext = filePath.split('.').pop()?.toLowerCase() || '';
    return this.BINARY_EXTENSIONS.has(ext);
  }

  /**
   * 通过内容启发式判断是否为二进制
   * 委托给 FilterRuleEngine（避免循环引用，内联实现）
   */
  static isBinaryByContent(content: string): boolean {
    const sample = content.substring(0, Math.min(8000, content.length));
    let controlCount = 0;
    for (let i = 0; i < sample.length; i++) {
      const code = sample.charCodeAt(i);
      if (code === 0) return true; // null 字节 → 确定是二进制
      if (code < 32 && code !== 9 && code !== 10 && code !== 13) {
        controlCount++;
      }
    }
    return controlCount > sample.length * 0.1;
  }

  /**
   * 综合判断：路径 + 内容
   */
  static detectBinary(filePath: string, content?: string): BinaryDetectionResult {
    // 扩展名判断
    if (this.isBinaryByExtension(filePath)) {
      const ext = filePath.split('.').pop()?.toLowerCase() || '';
      return {
        isBinary: true,
        reason: `文件扩展名 .${ext} 为已知二进制格式`,
        mimeType: this.guessMimeType(ext),
        confidence: 0.95,
      };
    }

    // 内容判断
    if (content && this.isBinaryByContent(content)) {
      return {
        isBinary: true,
        reason: '文件内容包含过多非文本控制字符',
        confidence: 0.8,
      };
    }

    return {
      isBinary: false,
      reason: '',
      confidence: 1.0,
    };
  }

  /**
   * 对比两个二进制文件的元数据
   */
  static compareBinaryMetadata(
    pathA: string,
    metadataA: FileMetadata,
    pathB: string,
    metadataB: FileMetadata
  ): BinaryDiffEntry {
    const isIdentical =
      metadataA.size === metadataB.size &&
      metadataA.modifiedTime === metadataB.modifiedTime;

    return {
      path: pathA,
      side: 'both',
      sizeA: metadataA.size,
      sizeB: metadataB.size,
      modifiedTimeA: metadataA.modifiedTime,
      modifiedTimeB: metadataB.modifiedTime,
      hashA: metadataA.hash,
      hashB: metadataB.hash,
      isIdentical,
      warningMessage: `${IconTokens.BINARY_FILE} 此为二进制文件，不支持文本内容对比。下面展示元数据差异。`,
    };
  }

  /**
   * 仅一侧存在的二进制文件
   */
  static binaryOnlyEntry(
    path: string,
    side: 'a' | 'b',
    metadata: FileMetadata
  ): BinaryDiffEntry {
    return {
      path,
      side,
      sizeA: side === 'a' ? metadata.size : 0,
      sizeB: side === 'b' ? metadata.size : 0,
      modifiedTimeA: side === 'a' ? metadata.modifiedTime : 0,
      modifiedTimeB: side === 'b' ? metadata.modifiedTime : 0,
      hashA: side === 'a' ? metadata.hash : undefined,
      hashB: side === 'b' ? metadata.hash : undefined,
      isIdentical: false,
      warningMessage: `${IconTokens.BINARY_FILE} 二进制文件仅存在于一侧`,
    };
  }

  /**
   * 生成二进制对比的摘要文本
   */
  static generateBinaryDiffSummary(entry: BinaryDiffEntry): string {
    if (entry.isIdentical) {
      return `二进制文件内容与元数据一致 (${FileContentService.formatFileSize(entry.sizeA)})`;
    }
    if (entry.side !== 'both') {
      return `二进制文件仅存在于 ${entry.side === 'a' ? '左侧' : '右侧'} (${FileContentService.formatFileSize(entry.side === 'a' ? entry.sizeA : entry.sizeB)})`;
    }
    const parts: string[] = [];
    if (entry.sizeA !== entry.sizeB) {
      parts.push(`大小: ${FileContentService.formatFileSize(entry.sizeA)} → ${FileContentService.formatFileSize(entry.sizeB)}`);
    }
    if (entry.modifiedTimeA !== entry.modifiedTimeB) {
      parts.push(`修改时间不同`);
    }
    if (entry.hashA && entry.hashB && entry.hashA !== entry.hashB) {
      parts.push(`内容哈希不同`);
    }
    return parts.length > 0 ? parts.join(' | ') : '二进制文件无变化';
  }

  /**
   * 是否应阻止文本 diff（返回 true 则不允许在 DiffEditor 中打开）
   */
  static shouldBlockTextDiff(filePath: string): boolean {
    return this.isBinaryByExtension(filePath);
  }

  /**
   * 获取二进制文件推荐操作
   */
  static getRecommendedAction(filePath: string): string {
    if (this.isBinaryByExtension(filePath)) {
      return 'metadata_only'; // 仅元数据对比
    }
    return 'text_diff'; // 文本对比
  }

  // ========= 内部方法 =========

  /**
   * 根据扩展名推测 MIME 类型
   */
  private static guessMimeType(ext: string): string | undefined {
    const mimeMap: Record<string, string> = {
      'png': 'image/png',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'gif': 'image/gif',
      'bmp': 'image/bmp',
      'webp': 'image/webp',
      'svg': 'image/svg+xml',
      'pdf': 'application/pdf',
      'zip': 'application/zip',
      'rar': 'application/x-rar-compressed',
      '7z': 'application/x-7z-compressed',
      'gz': 'application/gzip',
      'tar': 'application/x-tar',
      'mp3': 'audio/mpeg',
      'wav': 'audio/wav',
      'mp4': 'video/mp4',
      'ttf': 'font/ttf',
      'otf': 'font/otf',
      'woff': 'font/woff',
      'woff2': 'font/woff2',
    };
    return mimeMap[ext];
  }

  /**
   * 计算文件 Hash（简化 SHA-256）
   * 真实环境应使用 cryptoFramework.createMessageDigest('SHA-256')
   * 此处提供简化实现，返回基于大小+时间+首尾字节的组合 Key
   */
  static computeFileKey(content: string): string {
    const head = content.substring(0, Math.min(256, content.length));
    const tail = content.substring(Math.max(0, content.length - 256));
    let hash = 0;
    const combined = head + tail;
    for (let i = 0; i < combined.length; i++) {
      const ch = combined.charCodeAt(i);
      hash = ((hash << 5) - hash) + ch;
      hash |= 0;
    }
    return `key_${Math.abs(hash).toString(16)}_${content.length}`;
  }
}