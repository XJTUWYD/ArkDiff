/**
 * AegisDiff — TokenHighlighter（语法高亮引擎）
 * 根据文件扩展名进行关键词着色，返回 Token 数组
 */

export enum TokenType {
  KEYWORD = 0,
  STRING = 1,
  COMMENT = 2,
  NUMBER = 3,
  OPERATOR = 4,
  IDENTIFIER = 5,
  PLAIN = 6,
}

export interface Token {
  start: number;
  end: number;
  type: TokenType;
}

const ARKTS_KEYWORDS = new Set([
  'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
  'default', 'delete', 'do', 'else', 'enum', 'export', 'extends',
  'false', 'finally', 'for', 'function', 'if', 'import', 'in',
  'instanceof', 'new', 'null', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'typeof', 'var', 'void', 'while', 'with',
  'as', 'from', 'of', 'get', 'set', 'let', 'static', 'yield',
  'async', 'await', 'interface', 'type', 'abstract', 'implements',
  'private', 'protected', 'public', 'readonly',
  // ArkTS specific
  '@State', '@Prop', '@Link', '@Provide', '@Consume', '@StorageLink',
  '@StorageProp', '@Watch', '@Entry', '@Component', '@Builder',
  'struct', 'build', 'aboutToAppear', 'aboutToDisappear',
  'Text', 'Button', 'Row', 'Column', 'ForEach', 'List', 'ListItem',
  'Scroll', 'Divider', 'TextArea', 'TextInput', 'Toggle', 'Blank',
  'FlexAlign', 'BarState', 'TextAlign', 'TextOverflow', 'FontWeight',
  'Color', 'ButtonType', 'ToggleType',
]);

export class TokenHighlighter {
  /**
   * 对单行代码进行词法分析，返回 Token 列表
   * @param line 单行文本
   * @param extension 文件扩展名（用于判断语言）
   */
  static tokenize(line: string, extension: string = '.ets'): Token[] {
    if (line.length === 0) return [];
    const tokens: Token[] = [];
    let i = 0;
    const len = line.length;

    while (i < len) {
      const ch = line.charAt(i);
      const remaining = line.substring(i);

      // 单行注释 //
      if (ch === '/' && i + 1 < len && line.charAt(i + 1) === '/') {
        let commentEnd = i;
        while (commentEnd < len && line.charAt(commentEnd) !== '\n') commentEnd++;
        tokens.push({ start: i, end: commentEnd, type: TokenType.COMMENT });
        i = commentEnd;
        continue;
      }

      // 块注释 /* */
      if (ch === '/' && i + 1 < len && line.charAt(i + 1) === '*') {
        let commentEnd = i + 2;
        while (commentEnd < len && !(line.charAt(commentEnd) === '/' && line.charAt(commentEnd - 1) === '*')) {
          commentEnd++;
        }
        if (commentEnd < len) commentEnd++;
        tokens.push({ start: i, end: commentEnd, type: TokenType.COMMENT });
        i = commentEnd;
        continue;
      }

      // 字符串
      if (ch === '"' || ch === "'" || ch === '`') {
        let strEnd = i + 1;
        const quote = ch;
        while (strEnd < len && line.charAt(strEnd) !== quote) {
          if (line.charAt(strEnd) === '\\') strEnd++; // skip escape
          strEnd++;
        }
        if (strEnd < len) strEnd++; // include closing quote
        tokens.push({ start: i, end: strEnd, type: TokenType.STRING });
        i = strEnd;
        continue;
      }

      // 数字
      if ((ch >= '0' && ch <= '9') || (ch === '.' && i + 1 < len && line.charAt(i + 1) >= '0' && line.charAt(i + 1) <= '9')) {
        let numEnd = i;
        let hasDot = false;
        while (numEnd < len) {
          const nc = line.charAt(numEnd);
          if (nc >= '0' && nc <= '9') { numEnd++; continue; }
          if (nc === '.' && !hasDot) { hasDot = true; numEnd++; continue; }
          break;
        }
        tokens.push({ start: i, end: numEnd, type: TokenType.NUMBER });
        i = numEnd;
        continue;
      }

      // 空白
      if (ch === ' ' || ch === '\t') {
        let wsEnd = i;
        while (wsEnd < len && (line.charAt(wsEnd) === ' ' || line.charAt(wsEnd) === '\t')) wsEnd++;
        tokens.push({ start: i, end: wsEnd, type: TokenType.PLAIN });
        i = wsEnd;
        continue;
      }

      // 操作符/标点
      if ('{}()[];,.<>=+-*/%!&|^~?:'.indexOf(ch) >= 0) {
        tokens.push({ start: i, end: i + 1, type: TokenType.OPERATOR });
        i++;
        continue;
      }

      // 标识符/关键词
      let idEnd = i;
      while (idEnd < len && TokenHighlighter.isIdentChar(line.charAt(idEnd))) idEnd++;
      const word = line.substring(i, idEnd);
      if (ARKTS_KEYWORDS.has(word)) {
        tokens.push({ start: i, end: idEnd, type: TokenType.KEYWORD });
      } else {
        tokens.push({ start: i, end: idEnd, type: TokenType.IDENTIFIER });
      }
      i = idEnd;
    }

    return tokens;
  }

  private static isIdentChar(ch: string): boolean {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') || ch === '_' || ch === '$' || ch === '@';
  }

  /** 获取 Token 类型对应的颜色 */
  static getTokenColor(type: TokenType, isMonokai: boolean): string {
    if (isMonokai) {
      switch (type) {
        case TokenType.KEYWORD: return '#F92672';
        case TokenType.STRING: return '#E6DB74';
        case TokenType.COMMENT: return '#75715E';
        case TokenType.NUMBER: return '#AE81FF';
        case TokenType.OPERATOR: return '#F8F8F2';
        case TokenType.IDENTIFIER: return '#F8F8F2';
        default: return '#F8F8F2';
      }
    }
    switch (type) {
      case TokenType.KEYWORD: return '#D73A49';
      case TokenType.STRING: return '#032F62';
      case TokenType.COMMENT: return '#6A737D';
      case TokenType.NUMBER: return '#005CC5';
      case TokenType.OPERATOR: return '#24292E';
      case TokenType.IDENTIFIER: return '#24292E';
      default: return '#1C1C1C';
    }
  }
}
