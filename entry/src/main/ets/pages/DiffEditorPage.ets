import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import pasteboard from '@ohos.pasteboard';
import { DiffBlockLocator, DiffBlock } from '../engine/DiffBlockLocator';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffToolbar } from '../components/DiffToolbar';
import { InputPanel } from '../components/InputPanel';
import { DiffOverviewBar } from '../components/DiffOverviewBar';
import { SampleDataProvider } from '../utils/SampleDataProvider';
import { FileUtils } from '../utils/FileUtils';
import { ViewMode, DiffOptions, CharSegment } from '../model/DiffModels';
import { DiffEngine } from '../engine/DiffEngine';
import { TokenType, TokenHighlighter, Token } from '../engine/TokenHighlighter';

@Component
struct UnifiedLine {
  @Prop typeNum: number = 0;
  @Prop content: string = '';
  @Prop linenoA: number = -1;
  @Prop linenoB: number = -1;
  @Prop searchKeyword: string = '';
  @Prop isSearchMatch: boolean = false;
  @Prop isMonokai: boolean = false;
  @Prop isHighlighted: boolean = false;
  @Prop charSegments: CharSegment[] = [];
  @Prop isEditing: boolean = false;
  @Link editBuffer: string;
  onLineClick?: () => void;
  onEditSubmit?: (value: string) => void;
  onEditCancel?: () => void;

  build() {
    Row() {
      Text(this.linenoA > 0 ? `${this.linenoA}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.linenoB > 0 ? `${this.linenoB}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.getPrefix()).fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.getPColor()).width(14).textAlign(TextAlign.Center)
      if (this.isEditing) {
        TextInput({ text: this.editBuffer })
          .fontSize(12).fontFamily('monospace').fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C')
          .backgroundColor(Color.Transparent).height(22).layoutWeight(1)
          .padding({ left: 6, right: 6 }).border({ width: 1, color: '#007AFF', style: BorderStyle.Dashed })
          .onChange((v: string) => { this.editBuffer = v; })
          .onSubmit((_: EnterKeyType) => { if (this.onEditSubmit) this.onEditSubmit(this.editBuffer); })
      } else {
        this.contentText()
      }
    }.width('100%').height(22).backgroundColor(this.getBg())
    .onClick(() => { if (!this.isEditing && this.onLineClick) this.onLineClick(); })
  }
  @Builder
  contentText() {
    if (this.charSegments.length > 0 && this.typeNum === 3) {
      Text() {
        ForEach(this.charSegments, (seg: CharSegment, idx: number) => {
          Span(this.content.substring(seg.start, seg.end))
            .fontSize(12).fontFamily('monospace')
            .fontColor(seg.type === 1 ? (this.isMonokai ? '#A6E22E' : '#1A7F37') :
              (this.isMonokai ? '#F8F8F2' : '#1C1C1C'))
        }, (seg: CharSegment, idx: number) => `seg_${idx}`)
      }
      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 6 })
    } else {
      this.syntaxText()
    }
  }

  @Builder
  syntaxText() {
    Text() {
      ForEach(TokenHighlighter.tokenize(this.content), (tok: Token, _idx: number) => {
        Span(this.content.substring(tok.start, tok.end))
          .fontSize(12).fontFamily('monospace')
          .fontColor(TokenHighlighter.getTokenColor(tok.type, this.isMonokai))
      }, (tok: Token, _idx: number) => `tk_${_idx}`)
    }
    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 6 })
  }
  private getPrefix(): string { if (this.typeNum === 1) return '+'; if (this.typeNum === 2) return '-'; if (this.typeNum === 3) return '~'; return ' '; }
  private getPColor(): string {
    if (this.isMonokai) { if (this.typeNum === 1) return '#A6E22E'; if (this.typeNum === 2) return '#F92672'; if (this.typeNum === 3) return '#E6DB74'; return '#75715E'; }
    if (this.typeNum === 1) return '#1A7F37'; if (this.typeNum === 2) return '#BE2E2E'; if (this.typeNum === 3) return '#D4A017'; return '#CCCCCC';
  }
  private getBg(): string {
    if (this.isEditing) return this.isMonokai ? '#2A2A40' : '#E3F2FD';
    if (this.isSearchMatch) return this.isMonokai ? '#49483E' : '#FFD54F';
    if (this.isHighlighted) return this.isMonokai ? '#3A3A2A' : '#FFF9C4';
    if (this.isMonokai) { if (this.typeNum === 1) return '#232D1A'; if (this.typeNum === 2) return '#351B1B'; if (this.typeNum === 3) return '#33301A'; return '#272822'; }
    if (this.typeNum === 1) return '#E6FFEC'; if (this.typeNum === 2) return '#FFEBE9'; if (this.typeNum === 3) return '#FFF3D4'; return '#FFFFFF';
  }
}

@Component
struct SideBySideRow {
  @Prop leftType: number = 0; @Prop leftContent: string = ''; @Prop leftLineNo: number = -1;
  @Prop rightType: number = 0; @Prop rightContent: string = ''; @Prop rightLineNo: number = -1;
  @Prop isSearchMatch: boolean = false; @Prop isMonokai: boolean = false;
  @Prop isHighlighted: boolean = false;
  onSyncToRight?: () => void;
  onSyncToLeft?: () => void;
  build() {
    Row() {
      Row() {
        Text(this.leftLineNo > 0 ? `${this.leftLineNo}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(this.leftContent).fontSize(11).fontFamily('monospace').fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 4, right: 4 }).layoutWeight(1)
      }.width('46%').height(22).backgroundColor(this.getBg(this.leftType)).padding({ right: 1 })

      Column() {
        if (this.leftType !== 0 || this.rightType !== 0) {
          if (this.leftType === 2) {
            Button({ type: ButtonType.Circle }) { Text('→').fontSize(10).fontColor(this.isMonokai ? '#A6E22E' : '#1A7F37') }
            .width(22).height(20).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.onSyncToRight) this.onSyncToRight(); })
          }
          if (this.rightType === 1) {
            Button({ type: ButtonType.Circle }) { Text('←').fontSize(10).fontColor(this.isMonokai ? '#F92672' : '#BE2E2E') }
            .width(22).height(20).backgroundColor(Color.Transparent)
            .onClick(() => { if (this.onSyncToLeft) this.onSyncToLeft(); })
          }
        }
      }.width(26).justifyContent(FlexAlign.Center)

      Row() {
        Text(this.rightLineNo > 0 ? `${this.rightLineNo}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(this.rightContent).fontSize(11).fontFamily('monospace').fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 4, right: 4 }).layoutWeight(1)
      }.width('46%').height(22).backgroundColor(this.getBg(this.rightType)).padding({ left: 1 })
    }.width('100%').height(22)
  }
  private getBg(type: number): string {
    if (this.isSearchMatch) return this.isMonokai ? '#49483E' : '#FFD54F';
    if (this.isHighlighted) return this.isMonokai ? '#3A3A2A' : '#FFF9C4';
    if (this.isMonokai) { if (type === 1) return '#232D1A'; if (type === 2) return '#351B1B'; if (type === 3) return '#33301A'; return '#272822'; }
    if (type === 1) return '#E6FFEC'; if (type === 2) return '#FFEBE9'; if (type === 3) return '#FFF3D4'; return '#FFFFFF';
  }
}

interface SbsPair { leftType: number; leftContent: string; leftLineNo: number; rightType: number; rightContent: string; rightLineNo: number; }
interface DisplayItem { kind: number; lineIdx: number; gapCount: number; } // kind:0=line, 1=gap

@Entry
@Component
struct DiffEditorPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @StorageLink('ignoreBlankLines') ignoreBlankLines: boolean = false;
  @State textA: string = ''; @State textB: string = '';
  @State viewMode: ViewMode = ViewMode.UNIFIED;
  @State inputVisible: boolean = true; @State navIdx: number = 0;
  @State added: number = 0; @State deleted: number = 0; @State modified: number = 0;
  @State similarity: number = 0; @State blockCnt: number = 0; @State hasResult: boolean = false;
  @State lineTypes: number[] = []; @State lineContents: string[] = [];
  @State lineNosA: number[] = []; @State lineNosB: number[] = [];
  @State sbsPairs: SbsPair[] = [];
  @State charSegs: CharSegment[][] = [];
  @State searchActive: boolean = false; @State searchKeyword: string = '';
  @State searchMatches: number[] = []; @State searchIdx: number = 0;
  @State fileAName: string = ''; @State fileBName: string = '';
  @State collapsedGaps: Set<number> = new Set();
  @State displayItems: DisplayItem[] = [];
  @State editingIndex: number = -1;
  @State editBuffer: string = '';
  private diffBlocks: DiffBlock[] = [];
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 如果从目录对比页面跳转过来，使用传递的文件内容
    let fromDirA = AppStorage.get<string>('dirDiffContentA');
    let fromDirB = AppStorage.get<string>('dirDiffContentB');
    if (fromDirA !== undefined && fromDirA !== null && fromDirB !== undefined && fromDirB !== null) {
      this.textA = fromDirA;
      this.textB = fromDirB;
      this.fileAName = AppStorage.get<string>('dirDiffNameA') || '文件A';
      this.fileBName = AppStorage.get<string>('dirDiffNameB') || '文件B';
      AppStorage.delete('dirDiffContentA');
      AppStorage.delete('dirDiffContentB');
      AppStorage.delete('dirDiffNameA');
      AppStorage.delete('dirDiffNameB');
      this.doDiff();
    } else {
      this.textA = SampleDataProvider.getSampleA();
      this.textB = SampleDataProvider.getSampleB();
    }
  }

  build() {
    Column() {
      DiffToolbar({
        viewMode: this.viewMode, isComputing: false, searchActive: false,
        onRunDiff: () => { this.doDiff(); },
        onSwitchView: (m: ViewMode) => { this.viewMode = m; },
        onPasteSample: () => { this.doPaste(); },
        onOpenSettings: () => { router.pushUrl({ url: 'pages/SettingsPage' }); },
        onToggleSearch: () => { this.searchActive = !this.searchActive; this.searchKeyword = ''; this.searchMatches = []; },
        onOpenMerge: () => { router.pushUrl({ url: 'pages/MergePage' }); },
        onExport: () => { this.exportDiff(); }
      }).width('100%').height(44)
      Divider().height(1).color('#E0E0E0')

      Row() {
        Button('📂 选择文件A').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(10).padding({ left: 8, right: 8 })
          .onClick(() => { this.pickFileA(); })
        Button('📄 选择文件B').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
          .onClick(() => { this.pickFileB(); })
        Button('📁 对比').fontSize(11).height(28).type(ButtonType.Capsule)
          .backgroundColor('#E3F2FD').fontColor('#1565C0').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
          .onClick(() => { router.pushUrl({ url: 'pages/DirectoryDiffPage' }); })
        if (this.fileAName !== '' || this.fileBName !== '') {
          Text(this.fileAName !== '' ? `A:${this.fileAName}` : '')
            .fontSize(10).fontColor('#1A7F37').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ left: 6 })
          Text(this.fileBName !== '' ? `B:${this.fileBName}` : '')
            .fontSize(10).fontColor('#BE2E2E').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1).margin({ left: 6 })
        } else {
          Blank().layoutWeight(1)
        }
      }
      .width('100%').height(36).padding({ left: 8, right: 8 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })

      if (this.searchActive && this.hasResult) {
        Row() {
          Button({ type: ButtonType.Circle }) { Text('×').fontSize(14).fontColor('#666666') }
          .width(28).height(28).backgroundColor(Color.Transparent)
          .onClick(() => { this.searchActive = false; this.searchKeyword = ''; })
          TextInput({ text: this.searchKeyword, placeholder: '搜索...' })
            .fontSize(12).height(28).layoutWeight(1)
            .backgroundColor('#FFFFFF').borderRadius(6).padding({ left: 6, right: 6 })
            .onChange((v: string) => { this.searchKeyword = v; this.doSearch(); })
          Button({ type: ButtonType.Circle }) { Text('▲').fontSize(12).fontColor('#666666') }
          .width(24).height(24).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.searchMatches.length > 0) { this.searchIdx = (this.searchIdx - 1 + this.searchMatches.length) % this.searchMatches.length; } })
          Button({ type: ButtonType.Circle }) { Text('▼').fontSize(12).fontColor('#666666') }
          .width(24).height(24).backgroundColor(Color.Transparent)
          .onClick(() => { if (this.searchMatches.length > 0) { this.searchIdx = (this.searchIdx + 1) % this.searchMatches.length; } })
          if (this.searchMatches.length > 0) {
            Text(`${this.searchIdx + 1}/${this.searchMatches.length}`).fontSize(11).fontColor('#999999')
          }
        }
        .width('100%').height(36).padding({ left: 4, right: 4 })
        .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })
      }

      if (this.hasResult) {
        Row() {
          Text(`+${this.added}`).fontSize(11).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
          Text(` -${this.deleted}`).fontSize(11).fontColor('#BE2E2E').fontWeight(FontWeight.Medium).margin({ left: 8, right: 8 })
          Text(` ~${this.modified}`).fontSize(11).fontColor('#D4A017').fontWeight(FontWeight.Medium)
          Text(`  ${this.similarity}%`).fontSize(11).fontColor('#999999').layoutWeight(1)
          Text(`${this.blockCnt}块`).fontSize(11).fontColor('#999999')
        }.width('100%').height(30).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })
      }
      if (this.isLargeScreen()) {
        Row() {
          if (this.inputVisible) {
            InputPanel({ textA: $textA, textB: $textB }).width('42%').height('100%')
          }
          if (this.hasResult) {
            Row() {
              Scroll() {
                if (this.viewMode === ViewMode.UNIFIED) {
                  Column() {
                    ForEach(this.displayItems, (item: DisplayItem, idx: number) => {
                      this.unifiedRow(item, idx)
                    }, (item: DisplayItem, idx: number) => `ud_${idx}`)
                  }
                } else {
                  Column() {
                    ForEach(this.sbsPairs, (p: SbsPair, i: number) => {
                      SideBySideRow({
                        leftType: p.leftType, leftContent: p.leftContent, leftLineNo: p.leftLineNo,
                        rightType: p.rightType, rightContent: p.rightContent, rightLineNo: p.rightLineNo,
                        isMonokai: this.colorMode === 'monokai',
                        isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === i,
                        isHighlighted: this.isLineInCurrentBlock(i),
                        onSyncToRight: () => { this.syncToRight(p); },
                        onSyncToLeft: () => { this.syncToLeft(p); }
                      })
                    }, (p: SbsPair, i: number) => `s_${i}`)
                  }
                }
              }.layoutWeight(1).height('100%').scrollBar(BarState.Auto)

              if (this.diffBlocks.length > 0) {
                DiffOverviewBar({
                  blocks: this.diffBlocks, totalLines: this.lineTypes.length,
                  isMonokai: this.colorMode === 'monokai', activeIdx: this.navIdx,
                  onJumpToBlock: (idx: number) => { this.navIdx = idx; this.scrollToBlock(idx); }
                }).width(10).height('100%')
              }
            }.width(this.inputVisible ? '58%' : '100%').height('100%')
          } else {
            Column() {
              Text('AegisDiff').fontSize(22).fontColor(this.colorMode === 'monokai' ? '#F8F8F2' : '#333333')
              Text('点击执行对比查看差异').fontSize(13).fontColor('#999999').margin({ top: 8 })
            }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          }
        }.width('100%').layoutWeight(1)
      } else {
        if (this.inputVisible) { InputPanel({ textA: $textA, textB: $textB }).width('100%').height(140) }
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
                    SideBySideRow({
                      leftType: p.leftType, leftContent: p.leftContent, leftLineNo: p.leftLineNo,
                      rightType: p.rightType, rightContent: p.rightContent, rightLineNo: p.rightLineNo,
                      isMonokai: this.colorMode === 'monokai',
                      isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === i,
                      isHighlighted: this.isLineInCurrentBlock(i),
                      onSyncToRight: () => { this.syncToRight(p); },
                      onSyncToLeft: () => { this.syncToLeft(p); }
                    })
                  }, (p: SbsPair, i: number) => `s_${i}`)
                }
              }
            }.layoutWeight(1).height('100%').scrollBar(BarState.Auto)

            if (this.diffBlocks.length > 0) {
              DiffOverviewBar({
                blocks: this.diffBlocks, totalLines: this.lineTypes.length,
                isMonokai: this.colorMode === 'monokai', activeIdx: this.navIdx,
                onJumpToBlock: (idx: number) => { this.navIdx = idx; this.scrollToBlock(idx); }
              }).width(10).height('100%')
            }
          }.width('100%').layoutWeight(1)
        } else {
          Column() {
            Text('AegisDiff').fontSize(22).fontColor(this.colorMode === 'monokai' ? '#F8F8F2' : '#333333')
            Text('点击执行对比查看差异').fontSize(13).fontColor('#999999').margin({ top: 8 })
          }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }
      Divider().height(1).color('#E0E0E0')
      DiffNavigator({
        totalBlocks: this.blockCnt, currentIndex: this.navIdx, inputPanelVisible: this.inputVisible,
        onNavigateTo: (i: number) => { this.navIdx = i; },
        onToggleInput: () => { this.inputVisible = !this.inputVisible; }
      }).width('100%').height(40)
    }.width('100%').height('100%').backgroundColor(this.colorMode === 'monokai' ? '#1E1F1C' : '#F5F5F5')
  }

  private isLargeScreen(): boolean { return this.currentBp === 'lg' || this.currentBp === 'md'; }

  /**
   * 核心 Diff 计算 — 使用 Myers/LCS 引擎
   */
  private doDiff(): void {
    if (this.textA.length === 0 && this.textB.length === 0) {
      return;
    }

    const options: DiffOptions = {
      ignoreBlankLines: this.ignoreBlankLines,
      enableCharDiff: true
    };

    const result = DiffEngine.computeDiff(this.textA, this.textB, options);

    // 构建 Unified 视图并行数组
    this.lineTypes = [];
    this.lineContents = [];
    this.lineNosA = [];
    this.lineNosB = [];
    this.charSegs = [];
    for (const line of result.unifiedLines) {
      this.lineTypes.push(line.type);
      this.lineContents.push(line.content);
      this.lineNosA.push(line.lineNumberA);
      this.lineNosB.push(line.lineNumberB);
      this.charSegs.push(line.charSegments);
    }

    // 构建 Side-by-Side 配对
    this.sbsPairs = [];
    const len = Math.max(result.leftLines.length, result.rightLines.length);
    for (let i = 0; i < len; i++) {
      const left = result.leftLines[i];
      const right = result.rightLines[i];
      this.sbsPairs.push({
        leftType: left ? left.type : 0,
        leftContent: left ? left.content : '',
        leftLineNo: left ? left.lineNumberA : -1,
        rightType: right ? right.type : 0,
        rightContent: right ? right.content : '',
        rightLineNo: right ? right.lineNumberB : -1
      } as SbsPair);
    }

    // 统计
    this.added = result.stats.addedCount;
    this.deleted = result.stats.deletedCount;
    this.modified = result.stats.modifiedCount;
    this.similarity = result.stats.similarityPercent;
    this.blockCnt = result.stats.diffBlockCount;
    this.hasResult = true;

    // 构建折叠显示列表
    this.collapsedGaps = new Set();
    this.buildDisplayItems();

    // 定位差异块，用于导航
    this.diffBlocks = DiffBlockLocator.locateBlocks(result.unifiedLines);
    this.navIdx = 0;
    this.searchMatches = [];
    this.searchIdx = 0;
  }

  /**
   * 判断行是否在当前导航块内
   */
  private isLineInCurrentBlock(lineIndex: number): boolean {
    if (this.diffBlocks.length === 0 || this.navIdx < 0 || this.navIdx >= this.diffBlocks.length) {
      return false;
    }
    const block = this.diffBlocks[this.navIdx];
    return lineIndex >= block.startIndex && lineIndex < block.startIndex + block.length;
  }

  private scrollToBlock(blockIdx: number): void {
    if (blockIdx < 0 || blockIdx >= this.diffBlocks.length) return;
    const block = this.diffBlocks[blockIdx];
    this.scroller.scrollToIndex(block.startIndex, true);
    this.navIdx = blockIdx;
  }

  private doSearch(): void {
    if (this.searchKeyword.length === 0) { this.searchMatches = []; return; }
    const kw = this.searchKeyword.toLowerCase();
    this.searchMatches = [];
    for (let i = 0; i < this.lineContents.length; i++) {
      if (this.lineContents[i].toLowerCase().includes(kw)) this.searchMatches.push(i);
    }
    this.searchIdx = 0;
  }

  /**
   * 构建 Unified 视图显示列表，将 >8 行的连续 UNCHANGED 区域折叠为 gap
   */
  private buildDisplayItems(): void {
    const GAP_MIN = 8;
    this.displayItems = [];
    let i = 0;
    while (i < this.lineTypes.length) {
      if (this.lineTypes[i] === 0) {
        // 统计连续 UNCHANGED 行数
        let runStart = i;
        while (i < this.lineTypes.length && this.lineTypes[i] === 0) i++;
        let runLen = i - runStart;
        if (runLen > GAP_MIN && !this.collapsedGaps.has(runStart)) {
          // 折叠：显示前后各 3 行 + gap
          for (let j = 0; j < 3 && runStart + j < runStart + runLen; j++) {
            let item: DisplayItem = { kind: 0, lineIdx: runStart + j, gapCount: 0 };
            this.displayItems.push(item);
          }
          let gapItem: DisplayItem = { kind: 1, lineIdx: runStart + 3, gapCount: runLen - 6 };
          this.displayItems.push(gapItem);
          for (let j = runLen - 3; j < runLen; j++) {
            if (runStart + j >= runStart + 3) {
              let item: DisplayItem = { kind: 0, lineIdx: runStart + j, gapCount: 0 };
              this.displayItems.push(item);
            }
          }
        } else {
          for (let j = runStart; j < i; j++) {
            let item: DisplayItem = { kind: 0, lineIdx: j, gapCount: 0 };
            this.displayItems.push(item);
          }
        }
      } else {
        let item: DisplayItem = { kind: 0, lineIdx: i, gapCount: 0 };
        this.displayItems.push(item);
        i++;
      }
    }
  }

  @Builder
  unifiedRow(item: DisplayItem, idx: number) {
    if (item.kind === 1) {
      this.gapRow(item.lineIdx, item.gapCount)
    } else {
      UnifiedLine({ typeNum: this.lineTypes[item.lineIdx], content: this.lineContents[item.lineIdx],
        linenoA: this.lineNosA[item.lineIdx], linenoB: this.lineNosB[item.lineIdx],
        searchKeyword: this.searchKeyword, isMonokai: this.colorMode === 'monokai',
        isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === item.lineIdx,
        isHighlighted: this.isLineInCurrentBlock(item.lineIdx),
        charSegments: this.charSegs[item.lineIdx],
        isEditing: this.editingIndex === item.lineIdx,
        editBuffer: $editBuffer,
        onLineClick: () => { this.startEdit(item.lineIdx); },
        onEditSubmit: (v: string) => { this.commitEdit(v); },
        onEditCancel: () => { this.cancelEdit(); }
      })
    }
  }

  @Builder
  gapRow(startIdx: number, count: number) {
    Row() {
      Text(`⋮ ${count} 行未变更 ⋮`)
        .fontSize(11).fontColor('#999999').fontFamily('monospace')
    }
    .width('100%').height(22)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F0F0F0')
    .onClick(() => {
      if (this.collapsedGaps.has(startIdx)) {
        this.collapsedGaps.delete(startIdx);
      } else {
        this.collapsedGaps.add(startIdx);
      }
      this.buildDisplayItems();
    })
  }

  private syncToRight(p: SbsPair): void {
    let arrA = this.textA.split('\n');
    let arrB = this.textB.split('\n');
    if (p.leftLineNo > 0 && p.leftLineNo <= arrA.length) {
      if (p.rightLineNo > 0 && p.rightLineNo <= arrB.length) {
        arrB[p.rightLineNo - 1] = arrA[p.leftLineNo - 1];
      } else {
        arrB.splice(Math.max(0, p.leftLineNo - 1), 0, arrA[p.leftLineNo - 1]);
      }
      this.textB = arrB.join('\n');
      this.doDiff();
    }
  }

  private syncToLeft(p: SbsPair): void {
    let arrA = this.textA.split('\n');
    let arrB = this.textB.split('\n');
    if (p.rightLineNo > 0 && p.rightLineNo <= arrB.length) {
      if (p.leftLineNo > 0 && p.leftLineNo <= arrA.length) {
        arrA[p.leftLineNo - 1] = arrB[p.rightLineNo - 1];
      } else {
        arrA.splice(Math.max(0, p.rightLineNo - 1), 0, arrB[p.rightLineNo - 1]);
      }
      this.textA = arrA.join('\n');
      this.doDiff();
    }
  }

  private doPaste(): void { this.textA = SampleDataProvider.getSampleA(); this.textB = SampleDataProvider.getSampleB(); this.fileAName = ''; this.fileBName = ''; }

  // ===================== 视图内编辑 =====================

  /** 进入编辑模式 */
  private startEdit(lineIdx: number): void {
    // 如果之前有一行在编辑，先提交
    if (this.editingIndex >= 0 && this.editingIndex !== lineIdx) {
      this.commitEdit(this.editBuffer);
    }
    if (lineIdx < 0 || lineIdx >= this.lineContents.length) return;
    this.editingIndex = lineIdx;
    this.editBuffer = this.lineContents[lineIdx];
  }

  /** 提交编辑内容并重新计算 diff */
  private commitEdit(value: string): void {
    if (this.editingIndex < 0) return;
    if (value === this.lineContents[this.editingIndex]) {
      this.editingIndex = -1;
      return;
    }
    this.lineContents[this.editingIndex] = value;

    // 从 Unified 行重建 textA 和 textB
    const arrA: string[] = [];
    const arrB: string[] = [];
    for (let i = 0; i < this.lineTypes.length; i++) {
      const typ = this.lineTypes[i];
      const cnt = this.lineContents[i];
      if (typ === 0) { arrA.push(cnt); arrB.push(cnt); }
      else if (typ === 1) { arrB.push(cnt); }
      else if (typ === 2) { arrA.push(cnt); }
      else if (typ === 3) { arrA.push(cnt); arrB.push(cnt); }
    }
    this.textA = arrA.join('\n');
    this.textB = arrB.join('\n');

    this.editingIndex = -1;
    this.doDiff();
  }

  /** 取消编辑 */
  private cancelEdit(): void {
    this.editingIndex = -1;
    this.editBuffer = '';
  }

  private exportDiff(): void {
    const lines: string[] = [];
    lines.push(`--- A/${this.fileAName || 'fileA'}`);
    lines.push(`+++ B/${this.fileBName || 'fileB'}`);
    lines.push(`@@ +${this.added} -${this.deleted} ~${this.modified} ${this.similarity}% @@`);
    for (let i = 0; i < this.lineTypes.length; i++) {
      let prefix = ' ';
      if (this.lineTypes[i] === 1) prefix = '+';
      else if (this.lineTypes[i] === 2) prefix = '-';
      else if (this.lineTypes[i] === 3) prefix = '~';
      lines.push(`${prefix} ${this.lineContents[i]}`);
    }
    const text = lines.join('\n');
    try {
      const pb = pasteboard.getSystemPasteboard();
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pb.setPasteData(data, () => {
        AlertDialog.show({ title: '导出成功', message: `${this.blockCnt}个差异块 → 已复制到剪贴板`, autoCancel: true });
      });
    } catch (_e) {
      AlertDialog.show({ title: '导出Diff', message: `${this.blockCnt}个差异块，${text.length}字符`, autoCancel: true });
    }
  }

  private pickFileA(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          this.fileAName = FileUtils.getFileName(uris[0]);
          this.textA = FileUtils.readFile(uris[0]);
        }
      });
    } catch (e) { /* ignore */ }
  }

  private pickFileB(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          this.fileBName = FileUtils.getFileName(uris[0]);
          this.textB = FileUtils.readFile(uris[0]);
        }
      });
    } catch (e) { /* ignore */ }
  }
}
