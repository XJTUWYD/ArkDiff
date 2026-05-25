/**
 * AegisDiff — 行解析器
 * 将原始文本按换行符拆分为行数组，兼容 CRLF 和 LF
 */

export class LineParser {
  /**
   * 将文本按行拆分
   * @param text 原始文本（支持 \n 和 \r\n 换行）
   * @returns 行数组（包含空行，不包含换行符本身）
   */
  static parseLines(text: string): string[] {
    if (text.length === 0) {
      return [''];
    }

    // 统一换行符：先将 \r\n 替换为 \n
    const normalized = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');

    // 按 \n 拆分
    const lines = normalized.split('\n');

    // 如果文本以 \n 结尾，split 会产生一个空字符串尾部元素，保留它表示尾随换行
    return lines;
  }

  /**
   * 过滤空白行
   * @param lines 行数组
   * @returns 过滤掉仅包含空白字符的行（trim 后长度为 0）
   */
  static filterBlankLines(lines: string[]): string[] {
    return lines.filter(line => line.trim().length > 0);
  }
}
