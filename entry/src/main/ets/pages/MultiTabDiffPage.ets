/**
 * AegisDiff — MultiTabDiffPage（多 Tab + 最近文件）
 * 支持多标签工作区、标签页切换、最近文件列表
 */
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import pasteboard from '@ohos.pasteboard';
import { DiffBlockLocator, DiffBlock } from '../engine/DiffBlockLocator';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffOverviewBar } from '../components/DiffOverviewBar';
import { SampleDataProvider } from '../utils/SampleDataProvider';
import { FileContentService } from '../services/FileContentService';
import { ViewMode, DiffOptions, CharSegment } from '../model/DiffModels';
import { DiffEngine } from '../engine/DiffEngine';
import { TokenType, TokenHighlighter, Token } from '../engine/TokenHighlighter';

// ===================== 数据模型 =====================

interface TabSession {
  id: number;
  label: string;
  textA: string;
  textB: string;
  viewMode: ViewMode;
  fileAName: string;
  fileBName: string;
}

interface RecentFile {
  name: string;
  path: string;
  timestamp: number;
}

interface SbsPair {
  leftType: number; leftContent: string; leftLineNo: number;
  rightType: number; rightContent: string; rightLineNo: number;
}
interface DisplayItem { kind: number; lineIdx: number; gapCount: number; }

// ===================== UI 组件 =====================

@Component
struct UnifiedLine {
  @Prop typeNum: number = 0; @Prop content: string = '';
  @Prop linenoA: number = -1; @Prop linenoB: number = -1;
  @Prop isMonokai: boolean = false; @Prop isHighlighted: boolean = false;
  @Prop charSegments: CharSegment[] = [];
  @Prop isEditing: boolean = false; @Link editBuffer: string;
  onLineClick?: () => void; onEditSubmit?: (value: string) => void;

  build() {
    Row() {
      Text(this.linenoA > 0 ? `${this.linenoA}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.linenoB > 0 ? `${this.linenoB}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.getPrefix()).fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.getPColor()).width(14).textAlign(TextAlign.Center)
      if (this.isEditing) {
        TextInput({ text: this.editBuffer }).fontSize(12).fontFamily('monospace').fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C')
          .backgroundColor(Color.Transparent).height(22).layoutWeight(1)
          .padding({ left: 6, right: 6 }).border({ width: 1, color: '#007AFF', style: BorderStyle.Dashed })
          .onChange((v: string) => { this.editBuffer = v; })
          .onSubmit(() => { if (this.onEditSubmit) this.onEditSubmit(this.editBuffer); })
      } else {
        this.syntaxText()
      }
    }.width('100%').height(22).backgroundColor(this.getBg())
    .onClick(() => { if (!this.isEditing && this.onLineClick) this.onLineClick(); })
  }

  @Builder syntaxText() {
    Text() {
      ForEach(TokenHighlighter.tokenize(this.content), (tok: Token, _idx: number) => {
        Span(this.content.substring(tok.start, tok.end)).fontSize(12).fontFamily('monospace')
          .fontColor(TokenHighlighter.getTokenColor(tok.type, this.isMonokai))
      }, (tok: Token, _idx: number) => `tk_${_idx}`)
    }.maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 6 })
  }

  private getPrefix(): string { if (this.typeNum === 1) return '+'; if (this.typeNum === 2) return '-'; if (this.typeNum === 3) return '~'; return ' '; }
  private getPColor(): string {
    if (this.isMonokai) { if (this.typeNum === 1) return '#A6E22E'; if (this.typeNum === 2) return '#F92672'; if (this.typeNum === 3) return '#E6DB74'; return '#75715E'; }
    if (this.typeNum === 1) return '#1A7F37'; if (this.typeNum === 2) return '#BE2E2E'; if (this.typeNum === 3) return '#D4A017'; return '#CCC';
  }
  private getBg(): string {
    if (this.isEditing) return this.isMonokai ? '#2A2A40' : '#E3F2FD';
    if (this.isHighlighted) return this.isMonokai ? '#3A3A2A' : '#FFF9C4';
    if (this.isMonokai) { if (this.typeNum === 1) return '#232D1A'; if (this.typeNum === 2) return '#351B1B'; if (this.typeNum === 3) return '#33301A'; return '#272822'; }
    if (this.typeNum === 1) return '#E6FFEC'; if (this.typeNum === 2) return '#FFEBE9'; if (this.typeNum === 3) return '#FFF3D4'; return '#FFF';
  }
}

// ===================== 主页面 =====================

@Entry
@Component
struct MultiTabDiffPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @StorageLink('ignoreBlankLines') ignoreBlankLines: boolean = false;
  @StorageLink('multiTab_recentFiles') recentFilesRaw: string = '[]';

  // Tab 管理
  @State tabs: TabSession[] = [];
  @State activeIdx: number = 0;
  private idCounter: number = 1;

  // 当前 Tab 的 diff 状态
  @State viewMode: ViewMode = ViewMode.SIDE_BY_SIDE;
  @State inputVisible: boolean = true;
  @State navIdx: number = 0;
  @State added: number = 0; @State deleted: number = 0; @State modified: number = 0;
  @State similarity: number = 0; @State blockCnt: number = 0; @State hasResult: boolean = false;
  @State lineTypes: number[] = []; @State lineContents: string[] = [];
  @State lineNosA: number[] = []; @State lineNosB: number[] = [];
  @State sbsPairs: SbsPair[] = [];
  @State charSegs: CharSegment[][] = [];
  @State searchActive: boolean = false; @State searchKeyword: string = '';
  @State searchMatches: number[] = []; @State searchIdx: number = 0;
  @State collapsedGaps: Set<number> = new Set();
  @State displayItems: DisplayItem[] = [];
  @State editingIndex: number = -1; @State editBuffer: string = '';
  @State searchInActive: boolean = false; @State searchInKeyword: string = '';
  @State searchInMatches: number[] = []; @State searchInIdx: number = 0;
  @State showRecentFiles: boolean = false;
  @State recentFiles: RecentFile[] = [];

  private diffBlocks: DiffBlock[] = [];
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadRecentFiles();
    // 检查是否从目录对比跳转
    let fromDirA = AppStorage.get<string>('dirDiffContentA');
    if (fromDirA) {
      let fromDirB = AppStorage.get<string>('dirDiffContentB') || '';
      this.addTab(
        AppStorage.get<string>('dirDiffNameA') || '文件A',
        fromDirA, fromDirB,
        AppStorage.get<string>('dirDiffNameB') || '文件B'
      );
      AppStorage.delete('dirDiffContentA'); AppStorage.delete('dirDiffContentB');
      AppStorage.delete('dirDiffNameA'); AppStorage.delete('dirDiffNameB');
    } else {
      this.addTab('示例', SampleDataProvider.getSampleA(), SampleDataProvider.getSampleB(), '示例B');
    }
  }

  build() {
    Column() {
      // ===== Tab 栏 =====
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333') }
          .width(32).height(32).backgroundColor(Color.Transparent)
          .onClick(() => { router.back(); })
        Scroll() {
          Row({ space: 2 }) {
            ForEach(this.tabs, (tab: TabSession, idx: number) => {
              Row() {
                Text(tab.label).fontSize(12).maxLines(1).width(80).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .fontColor(idx === this.activeIdx ? '#007AFF' : '#666')
                if (this.tabs.length > 1) {
                  Text('×').fontSize(14).fontColor('#CCC').margin({ left: 4 }).padding({ left: 2, right: 2 })
                    .onClick(() => { this.closeTab(idx); })
                }
              }
              .padding({ left: 10, right: 6, top: 4, bottom: 4 })
              .backgroundColor(idx === this.activeIdx ? '#E3F2FD' : '#F5F5F5')
              .borderRadius(8).border({ width: idx === this.activeIdx ? 1 : 0, color: '#007AFF' })
              .onClick(() => { this.switchTab(idx); })
            }, (tab: TabSession) => `t_${tab.id}`)
          }.padding({ left: 4, right: 4 })
        }.layoutWeight(1).scrollBar(BarState.Off).scrollable(ScrollDirection.Horizontal)

        // 最近文件按钮
        Button({ type: ButtonType.Circle }) { Text('📁').fontSize(13) }
          .width(28).height(28).backgroundColor(this.showRecentFiles ? '#E3F2FD' : Color.Transparent)
          .onClick(() => { this.showRecentFiles = !this.showRecentFiles; })
        Button({ type: ButtonType.Circle }) { Text('+').fontSize(16).fontColor('#007AFF') }
          .width(28).height(28).backgroundColor(Color.Transparent)
          .onClick(() => { this.addTab('新对比', '', '', ''); })
      }
      .width('100%').height(40).padding({ left: 4, right: 4 }).backgroundColor('#FFF')
      Divider().height(1).color('#E0E0E0')

      // 最近文件面板
      if (this.showRecentFiles) {
        this.recentFilesPanel()
      }

      // ===== 文件选择 + 统计 =====
      Row() {
        Button('📂 A').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(10).padding({ left: 8, right: 8 })
          .onClick(() => { this.pickFileA(); })
        Button('📄 B').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
          .onClick(() => { this.pickFileB(); })
        Button('对比').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').fontColor(Color.White).borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
          .onClick(() => { this.doDiff(); })
        Button(this.viewMode === ViewMode.UNIFIED ? '统一' : '分栏').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#E0E0E0').fontColor('#666').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
          .onClick(() => { this.viewMode = this.viewMode === ViewMode.UNIFIED ? ViewMode.SIDE_BY_SIDE : ViewMode.UNIFIED; })
        if (this.hasResult) {
          Button('⇓').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#E3F2FD').fontColor('#1565C0').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
            .onClick(() => { this.exportDiff(); })
        }
        if (this.hasResult) {
          Text(`+${this.added} -${this.deleted} ~${this.modified} ${this.similarity}%`)
            .fontSize(11).fontColor('#999').layoutWeight(1).textAlign(TextAlign.End)
        } else {
          Blank().layoutWeight(1)
        }
      }
      .width('100%').height(36).padding({ left: 8, right: 8 })
      .backgroundColor('#FFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })

      // ===== 搜索栏 =====
      if (this.searchActive && this.hasResult) {
        Row() {
          Button({ type: ButtonType.Circle }) { Text('×').fontSize(14).fontColor('#666') }
            .width(28).height(28).backgroundColor(Color.Transparent)
            .onClick(() => { this.searchActive = false; this.searchKeyword = ''; this.searchMatches = []; })
          TextInput({ text: this.searchKeyword, placeholder: '搜索...' })
            .fontSize(12).height(28).layoutWeight(1).backgroundColor('#FFF').borderRadius(6).padding({ left: 6, right: 6 })
            .onChange((v: string) => { this.searchKeyword = v; this.doSearch(); })
          if (this.searchMatches.length > 0) {
            Text(`${this.searchIdx + 1}/${this.searchMatches.length}`).fontSize(11).fontColor('#999')
          }
        }.width('100%').height(36).padding({ left: 4, right: 4 }).backgroundColor('#FFF')
      }

      // ===== Diff 结果区域 =====
      if (this.hasResult) {
        Row() {
          Scroll(this.scroller) {
            if (this.viewMode === ViewMode.UNIFIED) {
              Column() {
                ForEach(this.displayItems, (item: DisplayItem, idx: number) => {
                  this.unifiedRow(item, idx)
                }, (item: DisplayItem, idx: number) => `ud_${idx}`)
              }
            } else {
              Column() {
                ForEach(this.sbsPairs, (p: SbsPair, i: number) => {
                  this.sbsRow(p, i)
                }, (p: SbsPair, i: number) => `s_${i}`)
              }
            }
          }.layoutWeight(1).height('100%').scrollBar(BarState.Auto)
          if (this.diffBlocks.length > 0) {
            DiffOverviewBar({
              blocks: this.diffBlocks, totalLines: this.lineTypes.length,
              isMonokai: this.colorMode === 'monokai', isDark: this.colorMode === 'dark', activeIdx: this.navIdx,
              onJumpToBlock: (idx: number) => { this.navIdx = idx; this.scrollToBlock(idx); }
            }).width(10).height('100%')
          }
        }.layoutWeight(1).height(0)
      } else {
        Column() { Text('点击「对比」查看差异').fontSize(13).fontColor('#999') }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }

      Divider().height(1).color('#E0E0E0')
      DiffNavigator({
        totalBlocks: this.blockCnt, currentIndex: this.navIdx,
        onNavigateTo: (i: number) => { this.navIdx = i; }
      }).width('100%').height(40)
    }
    .width('100%').height('100%').backgroundColor(this.colorMode === 'monokai' ? '#1E1F1C' : '#F5F5F5')
  }

  // ===================== 最近文件面板 =====================
  @Builder
  recentFilesPanel() {
    Column() {
      Row() {
        Text('最近文件').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#333')
        Blank()
        Text('清空').fontSize(11).fontColor('#BE2E2E').onClick(() => { this.clearRecent(); })
      }.width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })
      if (this.recentFiles.length === 0) {
        Text('暂无最近文件').fontSize(12).fontColor('#BBB').padding(16)
      } else {
        List() {
          ForEach(this.recentFiles, (rf: RecentFile) => {
            ListItem() {
              Row() {
                Text(rf.name).fontSize(12).fontColor('#1C1C1C').maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                Text(this.formatTime(rf.timestamp)).fontSize(10).fontColor('#999')
              }
              .width('100%').height(36).padding({ left: 12, right: 12 })
              .onClick(() => { this.openRecent(rf); })
            }
          }, (rf: RecentFile) => rf.path)
        }.height(200)
      }
    }
    .width('100%').backgroundColor('#FFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })
  }

  // ===================== Tab 操作 =====================
  private addTab(label: string, textA: string, textB: string, fileBName: string): void {
    const tabId = this.idCounter++;
    this.tabs.push({ id: tabId, label, textA, textB, viewMode: this.viewMode, fileAName: label, fileBName });
    if (this.tabs.length === 1) this.activeIdx = 0;
    else this.activeIdx = this.tabs.length - 1;
    this.restoreTab();
  }

  private closeTab(idx: number): void {
    if (this.tabs.length <= 1) return;
    this.tabs.splice(idx, 1);
    if (this.activeIdx >= this.tabs.length) this.activeIdx = this.tabs.length - 1;
    if (this.activeIdx < 0) this.activeIdx = 0;
    this.restoreTab();
  }

  private switchTab(idx: number): void {
    // 保存当前 Tab
    if (this.activeIdx >= 0 && this.activeIdx < this.tabs.length) {
      this.tabs[this.activeIdx].textA = this.tabs[this.activeIdx]?.textA || '';
      this.tabs[this.activeIdx].textB = this.tabs[this.activeIdx]?.textB || '';
    }
    this.activeIdx = idx;
    this.restoreTab();
  }

  private restoreTab(): void {
    if (this.activeIdx < 0 || this.activeIdx >= this.tabs.length) return;
    const tab = this.tabs[this.activeIdx];
    this.viewMode = tab.viewMode;
    this.hasResult = false;
    this.lineTypes = []; this.lineContents = []; this.lineNosA = []; this.lineNosB = [];
    this.sbsPairs = []; this.charSegs = []; this.displayItems = []; this.diffBlocks = [];
    this.added = 0; this.deleted = 0; this.modified = 0; this.similarity = 0; this.blockCnt = 0;
    this.navIdx = 0; this.editingIndex = -1;
    if (tab.textA || tab.textB) {
      this.doDiffInternal(tab.textA, tab.textB);
    }
  }

  // ===================== Diff 计算 =====================
  private doDiff(): void {
    const tab = this.tabs[this.activeIdx];
    if (!tab) return;
    this.doDiffInternal(tab.textA, tab.textB);
  }

  private doDiffInternal(textA: string, textB: string): void {
    if (textA.length === 0 && textB.length === 0) return;
    const result = DiffEngine.computeDiff(textA, textB, { ignoreBlankLines: this.ignoreBlankLines, enableCharDiff: true, ignoreCase: false, ignoreWhitespace: false, ignoreAllWhitespace: false, manualAlignments: new Map<number, number>() });
    this.lineTypes = []; this.lineContents = []; this.lineNosA = []; this.lineNosB = []; this.charSegs = [];
    for (let line of result.unifiedLines) {
      this.lineTypes.push(line.type); this.lineContents.push(line.content);
      this.lineNosA.push(line.lineNumberA); this.lineNosB.push(line.lineNumberB);
      this.charSegs.push(line.charSegments);
    }
    this.sbsPairs = [];
    const len = Math.max(result.leftLines.length, result.rightLines.length);
    for (let i = 0; i < len; i++) {
      let l = result.leftLines[i], r = result.rightLines[i];
      this.sbsPairs.push({
        leftType: l ? l.type : 0, leftContent: l ? l.content : '', leftLineNo: l ? l.lineNumberA : -1,
        rightType: r ? r.type : 0, rightContent: r ? r.content : '', rightLineNo: r ? r.lineNumberB : -1
      });
    }
    this.added = result.stats.addedCount; this.deleted = result.stats.deletedCount;
    this.modified = result.stats.modifiedCount; this.similarity = result.stats.similarityPercent;
    this.blockCnt = result.stats.diffBlockCount; this.hasResult = true;
    this.collapsedGaps = new Set(); this.buildDisplayItems();
    this.diffBlocks = DiffBlockLocator.locateBlocks(result.unifiedLines);
    this.navIdx = 0; this.searchMatches = []; this.searchIdx = 0;
  }

  // ===================== 编辑 =====================
  private startEdit(lineIdx: number): void {
    if (this.editingIndex >= 0 && this.editingIndex !== lineIdx) this.commitEdit(this.editBuffer);
    if (lineIdx < 0 || lineIdx >= this.lineContents.length) return;
    this.editingIndex = lineIdx; this.editBuffer = this.lineContents[lineIdx];
  }

  private commitEdit(value: string): void {
    if (this.editingIndex < 0 || value === this.lineContents[this.editingIndex]) { this.editingIndex = -1; return; }
    this.lineContents[this.editingIndex] = value;
    const arrA: string[] = [], arrB: string[] = [];
    for (let i = 0; i < this.lineTypes.length; i++) {
      if (this.lineTypes[i] === 0) { arrA.push(this.lineContents[i]); arrB.push(this.lineContents[i]); }
      else if (this.lineTypes[i] === 1) arrB.push(this.lineContents[i]);
      else if (this.lineTypes[i] === 2) arrA.push(this.lineContents[i]);
      else if (this.lineTypes[i] === 3) { arrA.push(this.lineContents[i]); arrB.push(this.lineContents[i]); }
    }
    const tab = this.tabs[this.activeIdx];
    if (tab) { tab.textA = arrA.join('\n'); tab.textB = arrB.join('\n'); }
    this.editingIndex = -1;
    this.doDiffInternal(tab ? tab.textA : '', tab ? tab.textB : '');
  }

  // ===================== 最近文件 =====================
  private loadRecentFiles(): void {
    try { this.recentFiles = JSON.parse(this.recentFilesRaw); } catch (_e) { this.recentFiles = []; }
  }

  private saveRecent(name: string, path: string): void {
    const existing = this.recentFiles.findIndex(f => f.path === path);
    if (existing >= 0) this.recentFiles.splice(existing, 1);
    this.recentFiles.unshift({ name, path, timestamp: Date.now() });
    if (this.recentFiles.length > 20) this.recentFiles.splice(20);
    this.recentFilesRaw = JSON.stringify(this.recentFiles);
  }

  private clearRecent(): void { this.recentFiles = []; this.recentFilesRaw = '[]'; }

  private openRecent(rf: RecentFile): void {
    try { this.tabs[this.activeIdx].textA = FileContentService.readFileContent(rf.path).content; this.doTabLabel(); } catch (_e) {}
  }

  private formatTime(ts: number): string { return new Date(ts).toLocaleDateString(); }

  // ===================== 文件操作 =====================
  private pickFileA(): void {
    try {
      let ctx = getContext(this);
      new picker.DocumentViewPicker(ctx).select({ maxSelectNumber: 1 } as picker.DocumentSelectOptions)
        .then((uris: string[]) => {
          if (uris.length > 0) {
            const name = FileContentService.extractFileName(uris[0]);
            this.tabs[this.activeIdx].textA = FileContentService.readFileContent(uris[0]).content;
            this.tabs[this.activeIdx].fileAName = name;
            this.doTabLabel();
            this.saveRecent(name, uris[0]);
          }
        });
    } catch (_e) {}
  }

  private pickFileB(): void {
    try {
      let ctx = getContext(this);
      new picker.DocumentViewPicker(ctx).select({ maxSelectNumber: 1 } as picker.DocumentSelectOptions)
        .then((uris: string[]) => {
          if (uris.length > 0) {
            const name = FileContentService.extractFileName(uris[0]);
            this.tabs[this.activeIdx].textB = FileContentService.readFileContent(uris[0]).content;
            this.tabs[this.activeIdx].fileBName = name;
            this.doTabLabel();
            this.saveRecent(name, uris[0]);
          }
        });
    } catch (_e) {}
  }

  private doTabLabel(): void {
    const tab = this.tabs[this.activeIdx];
    if (tab.fileAName && tab.fileBName) tab.label = `${tab.fileAName} ↔ ${tab.fileBName}`;
    else if (tab.fileAName) tab.label = tab.fileAName;
    else if (tab.fileBName) tab.label = tab.fileBName;
  }

  // ===================== 搜索 =====================
  private doSearch(): void {
    if (this.searchKeyword.length === 0) { this.searchMatches = []; return; }
    const kw = this.searchKeyword.toLowerCase(); this.searchMatches = [];
    for (let i = 0; i < this.lineContents.length; i++) {
      if (this.lineContents[i].toLowerCase().includes(kw)) this.searchMatches.push(i);
    }
    this.searchIdx = 0;
  }

  // ===================== 导出 =====================
  private exportDiff(): void {
    const lines: string[] = [
      `--- A/${this.tabs[this.activeIdx]?.fileAName || 'fileA'}`,
      `+++ B/${this.tabs[this.activeIdx]?.fileBName || 'fileB'}`,
      `@@ +${this.added} -${this.deleted} ~${this.modified} ${this.similarity}% @@`
    ];
    for (let i = 0; i < this.lineTypes.length; i++) {
      let pf = ' ';
      if (this.lineTypes[i] === 1) pf = '+'; else if (this.lineTypes[i] === 2) pf = '-'; else if (this.lineTypes[i] === 3) pf = '~';
      lines.push(`${pf} ${this.lineContents[i]}`);
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, lines.join('\n'));
    pasteboard.getSystemPasteboard().setPasteData(data);
    AlertDialog.show({ title: '已复制', message: `${this.blockCnt}个差异块 → 剪贴板`, autoCancel: true });
  }

  // ===================== 显示辅助 =====================
  private isLineInCurrentBlock(idx: number): boolean {
    if (this.diffBlocks.length === 0 || this.navIdx < 0 || this.navIdx >= this.diffBlocks.length) return false;
    const b = this.diffBlocks[this.navIdx];
    return idx >= b.startIndex && idx < b.startIndex + b.length;
  }

  private scrollToBlock(idx: number): void {
    if (idx < 0 || idx >= this.diffBlocks.length) return;
    this.scroller.scrollToIndex(this.diffBlocks[idx].startIndex, true);
    this.navIdx = idx;
  }

  private buildDisplayItems(): void {
    const GAP_MIN = 8; this.displayItems = [];
    let i = 0;
    while (i < this.lineTypes.length) {
      if (this.lineTypes[i] === 0) {
        let rs = i; while (i < this.lineTypes.length && this.lineTypes[i] === 0) i++;
        let rl = i - rs;
        if (rl > GAP_MIN && !this.collapsedGaps.has(rs)) {
          for (let j = 0; j < 3 && rs + j < rs + rl; j++) this.displayItems.push({ kind: 0, lineIdx: rs + j, gapCount: 0 });
          this.displayItems.push({ kind: 1, lineIdx: rs + 3, gapCount: rl - 6 });
          for (let j = rl - 3; j < rl; j++) if (rs + j >= rs + 3) this.displayItems.push({ kind: 0, lineIdx: rs + j, gapCount: 0 });
        } else {
          for (let j = rs; j < i; j++) this.displayItems.push({ kind: 0, lineIdx: j, gapCount: 0 });
        }
      } else { this.displayItems.push({ kind: 0, lineIdx: i, gapCount: 0 }); i++; }
    }
  }

  // ===================== Builders =====================
  @Builder unifiedRow(item: DisplayItem, idx: number) {
    if (item.kind === 1) {
      Row() {
        Text(`⋮ ${item.gapCount} 行未变更 ⋮`).fontSize(11).fontColor('#999').fontFamily('monospace')
      }.width('100%').height(22).justifyContent(FlexAlign.Center).backgroundColor('#F0F0F0')
      .onClick(() => { this.collapsedGaps.has(item.lineIdx) ? this.collapsedGaps.delete(item.lineIdx) : this.collapsedGaps.add(item.lineIdx); this.buildDisplayItems(); })
    } else {
      UnifiedLine({
        typeNum: this.lineTypes[item.lineIdx], content: this.lineContents[item.lineIdx],
        linenoA: this.lineNosA[item.lineIdx], linenoB: this.lineNosB[item.lineIdx],
        isMonokai: this.colorMode === 'monokai',
        isHighlighted: this.isLineInCurrentBlock(item.lineIdx),
        charSegments: this.charSegs[item.lineIdx],
        isEditing: this.editingIndex === item.lineIdx,
        editBuffer: $editBuffer,
        onLineClick: () => { this.startEdit(item.lineIdx); },
        onEditSubmit: (v: string) => { this.commitEdit(v); }
      })
    }
  }

  @Builder sbsRow(p: SbsPair, i: number) {
    Row() {
      Row() {
        Text(p.leftLineNo > 0 ? `${p.leftLineNo}` : '').fontSize(10).fontColor('#999').width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(p.leftContent).fontSize(11).fontFamily('monospace').fontColor(this.colorMode === 'monokai' ? '#F8F8F2' : '#1C1C1C')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 4 }).layoutWeight(1)
      }.width('48%').height(22).backgroundColor(this.sbsBg(p.leftType))
      Column() {}.width('4%')
      Row() {
        Text(p.rightLineNo > 0 ? `${p.rightLineNo}` : '').fontSize(10).fontColor('#999').width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(p.rightContent).fontSize(11).fontFamily('monospace').fontColor(this.colorMode === 'monokai' ? '#F8F8F2' : '#1C1C1C')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 4 }).layoutWeight(1)
      }.width('48%').height(22).backgroundColor(this.sbsBg(p.rightType))
    }.width('100%').height(22)
  }

  private sbsBg(t: number): string {
    if (this.colorMode === 'monokai') { if (t === 1) return '#232D1A'; if (t === 2) return '#351B1B'; if (t === 3) return '#33301A'; return '#272822'; }
    if (t === 1) return '#E6FFEC'; if (t === 2) return '#FFEBE9'; if (t === 3) return '#FFF3D4'; return '#FFF';
  }
}
