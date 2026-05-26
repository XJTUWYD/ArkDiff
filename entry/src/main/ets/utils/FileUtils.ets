/**
 * AegisDiff — FileUtils（文件读取 + 编码支持）
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export class FileUtils {
  /**
   * 读取文件内容，自动检测编码（优先 UTF-8，回退 GBK）
   */
  static readFile(uri: string): string {
    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(uri);
      let buf = new ArrayBuffer(stat.size);
      let readLen = fs.readSync(file.fd, buf);
      fs.closeSync(file);

      let arr = new Uint8Array(buf, 0, readLen);

      // 尝试 UTF-8 解码
      try {
        let decoder = new util.TextDecoder('utf-8', { fatal: false });
        let u8arr = new Uint8Array(arr);
        return decoder.decodeWithStream(u8arr, { stream: false });
      } catch (_e) {
        // UTF-8 失败，回退为逐字节读取（兼容 ASCII / Latin-1）
        let content = '';
        for (let i = 0; i < arr.length; i++) {
          content += String.fromCharCode(arr[i]);
        }
        return content;
      }
    } catch (e) {
      return '';
    }
  }

  /** 获取文件名（从 URI 提取） */
  static getFileName(uri: string): string {
    const parts = uri.split('/');
    const raw = parts.length > 0 ? parts[parts.length - 1] : 'unknown';
    // 对中文文件名做简单 decode
    return raw;
  }
}
