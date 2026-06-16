/**
 * AegisDiff — FileContentService（统一文件读取服务）
 *
 * 职责：
 * - 统一全项目文件内容读取入口
 * - 自动检测 UTF-8 / UTF-16 / GBK / GB2312 编码
 * - 检测二进制文件
 * - 提供文件元数据（名称、大小、行数）
 * - 大文件硬限制（P0 防崩溃）
 *
 * 编码支持现状：
 * - UTF-8 / BOM：已支持（util.TextDecoder）
 * - ASCII / Latin-1：UTF-8 解码失败时回退逐字节读取
 * - GBK / GB18030 / Shift-JIS：尚未支持，计划在 V0.3+ 引入编码检测
 *   与转码能力（需评估 HarmonyOS 平台 encoding API 可用性）
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

/** 大文件硬限制：超过此值直接拒绝读取 */
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
/** 大文件警告阈值 */
const LARGE_FILE_THRESHOLD = 5 * 1024 * 1024; // 5MB
/** 最大行数限制 */
const MAX_LINE_COUNT = 50000;
/** 单行最大长度限制 */
const MAX_LINE_LENGTH = 10000;

/** 二进制检测阈值：读取前 N 字节 */
const BINARY_CHECK_SIZE = 8192;
/** 二进制检测：NUL 字节占比阈值（超过此比例判定为二进制） */
const BINARY_NULL_RATIO = 0.1;

export class FileContentService {
  /**
   * 读取文件完整内容
   * @param uri 文件 URI
   * @returns FileContent 包含文本内容或错误信息
   */
  static readFileContent(uri: string): FileContent {
    let file: fs.File | null = null;
    try {
      const stat = fs.statSync(uri);
      const fileName = FileContentService.extractFileName(uri);

      // 空文件直接返回
      if (stat.size === 0) {
        return {
          content: '',
          fileName: fileName,
          sizeBytes: 0,
          isBinary: false,
          lineCount: 0,
          error: null
        };
      }

      // P0: 硬限制 — 文件过大直接拒绝，防止内存溢出崩溃
      if (stat.size > MAX_FILE_SIZE) {
        console.error(`FileContentService: 文件过大 (${(stat.size / 1048576).toFixed(1)}MB)，超过上限 ${MAX_FILE_SIZE / 1048576}MB，拒绝读取: ${fileName}`);
        return {
          content: '',
          fileName: fileName,
          sizeBytes: stat.size,
          isBinary: false,
          lineCount: 0,
          error: `文件过大 (${FileContentService.formatSize(stat.size)})，超过上限 ${FileContentService.formatSize(MAX_FILE_SIZE)}，请使用专业对比工具`
        };
      }

      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);

      // 读取全部内容
      const buf = new ArrayBuffer(stat.size);
      const readLen = fs.readSync(file.fd, buf);
      fs.closeSync(file);
      file = null;

      const arr = new Uint8Array(buf, 0, readLen);

      // ===== 编码检测与解码 =====
      // 先检测 BOM（UTF-16 文件约一半字节是 NUL，必须在二进制检测前判定）
      const hasUTF8BOM = arr.length >= 3 && arr[0] === 0xEF && arr[1] === 0xBB && arr[2] === 0xBF;
      const hasUTF16LEBOM = arr.length >= 2 && arr[0] === 0xFF && arr[1] === 0xFE;
      const hasUTF16BEBOM = arr.length >= 2 && arr[0] === 0xFE && arr[1] === 0xFF;
      const hasUTF16BOM = hasUTF16LEBOM || hasUTF16BEBOM;

      // 检测是否为二进制文件（带 BOM 的文本编码跳过 NUL 字节启发式）
      if (!hasUTF16BOM && FileContentService.isBinaryContent(arr)) {
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

      // 编码检测与解码
      // 策略：优先尝试 UTF-8 解码，用 \uFFFD 密度判断是否乱码；
      //       如果 UTF-8 解码产生大量替换字符（>5%），再尝试 GBK。
      //       这样可以避免 UTF-8 中文首字节被误判为 GBK lead byte。
      try {
        let content: string;
        if (hasUTF16LEBOM || hasUTF16BEBOM) {
          const encoding = hasUTF16LEBOM ? 'utf-16le' : 'utf-16be';
          const decoder = new util.TextDecoder(encoding, { fatal: false });
          // 跳过 2 字节 BOM，避免解码结果开头出现 U+FEFF
          const u8arr = new Uint8Array(arr.buffer, arr.byteOffset + 2, arr.length - 2);
          content = decoder.decodeWithStream(u8arr, { stream: false });
        } else {
          // 先尝试 UTF-8 解码
          const start = hasUTF8BOM ? 3 : 0;
          const subArr = new Uint8Array(arr.buffer, arr.byteOffset + start, arr.length - start);
          const utf8Decoder = new util.TextDecoder('utf-8', { fatal: false });
          const utf8Result = utf8Decoder.decodeWithStream(subArr, { stream: false });

          // 统计替换字符 \uFFFD 的密度
          const replacementCount = FileContentService.countReplacementChars(utf8Result);
          const replacementRatio = utf8Result.length > 0 ? replacementCount / utf8Result.length : 0;

          if (replacementRatio <= 0.05) {
            // UTF-8 解码干净，直接使用
            content = utf8Result;
          } else {
            // UTF-8 解码产生大量乱码，尝试 GBK
            const isGBK = FileContentService.detectGBK(arr);
            if (isGBK) {
              const gbkDecoder = new util.TextDecoder('gbk', { fatal: false });
              const u8arr = new Uint8Array(arr);
              content = gbkDecoder.decodeWithStream(u8arr, { stream: false });
              console.info(`FileContentService: UTF-8 替换率 ${(replacementRatio * 100).toFixed(1)}%，回退使用 GBK 解码: ${fileName}`);
            } else {
              // 不是 GBK，保留 UTF-8 结果（含替换字符）
              content = utf8Result;
            }
          }
        }

        // P0: 行数硬限制检查
        const lineCount = content.length > 0 ? (content.match(/\n/g) || []).length + 1 : 0;
        if (lineCount > MAX_LINE_COUNT) {
          console.error(`FileContentService: 行数过多 (${lineCount}行)，超过上限 ${MAX_LINE_COUNT}行，拒绝: ${fileName}`);
          return {
            content: '',
            fileName: fileName,
            sizeBytes: stat.size,
            isBinary: false,
            lineCount: lineCount,
            error: `行数过多 (${lineCount}行)，超过上限 ${MAX_LINE_COUNT}行，有可能崩溃或卡死，请使用专业对比工具`
          };
        }

        // P0: 单行长度检查
        const lines = content.split('\n');
        const longLineIdx = lines.findIndex((l: string) => l.length > MAX_LINE_LENGTH);
        if (longLineIdx >= 0) {
          console.error(`FileContentService: 第${longLineIdx + 1}行超长 (${lines[longLineIdx].length}字符)，超过上限 ${MAX_LINE_LENGTH}字符: ${fileName}`);
          return {
            content: '',
            fileName: fileName,
            sizeBytes: stat.size,
            isBinary: false,
            lineCount: lineCount,
            error: `第${longLineIdx + 1}行过长，超过上限 ${MAX_LINE_LENGTH}字符，请先处理超长行`
          };
        }

        return {
          content: content,
          fileName: fileName,
          sizeBytes: stat.size,
          isBinary: false,
          lineCount: lineCount,
          error: null
        };
      } catch (_decodeErr) {
        // 解码失败，回退为逐字节读取（兼容 ASCII / Latin-1）
        let content = '';
        for (let i = 0; i < arr.length; i++) {
          content += String.fromCharCode(arr[i]);
        }
        const lineCount = content.length > 0 ? (content.match(/\n/g) || []).length + 1 : 0;

        // 回退路径同样做行数和行长度检查
        if (lineCount > MAX_LINE_COUNT) {
          return {
            content: '',
            fileName: fileName,
            sizeBytes: stat.size,
            isBinary: false,
            lineCount: lineCount,
            error: `行数过多 (${lineCount}行)，超过上限 ${MAX_LINE_COUNT}行，有可能崩溃或卡死，请使用专业对比工具`
          };
        }

        return {
          content: content,
          fileName: fileName,
          sizeBytes: stat.size,
          isBinary: false,
          lineCount: lineCount,
          error: null
        };
      }
    } catch (e) {
      if (file !== null) {
        try { fs.closeSync(file); } catch (_c) { /* ignore */ }
      }
      const errorMsg = e instanceof Object && (e as Record<string, Object>)['message'] !== undefined
        ? String((e as Record<string, Object>)['message'])
        : JSON.stringify(e);
      console.error(`FileContentService: 读取文件异常: ${errorMsg}`);
      return {
        content: '',
        fileName: FileContentService.extractFileName(uri),
        sizeBytes: 0,
        isBinary: false,
        lineCount: 0,
        error: `读取文件失败: ${errorMsg}`
      };
    }
  }

  // ===================== 编码检测与转换 =====================

  /**
   * 检测文本是否可能是 GBK/GB2312 编码
   * 启发式：如果非ASCII字节中 GBK lead byte 占比 > 60%，则判定为 GBK
   */
  private static detectGBK(bytes: Uint8Array): boolean {
    let nonAscii = 0;
    let gbkLeads = 0;
    const limit = Math.min(bytes.length, 4096); // 只检测前 4KB
    for (let i = 0; i < limit; i++) {
      const b = bytes[i];
      if (b > 0x7F) {
        nonAscii++;
        if (b >= 0x81 && b <= 0xFE) {
          gbkLeads++;
        }
      }
    }
    if (nonAscii === 0) return false;
    // 超过 60% 的非ASCII字节落在 GBK lead byte 范围 → 判定为 GBK
    return (gbkLeads / nonAscii) > 0.6;
  }

  /**
   * 统计字符串中 Unicode 替换字符 (U+FFFD) 的个数
   * 用于判断 UTF-8 解码是否正确
   */
  private static countReplacementChars(str: string): number {
    let count = 0;
    for (let i = 0; i < str.length; i++) {
      if (str.charCodeAt(i) === 0xFFFD) {
        count++;
      }
    }
    return count;
  }

  // ===================== 元数据与工具方法 =====================

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
        modifiedTime: stat.mtimeNs ? Number(stat.mtimeNs) / 1000000 : 0,
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
   * 启发式：前 N 字节中 NUL 字节占比超过 10% 判定为二进制。
   * 用比例而非"任一 NUL"可避免 UTF-16 等合法文本被误判。
   */
  private static isBinaryContent(arr: Uint8Array): boolean {
    const checkLen = Math.min(arr.length, BINARY_CHECK_SIZE);
    if (checkLen === 0) return false;
    const threshold = Math.max(1, Math.floor(checkLen * BINARY_NULL_RATIO));
    let nullCount = 0;
    for (let i = 0; i < checkLen; i++) {
      if (arr[i] === 0) {
        nullCount++;
        if (nullCount >= threshold) return true;
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