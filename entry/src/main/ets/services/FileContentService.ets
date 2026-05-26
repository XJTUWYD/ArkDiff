/**
 * AegisDiff — FileContentService（统一文件读取服务）
 *
 * 职责：
 * - 统一全项目文件内容读取入口
 * - 自动检测 UTF-8 编码
 * - 检测二进制文件
 * - 提供文件元数据（名称、大小、行数）
 * - 大文件阈值警告
 *
 * 页面禁止直接调用 fs.read / String.fromCharCode，必须通过此服务。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

/** 文件内容读取结果 */
export interface FileContent {
  /** 文本内容（二进制文件时为空字符串） */
  content: string;
  /** 文件名（从 URI 提取） */
  fileName: string;
  /** 文件大小（字节） */
  sizeBytes: number;
  /** 是否为二进制文件 */
  isBinary: boolean;
  /** 行数 */
  lineCount: number;
  /** 读取错误信息（null 表示成功） */
  error: string | null;
}

/** 文件元数据（不含内容） */
export interface FileMetadata {
  fileName: string;
  sizeBytes: number;
  isDirectory: boolean;
  /** 最后修改时间（毫秒时间戳） */
  modifiedTime: number;
  /** 简化的内容哈希（基于首尾字节），用于快速比对 */
  hash?: string;
}

/** 大文件阈值（超过此值给出警告） */
const LARGE_FILE_THRESHOLD = 5 * 1024 * 1024; // 5MB

/** 二进制检测阈值：读取前 N 字节 */
const BINARY_CHECK_SIZE = 8192;

export class FileContentService {
  /**
   * 读取文件完整内容
   * @param uri 文件 URI
   * @returns FileContent 包含文本内容或错误信息
   */
  static readFileContent(uri: string): FileContent {
    let file: fs.File | null = null;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(uri);
      const fileName = FileContentService.extractFileName(uri);

      // 空文件直接返回
      if (stat.size === 0) {
        fs.closeSync(file);
        return {
          content: '',
          fileName: fileName,
          sizeBytes: 0,
          isBinary: false,
          lineCount: 0,
          error: null
        };
      }

      // 读取全部内容
      const buf = new ArrayBuffer(stat.size);
      const readLen = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      file = null;

      const arr = new Uint8Array(buf, 0, readLen);

      // 检测是否为二进制文件
      if (FileContentService.isBinaryContent(arr)) {
        return {
          content: '',
          fileName: fileName,
          sizeBytes: stat.size,
          isBinary: true,
          lineCount: 0,
          error: '文件为二进制格式，暂不支持文本比较'
        };
      }

      // 大文件警告
      if (stat.size > LARGE_FILE_THRESHOLD) {
        console.warn(`FileContentService: 文件较大 (${(stat.size / 1048576).toFixed(1)}MB)，可能影响性能: ${fileName}`);
      }

      // UTF-8 解码
      try {
        const decoder = new util.TextDecoder('utf-8', { fatal: false });
        const u8arr = new Uint8Array(arr);
        const content = decoder.decodeWithStream(u8arr, { stream: false });
        const lines = content.length > 0 ? content.split('\n').length : 0;

        return {
          content: content,
          fileName: fileName,
          sizeBytes: stat.size,
          isBinary: false,
          lineCount: lines,
          error: null
        };
      } catch (_decodeErr) {
        // UTF-8 解码失败，回退为逐字节读取（兼容 ASCII / Latin-1）
        let content = '';
        for (let i = 0; i < arr.length; i++) {
          content += String.fromCharCode(arr[i]);
        }
        const lines = content.length > 0 ? content.split('\n').length : 0;

        return {
          content: content,
          fileName: fileName,
          sizeBytes: stat.size,
          isBinary: false,
          lineCount: lines,
          error: null
        };
      }
    } catch (e) {
      if (file !== null) {
        try { fs.closeSync(file); } catch (_c) { /* ignore */ }
      }
      return {
        content: '',
        fileName: FileContentService.extractFileName(uri),
        sizeBytes: 0,
        isBinary: false,
        lineCount: 0,
        error: `读取文件失败: ${JSON.stringify(e)}`
      };
    }
  }

  /**
   * 获取文件元数据（不读取内容）
   */
  static getFileMetadata(uri: string): FileMetadata | null {
    try {
      const stat = fs.statSync(uri);
      const fileName = FileContentService.extractFileName(uri);
      return {
        fileName: fileName,
        sizeBytes: stat.size,
        isDirectory: stat.isDirectory(),
        modifiedTime: stat.mtimeNs ? Number(stat.mtimeNs) / 1000000 : Date.now(),
        hash: undefined
      };
    } catch (_e) {
      return null;
    }
  }

  /**
   * 从 URI 提取文件名
   */
  static extractFileName(uri: string): string {
    const parts = uri.split('/');
    return parts.length > 0 ? parts[parts.length - 1] : 'unknown';
  }

  /**
   * 检测内容是否为二进制
   * 通过检查前部字节中是否包含 null 字节来判断
   */
  private static isBinaryContent(arr: Uint8Array): boolean {
    const checkLen = Math.min(arr.length, BINARY_CHECK_SIZE);
    for (let i = 0; i < checkLen; i++) {
      if (arr[i] === 0) {
        return true;
      }
    }
    return false;
  }

  /**
   * 格式化文件大小为可读字符串
   */
  static formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
  }

  /**
   * 格式化文件大小为可读字符串（别名，供 BinaryFileHandler 等外部调用）
   */
  static formatFileSize(bytes: number): string {
    return FileContentService.formatSize(bytes);
  }
}
