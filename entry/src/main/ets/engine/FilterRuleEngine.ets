/**
 * AegisDiff — FilterRuleEngine（过滤规则引擎）
 *
 * 支持过滤规则：
 *   1. 忽略空白差异 (ignoreWhitespace)
 *   2. 忽略大小写 (ignoreCase)
 *   3. 忽略空行 (ignoreBlankLines)
 *   4. 忽略特定文件模式 (ignorePatterns — glob style)
 *   5. 仅显示差异文件 (onlyDiff — 目录对比)
 *   6. 上下文行数控制 (contextLines)
 */

/** 过滤器配置 */
export interface FilterConfig {
  ignoreWhitespace: boolean;   // 忽略行首尾空白
  ignoreAllWhitespace: boolean; // 忽略所有空白字符
  ignoreCase: boolean;          // 忽略大小写
  ignoreBlankLines: boolean;    // 忽略空行
  ignorePatterns: string[];     // glob 模式（如 "*.log", "node_modules/**"）
  onlyShowDiff: boolean;       // 仅显示差异
  contextLines: number;         // 上下文行数（0=无限，3=前后3行）
}

/** 默认过滤配置 */
export const DEFAULT_FILTER_CONFIG: FilterConfig = {
  ignoreWhitespace: false,
  ignoreAllWhitespace: false,
  ignoreCase: false,
  ignoreBlankLines: false,
  ignorePatterns: [],
  onlyShowDiff: false,
  contextLines: 0,
};

/**
 * FilterRuleEngine
 *
 * 对文本行列表应用过滤规则，返回过滤后的行索引集合或新行列表。
 * 也支持目录级文件路径过滤。
 */
export class FilterRuleEngine {
  /**
   * 对文本行应用过滤规则，返回过滤后的行列表
   * @param lines 原始行
   * @param config 过滤配置
   * @param diffTypes 可选 — 每行的差异类型（用于 contextLines 计算）
   * @returns 过滤后的行索引映射（新索引 → 原始索引）
   */
  static filterLines(
    lines: string[],
    config: FilterConfig,
    diffTypes?: string[]
  ): number[] {
    const indices: number[] = [];

    // 第一步：计算仅差异模式下哪些行需要保留
    let diffRowSet: Set<number> | null = null;
    if (config.onlyShowDiff && diffTypes) {
      diffRowSet = new Set<number>();
      for (let i = 0; i < diffTypes.length; i++) {
        if (diffTypes[i] !== 'UNCHANGED' && diffTypes[i] !== 'EMPTY') {
          diffRowSet.add(i);
        }
      }
      // 扩展上下文
      if (config.contextLines > 0 && diffRowSet.size > 0) {
        const expanded = new Set<number>(diffRowSet);
        for (const idx of diffRowSet) {
          for (let c = 1; c <= config.contextLines; c++) {
            if (idx - c >= 0) expanded.add(idx - c);
            if (idx + c < lines.length) expanded.add(idx + c);
          }
        }
        diffRowSet = expanded;
      }
    }

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];

      // 仅差异模式
      if (diffRowSet && !diffRowSet.has(i)) continue;

      // 忽略空行
      if (config.ignoreBlankLines && line.trim() === '') continue;

      // 忽略空白
      if (config.ignoreWhitespace) line = line.trim();
      if (config.ignoreAllWhitespace) line = line.replace(/\s+/g, '');

      indices.push(i);
    }

    return indices;
  }

  /**
   * 标准化文本行（应用空白/大小写规则后用于比较）
   */
  static normalizeLine(line: string, config: FilterConfig): string {
    let result = line;
    if (config.ignoreCase) {
      result = result.toLowerCase();
    }
    if (config.ignoreAllWhitespace) {
      result = result.replace(/\s+/g, '');
    } else if (config.ignoreWhitespace) {
      result = result.trim();
    }
    return result;
  }

  /**
   * 标准化文本块
   */
  static normalizeText(text: string, config: FilterConfig): string {
    let result = text;
    if (config.ignoreCase) {
      result = result.toLowerCase();
    }
    if (config.ignoreAllWhitespace) {
      result = result.replace(/\s+/g, '');
    } else if (config.ignoreWhitespace) {
      result = result.split('\n').map(l => l.trim()).join('\n');
    }
    if (config.ignoreBlankLines) {
      result = result.split('\n').filter(l => l.trim() !== '').join('\n');
    }
    return result;
  }

  /**
   * 文件路径是否匹配 glob 模式
   * 支持简单通配符：* 匹配任意字符（不含/），** 匹配任意路径
   */
  static matchesGlob(filePath: string, pattern: string): boolean {
    // 将 glob 模式转为正则
    let regexStr = '^';
    // 转义特殊字符
    const escape = (s: string) => s.replace(/[.+^${}()|[\]\\]/g, '\\$&');
    let i = 0;
    while (i < pattern.length) {
      if (pattern[i] === '*' && i + 1 < pattern.length && pattern[i + 1] === '*') {
        // ** — 匹配任意路径（包括 /）
        regexStr += '.*';
        i += 2;
      } else if (pattern[i] === '*') {
        // * — 匹配非 / 的任意字符
        regexStr += '[^/]*';
        i += 1;
      } else if (pattern[i] === '?') {
        regexStr += '[^/]';
        i += 1;
      } else {
        regexStr += escape(pattern[i]);
        i += 1;
      }
    }
    regexStr += '$';

    try {
      const re = new RegExp(regexStr);
      return re.test(filePath);
    } catch (_e) {
      return false;
    }
  }

  /**
   * 文件路径是否应被忽略（匹配任一模式）
   */
  static shouldIgnoreFile(filePath: string, patterns: string[]): boolean {
    if (!patterns || patterns.length === 0) return false;
    for (const pattern of patterns) {
      if (this.matchesGlob(filePath, pattern)) return true;
    }
    return false;
  }

  /**
   * 检查文件是否是二进制（通过内容启发式判断）
   */
  static isBinaryContent(content: string): boolean {
    // 检查前 8000 个字符中是否有 null 字节或过多控制字符
    const sample = content.substring(0, Math.min(8000, content.length));
    let controlCount = 0;
    for (let i = 0; i < sample.length; i++) {
      const code = sample.charCodeAt(i);
      if (code === 0) return true; // null 字节
      if (code < 32 && code !== 9 && code !== 10 && code !== 13) {
        controlCount++;
      }
    }
    // 超过 10% 控制字符视为二进制
    return controlCount > sample.length * 0.1;
  }

  /**
   * 获取常用的忽略模式
   */
  static getCommonIgnorePatterns(): string[] {
    return [
      'node_modules/**',
      '.git/**',
      '*.log',
      '*.lock',
      '*.min.js',
      '*.min.css',
      'dist/**',
      'build/**',
      '.DS_Store',
      'Thumbs.db',
      '__pycache__/**',
      '*.pyc',
      '.env',
      '*.swp',
      '*.swo',
    ];
  }

  /**
   * 从字符串解析过滤规则配置（用于 UI 输入）
   */
  static parseIgnorePatterns(input: string): string[] {
    return input.split(/[,\n]/).map(s => s.trim()).filter(s => s.length > 0);
  }

  /**
   * 将过滤配置序列化（用于持久化/恢复）
   */
  static serializeConfig(config: FilterConfig): string {
    return JSON.stringify(config);
  }

  /**
   * 反序列化过滤配置
   */
  static deserializeConfig(json: string): FilterConfig {
    try {
      const parsed = JSON.parse(json);
      return { ...DEFAULT_FILTER_CONFIG, ...parsed };
    } catch (_e) {
      return { ...DEFAULT_FILTER_CONFIG };
    }
  }
}