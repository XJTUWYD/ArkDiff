/**
 * AegisDiff — TokenHighlighter（多语言语法高亮引擎）
 * 支持 ArkTS/TypeScript、JavaScript、Python、Java、C/C++ 等语言
 */

export enum TokenType {
  KEYWORD = 0, STRING = 1, COMMENT = 2, NUMBER = 3,
  OPERATOR = 4, IDENTIFIER = 5, PLAIN = 6,
}

export interface Token { start: number; end: number; type: TokenType; }

// ===================== 关键词集 =====================

const ARKTS_KEYWORDS = new Set([
  'break','case','catch','class','const','continue','debugger','default','delete','do',
  'else','enum','export','extends','false','finally','for','function','if','import','in',
  'instanceof','new','null','return','super','switch','this','throw','true','try','typeof',
  'var','void','while','with','as','from','of','get','set','let','static','yield',
  'async','await','interface','type','abstract','implements','private','protected','public','readonly',
  '@State','@Prop','@Link','@Provide','@Consume','@StorageLink','@StorageProp','@Watch',
  '@Entry','@Component','@Builder','struct','build','aboutToAppear','aboutToDisappear',
  'Text','Button','Row','Column','ForEach','List','ListItem','Scroll','Divider',
  'TextArea','TextInput','Toggle','Blank','FlexAlign','BarState','TextAlign',
  'TextOverflow','FontWeight','Color','ButtonType','ToggleType',
]);

const PYTHON_KEYWORDS = new Set([
  'False','None','True','and','as','assert','async','await','break','class','continue',
  'def','del','elif','else','except','finally','for','from','global','if','import','in',
  'is','lambda','nonlocal','not','or','pass','raise','return','try','while','with','yield',
  'print','self','__init__','__name__','__main__',
]);

const JS_KEYWORDS = new Set([
  'break','case','catch','class','const','continue','debugger','default','delete','do',
  'else','export','extends','false','finally','for','function','if','import','in',
  'instanceof','new','null','return','super','switch','this','throw','true','try','typeof',
  'var','void','while','with','let','static','yield','async','await','of','from',
  'console','document','window','undefined','NaN','Infinity','Promise','Set','Map','Array','Object','String','Number',
]);

const JAVA_KEYWORDS = new Set([
  'abstract','assert','boolean','break','byte','case','catch','char','class','const',
  'continue','default','do','double','else','enum','extends','final','finally','float',
  'for','goto','if','implements','import','instanceof','int','interface','long','native',
  'new','package','private','protected','public','return','short','static','strictfp',
  'super','switch','synchronized','this','throw','throws','transient','try','void',
  'volatile','while','true','false','null','String','System','out','println','main',
]);

const C_KEYWORDS = new Set([
  'auto','break','case','char','const','continue','default','do','double','else','enum',
  'extern','float','for','goto','if','inline','int','long','register','restrict','return',
  'short','signed','sizeof','static','struct','switch','typedef','union','unsigned',
  'void','volatile','while','NULL','true','false','include','define','ifdef','ifndef',
  'endif','pragma','printf','scanf','malloc','free','main',
]);

const CSHARP_KEYWORDS = new Set([
  'abstract','as','async','await','base','bool','break','byte','case','catch','char',
  'checked','class','const','continue','decimal','default','delegate','do','double','else',
  'enum','event','explicit','extern','false','finally','fixed','float','for','foreach',
  'goto','if','implicit','in','int','interface','internal','is','lock','long','namespace',
  'new','null','object','operator','out','override','params','partial','private','protected',
  'public','readonly','ref','return','sbyte','sealed','short','sizeof','stackalloc','static',
  'string','struct','switch','this','throw','true','try','typeof','uint','ulong','unchecked',
  'unsafe','ushort','using','var','virtual','void','volatile','while','yield','get','set',
  'value','var',
]);

// 扩展名 → 关键词集
const EXT_KEYWORDS: Record<string, Set<string>> = {
  '.ets': ARKTS_KEYWORDS, '.ts': ARKTS_KEYWORDS, '.tsx': ARKTS_KEYWORDS,
  '.js': JS_KEYWORDS, '.jsx': JS_KEYWORDS, '.mjs': JS_KEYWORDS,
  '.py': PYTHON_KEYWORDS, '.pyw': PYTHON_KEYWORDS,
  '.java': JAVA_KEYWORDS,
  '.c': C_KEYWORDS, '.cpp': C_KEYWORDS, '.cc': C_KEYWORDS, '.cxx': C_KEYWORDS,
  '.h': C_KEYWORDS, '.hpp': C_KEYWORDS, '.cs': CSHARP_KEYWORDS,
};

// C-style: // 单行, /* */ 块
const CS_SINGLE = '//';
const CS_MULTI = '/*``*/'; // split by placeholders

// Python-style: # 单行, \"\"\" 块
const PY_SINGLE = '#';
const PY_MULTI = '"""``"""';

export class TokenHighlighter {
  static tokenize(line: string, extension: string = '.ets'): Token[] {
    if (line.length === 0) return [];
    const tokens: Token[] = [];
    const keywords = EXT_KEYWORDS[extension] || ARKTS_KEYWORDS;
    const isPython = extension === '.py' || extension === '.pyw';
    let i = 0;
    const len = line.length;

    while (i < len) {
      const ch = line.charAt(i);

      // C-style 块注释
      if (!isPython && ch === '/' && i + 1 < len && line.charAt(i + 1) === '*') {
        let ce = i + 2;
        while (ce < len && !(line.charAt(ce) === '*' && ce + 1 < len && line.charAt(ce + 1) === '/')) ce++;
        if (ce < len) ce += 2;
        tokens.push({ start: i, end: ce, type: TokenType.COMMENT });
        i = ce; continue;
      }
      // Python 块注释
      if (isPython && ch === '"' && i + 2 < len && line.charAt(i + 1) === '"' && line.charAt(i + 2) === '"') {
        let ce = i + 3;
        while (ce + 2 < len && !(line.charAt(ce) === '"' && line.charAt(ce + 1) === '"' && line.charAt(ce + 2) === '"')) ce++;
        if (ce + 2 < len) ce += 3;
        tokens.push({ start: i, end: ce, type: TokenType.COMMENT });
        i = ce; continue;
      }
      // C-style 单行注释
      if (!isPython && ch === '/' && i + 1 < len && line.charAt(i + 1) === '/') {
        tokens.push({ start: i, end: len, type: TokenType.COMMENT });
        i = len; continue;
      }
      // Python 单行注释
      if (isPython && ch === '#') {
        tokens.push({ start: i, end: len, type: TokenType.COMMENT });
        i = len; continue;
      }

      // 字符串
      if (ch === '"' || ch === "'" || ch === '`') {
        const quote = ch;
        let strEnd = i + 1;
        while (strEnd < len && line.charAt(strEnd) !== quote) {
          if (line.charAt(strEnd) === '\\') strEnd++;
          strEnd++;
        }
        if (strEnd < len) strEnd++;
        tokens.push({ start: i, end: strEnd, type: TokenType.STRING });
        i = strEnd; continue;
      }

      // 数字（含 0x/0b/0o 前缀、小数、科学计数法）
      if ((ch >= '0' && ch <= '9') || (ch === '.' && i + 1 < len && line.charAt(i + 1) >= '0' && line.charAt(i + 1) <= '9')) {
        let numEnd = i;
        // 16/2/8 进制前缀
        if (ch === '0' && i + 1 < len) {
          const p = line.charAt(i + 1);
          if (p === 'x' || p === 'X' || p === 'b' || p === 'B' || p === 'o' || p === 'O') {
            numEnd = i + 2;
            while (numEnd < len && TokenHighlighter.isHexChar(line.charAt(numEnd))) numEnd++;
            tokens.push({ start: i, end: numEnd, type: TokenType.NUMBER });
            i = numEnd; continue;
          }
        }
        let hasDot = false;
        while (numEnd < len) {
          const nc = line.charAt(numEnd);
          if (nc >= '0' && nc <= '9') { numEnd++; continue; }
          if (nc === '.' && !hasDot) { hasDot = true; numEnd++; continue; }
          break;
        }
        // 科学计数法: 1e10 / 1.5e-3
        if (numEnd < len && (line.charAt(numEnd) === 'e' || line.charAt(numEnd) === 'E')) {
          let pe = numEnd + 1;
          if (pe < len && (line.charAt(pe) === '+' || line.charAt(pe) === '-')) pe++;
          let expDigits = 0;
          while (pe < len && line.charAt(pe) >= '0' && line.charAt(pe) <= '9') { pe++; expDigits++; }
          if (expDigits > 0) numEnd = pe;
        }
        tokens.push({ start: i, end: numEnd, type: TokenType.NUMBER });
        i = numEnd; continue;
      }

      // 空白
      if (ch === ' ' || ch === '\t') {
        let wsEnd = i;
        while (wsEnd < len && (line.charAt(wsEnd) === ' ' || line.charAt(wsEnd) === '\t')) wsEnd++;
        tokens.push({ start: i, end: wsEnd, type: TokenType.PLAIN });
        i = wsEnd; continue;
      }

      // 操作符
      if ('{}()[];,.<>=+-*/%!&|^~?:'.indexOf(ch) >= 0) {
        tokens.push({ start: i, end: i + 1, type: TokenType.OPERATOR });
        i++; continue;
      }

      // 标识符/关键词
      let idEnd = i;
      while (idEnd < len && TokenHighlighter.isIdentChar(line.charAt(idEnd))) idEnd++;
      if (idEnd > i) {
        const word = line.substring(i, idEnd);
        tokens.push({ start: i, end: idEnd, type: keywords.has(word) ? TokenType.KEYWORD : TokenType.IDENTIFIER });
        i = idEnd;
      } else {
        // 未识别字符（如 CJK / emoji），按单字符 PLAIN 处理并保证前进，避免死循环
        const step = ch.length;
        tokens.push({ start: i, end: i + 1, type: TokenType.PLAIN });
        i += step;
      }
    }

    return tokens;
  }

  static detectLanguage(fileName: string): string {
    const dot = fileName.lastIndexOf('.');
    if (dot < 0) return '.ets';
    const ext = fileName.substring(dot).toLowerCase();
    return EXT_KEYWORDS[ext] ? ext : '.ets';
  }

  private static isIdentChar(ch: string): boolean {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') || ch === '_' || ch === '$' || ch === '@';
  }

  private static isHexChar(ch: string): boolean {
    return (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F') || ch === '_';
  }

  static getTokenColor(type: TokenType, isMonokai: boolean): string {
    if (isMonokai) {
      switch (type) {
        case TokenType.KEYWORD: return '#F92672';
        case TokenType.STRING: return '#E6DB74';
        case TokenType.COMMENT: return '#75715E';
        case TokenType.NUMBER: return '#AE81FF';
        case TokenType.OPERATOR: return '#F8F8F2';
        default: return '#F8F8F2';
      }
    }
    switch (type) {
      case TokenType.KEYWORD: return '#D73A49';
      case TokenType.STRING: return '#032F62';
      case TokenType.COMMENT: return '#6A737D';
      case TokenType.NUMBER: return '#005CC5';
      case TokenType.OPERATOR: return '#24292E';
      default: return '#1C1C1C';
    }
  }
}
