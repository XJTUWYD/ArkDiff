/**
 * AegisDiff — DiffSessionViewModel（Diff 会话状态管理器）
 *
 * 职责：
 * - 管理一次 Diff 会话的全部状态
 * - 文本输入 / 文件导入 / 编码处理
 * - Diff 计算编排
 * - 视图模式切换
 * - 搜索与差异导航
 * - 双向同步（side-by-side sync）
 * - 行内编辑支持
 * - 导出 / 剪辑板
 *
 * 页面仅负责渲染，所有业务逻辑收口于此。
 */
import { DiffEngine } from '../engine/DiffEngine';
import { DiffBlockLocator, DiffBlock } from '../engine/DiffBlockLocator';
import { FileContentService, FileContent } from '../services/FileContentService';
import { DiffLine, DiffOptions, ViewMode, DiffResult } from '../model/DiffModels';
import { pasteboard } from '@kit.BasicServicesKit';

/** 搜索结果 */
interface SearchMatch {
  lineIndex: number;
  columnStart: number;
  matchText: string;
}

/** 编辑状态 */
interface EditState {
  lineIndex: number;
  originalContent: string;
  buffer: string;
}

/** 编辑快照（用于 undo/redo） */
interface EditSnapshot {
  textA: string;
  textB: string;
  /** 变更描述（用于 UI 提示） */
  description: string;
}

/** 最大历史记录数 */
const MAX_HISTORY = 50;

export class DiffSessionViewModel {
  // ==================== 文件 / 输入状态 ====================
  textA: string = '';
  textB: string = '';
  fileNameA: string = '';
  fileNameB: string = '';
  isFileMode: boolean = false;

  // ==================== Diff 结果 ====================
  diffResult: DiffResult | null = null;
  diffBlocks: DiffBlock[] = [];

  // ==================== 视图 ====================
  viewMode: ViewMode = ViewMode.SIDE_BY_SIDE;
  highlightBlockIndex: number = -1;

  // ==================== 搜索 ====================
  searchVisible: boolean = false;
  searchKeyword: string = '';
  searchMatches: SearchMatch[] = [];
  searchCurrentIndex: number = 0;
  /** 搜索匹配行索引缓存（Set<number>），O(1) 判断 isLineSearchMatch */
  private _searchMatchLineSet: Set<number> = new Set();

  // ==================== 编辑 ====================
  editState: EditState | null = null;

  // ==================== 分栏编辑 ====================
  sideEditState: EditState | null = null;
  sideEditSide: 'left' | 'right' = 'left';

  // ==================== 选项 ====================
  enableCharDiff: boolean = false;
  ignoreBlankLines: boolean = false;
  isComputing: boolean = false;

  /** diff 错误信息（null = 无错误） */
  lastError: string | null = null;

  // ==================== Undo/Redo ====================
  private undoStack: EditSnapshot[] = [];
  private redoStack: EditSnapshot[] = [];

  /** 文件导入回调（由页面注入，用于触发文件选择器） */
  onRequestPickFile?: (side: 'A' | 'B') => void;

  /**
   * 从文本输入执行 Diff
   */
  runTextDiff(): void {
    if (this.textA.length === 0 && this.textB.length === 0) return;

    this.isComputing = true;
    this.isFileMode = false;
    this.lastError = null;
    try {
      const options: DiffOptions = {
        ignoreBlankLines: this.ignoreBlankLines,
        enableCharDiff: this.enableCharDiff
      };
      this.diffResult = DiffEngine.computeDiff(this.textA, this.textB, options);
      this.diffBlocks = DiffBlockLocator.locateBlocks(this.diffResult.unifiedLines);
      this.highlightBlockIndex = this.diffBlocks.length > 0 ? 0 : -1;
      this.searchMatches = [];
      this.searchCurrentIndex = 0;
      this._searchMatchLineSet = new Set();
    } catch (e) {
      const msg = e instanceof Object ? JSON.stringify(e) : String(e);
      console.error('DiffSessionViewModel.runTextDiff error:', msg);
      this.lastError = `Diff 计算失败: ${msg}`;
      this.diffResult = null;
      this.diffBlocks = [];
    } finally {
      this.isComputing = false;
    }
  }

  /**
   * 从文件 URI 加载文件并执行 Diff
   */
  loadFileAndDiff(uriA: string, uriB: string): void {
    this.isComputing = true;
    this.isFileMode = true;
    try {
      const resultA = FileContentService.readFileContent(uriA);
      const resultB = FileContentService.readFileContent(uriB);

      this.fileNameA = resultA.fileName;
      this.fileNameB = resultB.fileName;

      if (resultA.error && !resultA.isBinary) {
        console.error('读取文件A失败:', resultA.error);
      }
      if (resultB.error && !resultB.isBinary) {
        console.error('读取文件B失败:', resultB.error);
      }

      this.textA = resultA.content;
      this.textB = resultB.content;

      const options: DiffOptions = {
        ignoreBlankLines: this.ignoreBlankLines,
        enableCharDiff: this.enableCharDiff
      };
      this.diffResult = DiffEngine.computeDiff(this.textA, this.textB, options);
      this.diffBlocks = DiffBlockLocator.locateBlocks(this.diffResult.unifiedLines);
      this.highlightBlockIndex = this.diffBlocks.length > 0 ? 0 : -1;
      this.searchMatches = [];
      this.searchCurrentIndex = 0;
      this._searchMatchLineSet = new Set();
    } catch (e) {
      console.error('DiffSessionViewModel.loadFileAndDiff error:', JSON.stringify(e));
    } finally {
      this.isComputing = false;
    }
  }

  /**
   * 切换视图模式
   */
  switchView(mode: ViewMode): void {
    this.viewMode = mode;
  }

  /**
   * 切换字符级 Diff
   */
  toggleCharDiff(): void {
    this.enableCharDiff = !this.enableCharDiff;
    this.runTextDiff();
  }

  // ==================== 差异导航 ====================

  navigateToBlock(index: number): void {
    if (index >= 0 && index < this.diffBlocks.length) {
      this.highlightBlockIndex = index;
    }
  }

  navigateToPrevBlock(): void {
    if (this.diffBlocks.length === 0) return;
    if (this.highlightBlockIndex <= 0) {
      this.highlightBlockIndex = this.diffBlocks.length - 1;
    } else {
      this.highlightBlockIndex--;
    }
  }

  navigateToNextBlock(): void {
    if (this.diffBlocks.length === 0) return;
    if (this.highlightBlockIndex >= this.diffBlocks.length - 1) {
      this.highlightBlockIndex = 0;
    } else {
      this.highlightBlockIndex++;
    }
  }

  /**
   * 获取当前高亮的差异块
   */
  getHighlightedBlock(): DiffBlock | null {
    if (this.highlightBlockIndex >= 0 && this.highlightBlockIndex < this.diffBlocks.length) {
      return this.diffBlocks[this.highlightBlockIndex];
    }
    return null;
  }

  /**
   * 判断某行是否属于当前高亮的差异块
   */
  isLineInHighlightedBlock(lineIndex: number): boolean {
    const block = this.getHighlightedBlock();
    if (!block) return false;
    return lineIndex >= block.startIndex && lineIndex <= block.endLine;
  }

  // ==================== 搜索 ====================

  showSearch(): void {
    this.searchVisible = true;
  }

  hideSearch(): void {
    this.searchVisible = false;
    this.searchMatches = [];
    this.searchCurrentIndex = 0;
    this.searchKeyword = '';
    this._searchMatchLineSet = new Set();
  }

  /** 重建搜索匹配行索引缓存 */
  private _buildSearchMatchLineSet(): void {
    this._searchMatchLineSet = new Set<number>();
    for (let i = 0; i < this.searchMatches.length; i++) {
      this._searchMatchLineSet.add(this.searchMatches[i].lineIndex);
    }
  }

  performSearch(keyword: string): void {
    this.searchKeyword = keyword;
    this.searchMatches = [];
    this.searchCurrentIndex = 0;
    this._searchMatchLineSet = new Set();

    if (!keyword || !this.diffResult) return;

    const lower = keyword.toLowerCase();
    const lines = this.diffResult.unifiedLines;

    for (let i = 0; i < lines.length; i++) {
      const lowerContent = lines[i].content.toLowerCase();
      let pos = lowerContent.indexOf(lower);
      while (pos >= 0) {
        this.searchMatches.push({
          lineIndex: i,
          columnStart: pos,
          matchText: lines[i].content.substring(pos, pos + keyword.length)
        });
        pos = lowerContent.indexOf(lower, pos + 1);
      }
    }
    this._buildSearchMatchLineSet();
  }

  navigateSearchPrev(): void {
    if (this.searchMatches.length === 0) return;
    if (this.searchCurrentIndex <= 0) {
      this.searchCurrentIndex = this.searchMatches.length - 1;
    } else {
      this.searchCurrentIndex--;
    }
  }

  navigateSearchNext(): void {
    if (this.searchMatches.length === 0) return;
    if (this.searchCurrentIndex >= this.searchMatches.length - 1) {
      this.searchCurrentIndex = 0;
    } else {
      this.searchCurrentIndex++;
    }
  }

  /** O(1) 判断某行是否有搜索匹配（使用 Set 缓存） */
  isLineSearchMatch(lineIndex: number): boolean {
    return this._searchMatchLineSet.has(lineIndex);
  }

  get currentSearchResultIndex(): number {
    return this.searchCurrentIndex;
  }

  get totalSearchResults(): number {
    return this.searchMatches.length;
  }

  /**
   * 获取当前搜索匹配的行索引（用于滚动定位）
   */
  getCurrentSearchLineIndex(): number {
    if (this.searchMatches.length === 0) return -1;
    return this.searchMatches[this.searchCurrentIndex].lineIndex;
  }

  // ==================== 双向同步 ====================

  syncToRight(lineIndexA: number): void {
    if (!this.diffResult) return;
    const leftLines = this.diffResult.leftLines;
    if (lineIndexA < 0 || lineIndexA >= leftLines.length) return;
    const leftLine = leftLines[lineIndexA];
    const content = leftLine.content;
    const linesB = this.textB.split('\n');

    this.pushSnapshot('同步到右侧');
    // DELETED 行：lineNumberB = -1，说明 B 侧无对应行，需要插入（而非替换）
    if (leftLine.lineNumberB <= 0) {
      const insIdx = this._findNearestBInsertPos(leftLines, lineIndexA);
      if (insIdx >= 0 && insIdx <= linesB.length) {
        linesB.splice(insIdx, 0, content);
      } else {
        linesB.push(content);
      }
      this.textB = linesB.join('\n');
      this.runTextDiff();
      return;
    }

    // MODIFIED / UNCHANGED：替换目标行
    const targetIndex = leftLine.lineNumberB - 1;
    if (targetIndex >= 0 && targetIndex < linesB.length) {
      linesB[targetIndex] = content;
      this.textB = linesB.join('\n');
      this.runTextDiff();
    }
  }

  syncToLeft(lineIndexB: number): void {
    if (!this.diffResult) return;
    const rightLines = this.diffResult.rightLines;
    if (lineIndexB < 0 || lineIndexB >= rightLines.length) return;
    const rightLine = rightLines[lineIndexB];
    const content = rightLine.content;
    const linesA = this.textA.split('\n');

    this.pushSnapshot('同步到左侧');
    // ADDED 行：lineNumberA = -1，说明 A 侧无对应行，需要插入（而非替换）
    if (rightLine.lineNumberA <= 0) {
      const insIdx = this._findNearestAInsertPos(rightLines, lineIndexB);
      if (insIdx >= 0 && insIdx <= linesA.length) {
        linesA.splice(insIdx, 0, content);
      } else {
        linesA.push(content);
      }
      this.textA = linesA.join('\n');
      this.runTextDiff();
      return;
    }

    // MODIFIED / UNCHANGED：替换目标行
    const targetIndex = rightLine.lineNumberA - 1;
    if (targetIndex >= 0 && targetIndex < linesA.length) {
      linesA[targetIndex] = content;
      this.textA = linesA.join('\n');
      this.runTextDiff();
    }
  }

  /** 在 leftLines 中向后/向前查找第一个有效 lineNumberB，用于确定 B 侧插入位置 */
  private _findNearestBInsertPos(leftLines: DiffLine[], fromIndex: number): number {
    for (let i = fromIndex + 1; i < leftLines.length; i++) {
      if (leftLines[i].lineNumberB > 0) return leftLines[i].lineNumberB - 1;
    }
    for (let i = fromIndex - 1; i >= 0; i--) {
      if (leftLines[i].lineNumberB > 0) return leftLines[i].lineNumberB;
    }
    return -1;
  }

  /** 在 rightLines 中向后/向前查找第一个有效 lineNumberA，用于确定 A 侧插入位置 */
  private _findNearestAInsertPos(rightLines: DiffLine[], fromIndex: number): number {
    for (let i = fromIndex + 1; i < rightLines.length; i++) {
      if (rightLines[i].lineNumberA > 0) return rightLines[i].lineNumberA - 1;
    }
    for (let i = fromIndex - 1; i >= 0; i--) {
      if (rightLines[i].lineNumberA > 0) return rightLines[i].lineNumberA;
    }
    return -1;
  }

  // ==================== Undo/Redo ====================

  /**
   * 判断当前是否有可撤销的操作
   */
  get canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  /**
   * 判断当前是否有可重做的操作
   */
  get canRedo(): boolean {
    return this.redoStack.length > 0;
  }

  /**
   * 保存当前状态作为编辑快照
   * 在编辑操作之前调用（sync/submitEdit/syncToRight/syncToLeft 调用前先 pushSnapshot）
   */
  pushSnapshot(description: string): void {
    // 清空 redo 栈（新操作后旧 redo 不可用）
    this.redoStack = [];
    this.undoStack.push({
      textA: this.textA,
      textB: this.textB,
      description: description
    });
    // 限制历史记录数量
    if (this.undoStack.length > MAX_HISTORY) {
      this.undoStack.splice(0, 1);
    }
  }

  /**
   * 撤销：恢复到上一个快照
   */
  undo(): boolean {
    if (this.undoStack.length === 0) return false;

    // 保存当前状态到 redo 栈
    const current: EditSnapshot = {
      textA: this.textA,
      textB: this.textB,
      description: '恢复到此状态'
    };
    this.redoStack.push(current);

    // 恢复上一个快照
    const snapshot = this.undoStack.pop()!;
    this.textA = snapshot.textA;
    this.textB = snapshot.textB;
    this.runTextDiff();

    console.info(`DiffSessionViewModel: 撤销 — ${snapshot.description}`);
    return true;
  }

  /**
   * 重做：恢复到 redo 栈顶的快照
   */
  redo(): boolean {
    if (this.redoStack.length === 0) return false;

    // 保存当前状态到 undo 栈
    const current: EditSnapshot = {
      textA: this.textA,
      textB: this.textB,
      description: '重做前状态'
    };
    this.undoStack.push(current);

    // 恢复 redo 快照
    const snapshot = this.redoStack.pop()!;
    this.textA = snapshot.textA;
    this.textB = snapshot.textB;
    this.runTextDiff();

    console.info(`DiffSessionViewModel: 重做 — ${snapshot.description}`);
    return true;
  }

  /**
   * 重置 undo/redo 历史（加载新文件时调用）
   */
  resetHistory(): void {
    this.undoStack = [];
    this.redoStack = [];
  }
  }

  // ==================== 行内编辑 ====================

  startEdit(lineIndex: number): void {
    if (!this.diffResult) return;
    const lines = this.diffResult.unifiedLines;
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    const line = lines[lineIndex];
    this.editState = {
      lineIndex: lineIndex,
      originalContent: line.content,
      buffer: line.content
    };
  }

  cancelEdit(): void {
    this.editState = null;
  }

  submitEdit(value: string): void {
    if (!this.editState || !this.diffResult) return;
    this.pushSnapshot('行内编辑');
    const line = this.diffResult.unifiedLines[this.editState.lineIndex];

    // 根据行类型更新 textA 或 textB
    if (line.type === 2) {
      // DELETED 行：更新 textA
      const linesA = this.textA.split('\n');
      const idxA = line.lineNumberA - 1;
      if (idxA >= 0 && idxA < linesA.length) {
        linesA[idxA] = value;
        this.textA = linesA.join('\n');
      }
    } else {
      // ADDED / MODIFIED / UNCHANGED：更新 textB
      const linesB = this.textB.split('\n');
      const idxB = line.lineNumberB - 1;
      if (idxB >= 0 && idxB < linesB.length) {
        linesB[idxB] = value;
        this.textB = linesB.join('\n');
      }
    }

    this.editState = null;
    this.runTextDiff();
  }

  isEditing(lineIndex: number): boolean {
    return this.editState !== null && this.editState.lineIndex === lineIndex;
  }

  getEditBuffer(): string {
    return this.editState ? this.editState.buffer : '';
  }

  // ==================== 分栏编辑 ====================

  /**
   * 在分栏视图中开始编辑某一行
   * @param sbsLineIndex SideBySide pair 的索引
   * @param side 编辑左侧还是右侧
   */
  startSideEdit(sbsLineIndex: number, side: 'left' | 'right'): void {
    if (!this.diffResult) return;
    const lines = side === 'left' ? this.diffResult.leftLines : this.diffResult.rightLines;
    if (sbsLineIndex < 0 || sbsLineIndex >= lines.length) return;
    const line = lines[sbsLineIndex];
    // 不允许编辑空占位行
    if (line.content.length === 0 && line.type === 0) return;
    this.sideEditState = {
      lineIndex: sbsLineIndex,
      originalContent: line.content,
      buffer: line.content
    };
    this.sideEditSide = side;
  }

  cancelSideEdit(): void {
    this.sideEditState = null;
  }

  /**
   * 提交分栏编辑：更新对应侧的文本并重算 diff
   */
  submitSideEdit(value: string): void {
    if (!this.sideEditState || !this.diffResult) return;
    this.pushSnapshot('分栏编辑');
    const lineIndex = this.sideEditState.lineIndex;

    if (this.sideEditSide === 'left') {
      const leftLine = this.diffResult.leftLines[lineIndex];
      if (leftLine.lineNumberA > 0) {
        const linesA = this.textA.split('\n');
        const idxA = leftLine.lineNumberA - 1;
        if (idxA >= 0 && idxA < linesA.length) {
          linesA[idxA] = value;
          this.textA = linesA.join('\n');
        }
      }
    } else {
      const rightLine = this.diffResult.rightLines[lineIndex];
      if (rightLine.lineNumberB > 0) {
        const linesB = this.textB.split('\n');
        const idxB = rightLine.lineNumberB - 1;
        if (idxB >= 0 && idxB < linesB.length) {
          linesB[idxB] = value;
          this.textB = linesB.join('\n');
        }
      }
    }

    this.sideEditState = null;
    this.runTextDiff();
  }

  /**
   * 检查分栏中某侧某行是否在编辑中
   */
  isSideEditing(sbsLineIndex: number, side: 'left' | 'right'): boolean {
    return this.sideEditState !== null &&
      this.sideEditState.lineIndex === sbsLineIndex &&
      this.sideEditSide === side;
  }

  getSideEditBuffer(): string {
    return this.sideEditState ? this.sideEditState.buffer : '';
  }

  // ==================== 导出 ====================

  /**
   * 生成 Unified Diff 格式文本
   */
  generateUnifiedDiff(): string {
    if (!this.diffResult) return '';
    const headerA = this.fileNameA || '文件A';
    const headerB = this.fileNameB || '文件B';
    let output = `--- ${headerA}\n+++ ${headerB}\n`;

    for (let line of this.diffResult.unifiedLines) {
      switch (line.type) {
        case 0: output += `  ${line.content}\n`; break;
        case 1: output += `+ ${line.content}\n`; break;
        case 2: output += `- ${line.oldContent || line.content}\n`; break;
        case 3: output += `- ${line.oldContent}\n+ ${line.content}\n`; break;
      }
    }
    return output;
  }

  /**
   * 复制到剪贴板
   */
  copyToClipboard(text: string, callback?: () => void): void {
    try {
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      const sysPasteboard = pasteboard.getSystemPasteboard();
      sysPasteboard.setData(pasteData).then(() => {
        if (callback) callback();
      });
    } catch (_e) {
      console.error('DiffSessionViewModel: 剪贴板调用失败');
    }
  }
}