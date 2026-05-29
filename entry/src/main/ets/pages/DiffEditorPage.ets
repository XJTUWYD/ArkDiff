/**
 * AegisDiff — DiffEditorPage（编排层）
 *
 * 职责：页面布局编排，将渲染委托给各子组件。
 * 业务逻辑：DiffSessionViewModel
 * 行渲染：UnifiedLineRenderer / SideBySideRenderer
 * 搜索 UI：DiffSearchBar
 * 文件读取：FileContentService
 */
import { router } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { DiffBlockLocator, DiffBlock } from '../engine/DiffBlockLocator';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffToolbar } from '../components/DiffToolbar';
import { InputPanel } from '../components/InputPanel';
import { DiffOverviewBar } from '../components/DiffOverviewBar';
import { UnifiedLineRenderer } from '../components/UnifiedLineRenderer';
import { SideBySideRenderer } from '../components/SideBySideRenderer';
import { DiffSearchBar } from '../components/DiffSearchBar';
import { SampleDataProvider } from '../utils/SampleDataProvider';
import { DiffSessionViewModel } from '../viewmodel/DiffSessionViewModel';
import { FileContentService } from '../services/FileContentService';
import { ViewMode, DiffOptions } from '../model/DiffModels';
import {
  ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors,
  ButtonColorMap, getLightButtonColors, getDarkButtonColors
} from '../utils/ThemeTokens';

interface SbsPair {
  leftType: number;
  leftContent: string;
  leftLineNo: number;
  rightType: number;
  rightContent: string;
  rightLineNo: number;
}

interface DisplayItem {
  kind: number;
  lineIdx: number;
  gapCount: number;
} // kind:0=line, 1=gap

@Entry
@Component
struct DiffEditorPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @StorageLink('ignoreBlankLines') ignoreBlankLines: boolean = false;
  @State inputVisible: boolean = true;
  @State navIdx: number = 0;
  @State sbsPairs: SbsPair[] = [];
  @State displayItems: DisplayItem[] = [];
  @State collapsedGaps: Set<number> = new Set();
  @State shortcutHint: string = '';
  @State editBuffer: string = '';
  @State session: DiffSessionViewModel = new DiffSessionViewModel();
  @State theme: ThemeColorMap = getLightColors();
  @State btnTheme: ButtonColorMap = getLightButtonColors();
  private scroller: Scroller = new Scroller();
  private isMonokai: boolean = false;

  aboutToAppear(): void {
    let fromDirA = AppStorage.get<string>('dirDiffContentA');
    let fromDirB = AppStorage.get<string>('dirDiffContentB');
    if (fromDirA !== undefined && fromDirA !== null && fromDirB !== undefined && fromDirB !== null) {
      this.session.textA = fromDirA;
      this.session.textB = fromDirB;
      this.session.fileNameA = AppStorage.get<string>('dirDiffNameA') || '文件A';
      this.session.fileNameB = AppStorage.get<string>('dirDiffNameB') || '文件B';
      this.session.isFileMode = true;
      AppStorage.delete('dirDiffContentA');
      AppStorage.delete('dirDiffContentB');
      AppStorage.delete('dirDiffNameA');
      AppStorage.delete('dirDiffNameB');
      this.runDiffAndSync();
    } else {
      this.session.textA = SampleDataProvider.getSampleA();
      this.session.textB = SampleDataProvider.getSampleB();
    }
    this.updateTheme();
  }

  private updateTheme(): void {
    this.isMonokai = this.colorMode === 'monokai';
    if (this.isMonokai) {
      this.theme = getMonokaiColors();
    } else if (this.colorMode === 'dark') {
      this.theme = getDarkColors();
    } else {
      this.theme = getLightColors();
    }
    if (this.colorMode === 'dark' || this.isMonokai) {
      this.btnTheme = getDarkButtonColors();
    } else {
      this.btnTheme = getLightButtonColors();
    }
  }

  build() {
    Column() {
      DiffToolbar({
        viewMode: this.session.viewMode, isComputing: this.session.isComputing,
        searchActive: this.session.searchVisible,
        onRunDiff: () => { this.runDiffAndSync(); },
        onSwitchView: (m: ViewMode) => { this.session.switchView(m); },
        onPasteSample: () => { this.pasteSample(); },
        onOpenSettings: () => { router.pushUrl({ url: 'pages/SettingsPage' }); },
        onToggleSearch: () => { this.toggleSearch(); },
        onOpenMerge: () => { router.pushUrl({ url: 'pages/MergePage' }); },
        onExport: () => { this.exportDiff(); }
      }).width('100%').height(44)
      Divider().height(1).color(this.theme.dividerColor)

      Scroll() {
        Row() {
          Button('选择文件A').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(10).padding({ left: 8, right: 8 })
            .onClick(() => { this.pickFileA(); })
          Button('选择文件B').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
            .onClick(() => { this.pickFileB(); })
          Button('目录对比').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#E3F2FD').fontColor('#1565C0').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
            .onClick(() => { router.pushUrl({ url: 'pages/DirectoryDiffPage' }); })
          Button('多Tab').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#FFF3E0').fontColor('#E65100').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
            .onClick(() => { router.pushUrl({ url: 'pages/MultiTabDiffPage' }); })
          Button('💾 保存').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#F3E5F5').fontColor('#7B1FA2').borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
            .onClick(() => { this.saveDiffToFile(); })
        }.padding({ left: 8, right: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%').height(36)
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })
      if (this.session.searchVisible && this.session.diffResult) {
        DiffSearchBar({
          totalMatches: this.session.totalSearchResults,
          currentMatchIndex: this.session.currentSearchResultIndex,
          onSearch: (keyword: string) => { this.session.performSearch(keyword); },
          onNavigateNext: () => { this.session.navigateSearchNext(); },
          onNavigatePrev: () => { this.session.navigateSearchPrev(); },
          onClose: () => { this.session.hideSearch(); }
        })
      }

      if (this.session.diffResult) {
        this.diffStatsBar()
      }

      if (this.isLargeScreen()) {
        Row() {
          if (this.inputVisible) {
            InputPanel({ textA: $session.textA, textB: $session.textB }).width('42%').height('100%')
          }
          if (this.session.diffResult) {
            Row() {
              Scroll() { this.diffContentArea() }
              .layoutWeight(1).height('100%').scrollBar(BarState.Auto)

              if (this.session.diffBlocks.length > 0) {
                DiffOverviewBar({
                  blocks: this.session.diffBlocks,
                  totalLines: this.session.diffResult ? this.session.diffResult.unifiedLines.length : 0,
                  isMonokai: this.isMonokai, activeIdx: this.navIdx,
                  onJumpToBlock: (idx: number) => { this.navIdx = idx;
                  this.scrollToBlock(idx); }
                }).width(10).height('100%')
              }
            }.width(this.inputVisible ? '58%' : '100%').height('100%')
          } else {
            this.emptyState()
          }
        }.width('100%').layoutWeight(1)
      } else {
        if (this.inputVisible) {
          InputPanel({ textA: $session.textA, textB: $session.textB }).width('100%').height(140)
        }
        if (this.session.diffResult) {
          Row() {
            Scroll(this.scroller) { this.diffContentArea() }
            .layoutWeight(1).height('100%').scrollBar(BarState.Auto)

            if (this.session.diffBlocks.length > 0) {
              DiffOverviewBar({
                blocks: this.session.diffBlocks,
                totalLines: this.session.diffResult ? this.session.diffResult.unifiedLines.length : 0,
                isMonokai: this.isMonokai, activeIdx: this.navIdx,
                onJumpToBlock: (idx: number) => { this.navIdx = idx;
                this.scrollToBlock(idx); }
              }).width(10).height('100%')
            }
          }.width('100%').layoutWeight(1)
        } else {
          this.emptyState()
        }
      }

      Divider().height(1).color(this.theme.dividerColor)
      DiffNavigator({
        totalBlocks: this.session.diffBlocks.length, currentIndex: this.navIdx,
        inputPanelVisible: this.inputVisible,
        onNavigateTo: (i: number) => { this.navIdx = i; },
        onToggleInput: () => { this.inputVisible = !this.inputVisible; }
      }).width('100%').height(40)
    }.width('100%').height('100%').backgroundColor(this.theme.pageBackground)
    .onKeyEvent((event: KeyEvent) => { return this.handleKeyEvent(event); })
  }

  @Builder
  fileImportBar() {
    Row() {
      Button('选择文件A').fontSize(11).height(28).type(ButtonType.Capsule)
        .backgroundColor(this.theme.diffAddedBackground)
        .fontColor(this.theme.diffAddedForeground)
        .borderRadius(10).padding({ left: 8, right: 8 })
        .onClick(() => { this.pickFileA(); })
      Button('选择文件B').fontSize(11).height(28).type(ButtonType.Capsule)
        .backgroundColor(this.theme.diffDeletedBackground)
        .fontColor(this.theme.diffDeletedForeground)
        .borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
        .onClick(() => { this.pickFileB(); })
      Button('目录对比').fontSize(11).height(28).type(ButtonType.Capsule)
        .backgroundColor(this.btnTheme.primaryBackground)
        .fontColor(this.btnTheme.primaryForeground)
        .borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
        .onClick(() => { router.pushUrl({ url: 'pages/DirectoryDiffPage' }); })
      Button('多Tab').fontSize(11).height(28).type(ButtonType.Capsule)
        .backgroundColor(this.btnTheme.warningBackground)
        .fontColor(this.btnTheme.warningForeground)
        .borderRadius(10).padding({ left: 8, right: 8 }).margin({ left: 6 })
        .onClick(() => { router.pushUrl({ url: 'pages/MultiTabDiffPage' }); })
      if (this.session.fileNameA !== '' || this.session.fileNameB !== '') {
        Text(this.session.fileNameA !== '' ? `A:${this.session.fileNameA}` : '')
          .fontSize(10).fontColor(this.theme.diffAddedForeground)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .margin({ left: 6 })
        Text(this.session.fileNameB !== '' ? `B:${this.session.fileNameB}` : '')
          .fontSize(10).fontColor(this.theme.diffDeletedForeground)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
          .margin({ left: 6 })
      } else {
        Blank().layoutWeight(1)
      }
    }
    .width('100%').height(36).padding({ left: 8, right: 8 })
    .backgroundColor(this.theme.surfaceBackground)
    .border({ width: { bottom: 1 }, color: this.theme.dividerColor })
  }

  @Builder
  diffContentArea() {
    if (this.session.viewMode === ViewMode.UNIFIED) {
      // 使用单个可同时滚动方向(Free)的 Scroll，避免嵌套滚动冲突。
      // 之前外层是垂直 Scroll + 内层是水平 Scroll，两者会抢夺滑动手势。
      Scroll() {
        Column() {
          ForEach(this.displayItems, (item: DisplayItem, idx: number) => {
            if (item.kind === 1) {
              this.gapRow(item.lineIdx, item.gapCount)
            } else {
              UnifiedLineRenderer({
                typeNum: this.session.diffResult!.unifiedLines[item.lineIdx].type,
                content: this.session.diffResult!.unifiedLines[item.lineIdx].content,
                linenoA: this.session.diffResult!.unifiedLines[item.lineIdx].lineNumberA,
                linenoB: this.session.diffResult!.unifiedLines[item.lineIdx].lineNumberB,
                isMonokai: this.isMonokai,
                isSearchMatch: this.session.isLineSearchMatch(item.lineIdx),
                isHighlighted: this.session.isLineInHighlightedBlock(item.lineIdx),
                charSegments: this.session.diffResult!.unifiedLines[item.lineIdx].charSegments,
                isEditing: this.session.isEditing(item.lineIdx),
                editBuffer: $editBuffer,
                onLineClick: () => { this.session.startEdit(item.lineIdx); },
                onEditSubmit: (v: string) => { this.session.submitEdit(v);
                this.syncStateFromSession(); },
                onEditCancel: () => { this.session.cancelEdit(); }
              })
            }
          }, (item: DisplayItem, idx: number) => `ud_${idx}`)
        }.alignItems(HorizontalAlign.Start)
      }
      .scrollable(ScrollDirection.Free)
      .scrollBar(BarState.Auto)
    } else {
      this.sideBySideView()
    }
  }

  @Builder
  gapRow(startIdx: number, count: number) {
    Row() {
      Text(`⋮ ${count} 行未变更 ⋮`)
        .fontSize(11).fontColor(this.theme.textSecondary).fontFamily('monospace')
    }
    .width('100%').height(22).justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme.diffUnchangedBackground)
    .onClick(() => {
      if (this.collapsedGaps.has(startIdx)) {
        this.collapsedGaps.delete(startIdx);
      } else {
        this.collapsedGaps.add(startIdx);
      }
      this.buildDisplayItems();
    })
  }

  @Builder
  diffStatsBar() {
    Row() {
      Text(`+${this.session.diffResult!.stats.addedCount}`).fontSize(11).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
      Text(` -${this.session.diffResult!.stats.deletedCount}`).fontSize(11).fontColor('#BE2E2E').fontWeight(FontWeight.Medium).margin({ left: 8, right: 8 })
      Text(` ~${this.session.diffResult!.stats.modifiedCount}`).fontSize(11).fontColor('#D4A017').fontWeight(FontWeight.Medium)
      Text(`  ${this.session.diffResult!.stats.similarityPercent}%`).fontSize(11).fontColor('#999999').layoutWeight(1)
      Text(`${this.session.diffBlocks.length}块`).fontSize(11).fontColor('#999999')
    }.width('100%').height(30).padding({ left: 12, right: 12 }).backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#E0E0E0' })
  }

  @Builder
  sideBySideView() {
    Column() {
      ForEach(this.sbsPairs, (p: SbsPair, i: number) => {
        SideBySideRenderer({
          leftType: p.leftType,
          leftContent: p.leftContent,
          leftLineNo: p.leftLineNo,
          rightType: p.rightType,
          rightContent: p.rightContent,
          rightLineNo: p.rightLineNo,
          isMonokai: this.isMonokai,
          isSearchMatch: this.session.isLineSearchMatch(i),
          isHighlighted: this.session.isLineInHighlightedBlock(i),
          isLeftEditing: this.session.isSideEditing(i, 'left'),
          isRightEditing: this.session.isSideEditing(i, 'right'),
          sideEditBuffer: $editBuffer,
          onSyncToRight: () => { this.session.syncToRight(i); this.syncStateFromSession(); },
          onSyncToLeft: () => { this.session.syncToLeft(i); this.syncStateFromSession(); },
          onLeftClick: () => {
            if (!this.session.isSideEditing(i, 'left')) {
              this.editBuffer = p.leftContent;
              this.session.startSideEdit(i, 'left');
            }
          },
          onRightClick: () => {
            if (!this.session.isSideEditing(i, 'right')) {
              this.editBuffer = p.rightContent;
              this.session.startSideEdit(i, 'right');
            }
          },
          onLeftEditSubmit: (v: string) => { this.session.submitSideEdit(v); this.syncStateFromSession(); },
          onRightEditSubmit: (v: string) => { this.session.submitSideEdit(v); this.syncStateFromSession(); },
          onLeftEditCancel: () => { this.session.cancelSideEdit(); },
          onRightEditCancel: () => { this.session.cancelSideEdit(); }
        })
      }, (p: SbsPair, i: number) => `sbs_${i}`)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  emptyState() {
    Column() {
      Text('AegisDiff').fontSize(22).fontColor(this.theme.textPrimary)
      Text('点击执行对比查看差异').fontSize(13).fontColor(this.theme.textSecondary).margin({ top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  private isLargeScreen(): boolean { return this.currentBp === 'lg' || this.currentBp === 'md'; }

  /** 执行 diff 并在失败时弹窗 */
  private runDiffAndSync(): void {
    this.session.runTextDiff();
    this.syncStateFromSession();
    if (this.session.lastError) {
      AlertDialog.show({
        title: 'Diff 执行失败',
        message: this.session.lastError,
        autoCancel: true,
        confirm: { value: '确定', action: () => {} }
      });
    }
  }

  /** 从 session 同步显示状态 */
  private syncStateFromSession(): void {
    if (!this.session.diffResult) return;

    // 构建 SBS 配对
    this.sbsPairs = [];
    const len = Math.max(this.session.diffResult.leftLines.length, this.session.diffResult.rightLines.length);
    for (let i = 0; i < len; i++) {
      const left = this.session.diffResult.leftLines[i];
      const right = this.session.diffResult.rightLines[i];
      this.sbsPairs.push({
        leftType: left ? left.type : 0,
        leftContent: left ? left.content : '',
        leftLineNo: left ? left.lineNumberA : -1,
        rightType: right ? right.type : 0,
        rightContent: right ? right.content : '',
        rightLineNo: right ? right.lineNumberB : -1
      } as SbsPair);
    }

    this.collapsedGaps = new Set();
    this.buildDisplayItems();
    this.navIdx = this.session.highlightBlockIndex >= 0 ? this.session.highlightBlockIndex : 0;
  }

  private buildDisplayItems(): void {
    const GAP_MIN = 8;
    this.displayItems = [];
    if (!this.session.diffResult) return;

    const lines = this.session.diffResult.unifiedLines;
    let i = 0;
    while (i < lines.length) {
      if (lines[i].type === 0) {
        let runStart = i;
        while (i < lines.length && lines[i].type === 0) {
          i++;
        }
        let runLen = i - runStart;
        if (runLen > GAP_MIN && !this.collapsedGaps.has(runStart)) {
          for (let j = 0; j < 3 && runStart + j < runStart + runLen; j++) {
            this.displayItems.push({ kind: 0, lineIdx: runStart + j, gapCount: 0 });
          }
          this.displayItems.push({ kind: 1, lineIdx: runStart + 3, gapCount: runLen - 6 });
          for (let j = runLen - 3; j < runLen; j++) {
            if (runStart + j >= runStart + 3) {
              this.displayItems.push({ kind: 0, lineIdx: runStart + j, gapCount: 0 });
            }
          }
        } else {
          for (let j = runStart; j < i; j++) {
            this.displayItems.push({ kind: 0, lineIdx: j, gapCount: 0 });
          }
        }
      } else {
        this.displayItems.push({ kind: 0, lineIdx: i, gapCount: 0 });
        i++;
      }
    }
  }

  private scrollToBlock(blockIdx: number): void {
    if (blockIdx < 0 || blockIdx >= this.session.diffBlocks.length) return;
    const block = this.session.diffBlocks[blockIdx];
    this.scroller.scrollToIndex(block.startIndex, true);
    this.navIdx = blockIdx;
  }

  private handleKeyEvent(event: KeyEvent): void {
    if (event.type === KeyType.Down) {
      switch (event.keyCode) {
        case KeyCode.KEYCODE_ESCAPE:
          this.session.cancelEdit();
          this.session.hideSearch();
          break;
        case KeyCode.KEYCODE_CTRL_LEFT:
        case KeyCode.KEYCODE_CTRL_RIGHT:
          break;
        default:
          if (event.keyCode >= KeyCode.KEYCODE_F1 && event.keyCode <= KeyCode.KEYCODE_F12) break;
          let ctrl = event.isCtrlPressed;
          if (ctrl && event.keyCode === KeyCode.KEYCODE_S) {
            this.session.runTextDiff();
            this.syncStateFromSession();
            break;
          }
          if (ctrl && event.keyCode === KeyCode.KEYCODE_F) {
            this.toggleSearch();
            break;
          }
          if (ctrl && event.keyCode === KeyCode.KEYCODE_U) {
            this.session.switchView(ViewMode.UNIFIED);
            break;
          }
          if (ctrl && event.keyCode === KeyCode.KEYCODE_B) {
            this.session.switchView(ViewMode.SIDE_BY_SIDE);
            break;
          }
      }
    }
  }

  private toggleSearch(): void {
    if (this.session.searchVisible) {
      this.session.hideSearch();
    } else {
      this.session.showSearch();
    }
  }

  private pasteSample(): void {
    this.session.textA = SampleDataProvider.getSampleA();
    this.session.textB = SampleDataProvider.getSampleB();
    this.session.runTextDiff();
    this.syncStateFromSession();
  }

  private async pickFileA(): Promise<void> {
    try {
      const uris = await this.pickFile();
      if (uris.length > 0) {
        const content = await FileContentService.readTextFile(uris[0]);
        this.session.textA = content;
        const name = FileContentService.extractFileName(uris[0]);
        this.session.fileNameA = name;
        this.session.isFileMode = true;
        this.session.runTextDiff();
        this.syncStateFromSession();
      }
    } catch (e) {
      // user cancelled
    }
  }

  private async pickFileB(): Promise<void> {
    try {
      const uris = await this.pickFile();
      if (uris.length > 0) {
        const content = await FileContentService.readTextFile(uris[0]);
        this.session.textB = content;
        const name = FileContentService.extractFileName(uris[0]);
        this.session.fileNameB = name;
        this.session.isFileMode = true;
        this.session.runTextDiff();
        this.syncStateFromSession();
      }
    } catch (e) {
      // user cancelled
    }
  }

  private async pickFile(): Promise<string[]> {
    const docPicker = new picker.DocumentViewPicker();
    const result = await docPicker.select();
    if (result && result.length > 0) {
      return result;
    }
    return [];
  }

  private exportDiff(): void {
    if (!this.session.diffResult) return;
    const lines = this.session.diffResult.unifiedLines;
    let exportText = '';
    for (const line of lines) {
      let prefix = ' ';
      switch (line.type) {
        case 0: prefix = ' '; break;
        case 1: prefix = '-'; break;
        case 2: prefix = '+'; break;
        case 3: prefix = '~'; break;
      }
      exportText += `${prefix} ${line.content}\n`;
    }
    this.session.copyToClipboard(text, () => {
      AlertDialog.show({
        title: '导出成功',
        message: `${this.session.diffBlocks.length}个差异块 → 已复制到剪贴板`,
        autoCancel: true
      });
    });
  }

  private pickFileA(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          try {
            const result = FileContentService.readFileContent(uris[0]);
            this.session.textA = result.content;
            this.session.fileNameA = result.fileName;
            if (result.error) {
              AlertDialog.show({ title: '提示', message: result.error, autoCancel: true });
            }
            if (this.session.textA.length > 0 && this.session.textB.length > 0) {
              this.runDiffAndSync();
            }
          } catch (e2) {
            console.error('DiffEditorPage.pickFileA.readFileContent error:', JSON.stringify(e2));
            AlertDialog.show({ title: '读取失败', message: '无法读取所选文件，文件可能过大或格式不支持', autoCancel: true });
          }
        }
      }).catch((reason: Object) => {
        console.error('DiffEditorPage.pickFileA Promise rejected:', JSON.stringify(reason));
        AlertDialog.show({ title: '选择文件失败', message: '文件选择器异常，请重试', autoCancel: true });
      });
    } catch (e) {
      console.error('DiffEditorPage.pickFileA caught:', JSON.stringify(e));
    }
  }

  private saveDiffToFile(): void {
    const diffText = this.session.generateUnifiedDiff();
    if (!diffText) {
      AlertDialog.show({ title: '无差异', message: '请先执行对比', autoCancel: true });
      return;
    }
    try {
      let context = getContext(this);
      let filePicker = new picker.DocumentViewPicker(context);
      let saveOpts = new picker.DocumentSaveOptions();
      saveOpts.newFileNames = ['diff_output.patch'];
      filePicker.save(saveOpts).then((uris: string[]) => {
        if (uris.length > 0) {
          try {
            let file = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
            fs.writeSync(file.fd, diffText);
            fs.closeSync(file);
            AlertDialog.show({ title: '保存成功', message: `差异已保存到文件`, autoCancel: true });
          } catch (err) {
            AlertDialog.show({ title: '保存失败', message: '无法写入文件', autoCancel: true });
          }
        }
      });
    } catch (e) {
      AlertDialog.show({ title: '保存失败', message: '导出文件时出错', autoCancel: true });
    }
  }

  private pickFileB(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          try {
            const result = FileContentService.readFileContent(uris[0]);
            this.session.textB = result.content;
            this.session.fileNameB = result.fileName;
            if (result.error) {
              AlertDialog.show({ title: '提示', message: result.error, autoCancel: true });
            }
            if (this.session.textA.length > 0 && this.session.textB.length > 0) {
              this.runDiffAndSync();
            }
          } catch (e2) {
            console.error('DiffEditorPage.pickFileB.readFileContent error:', JSON.stringify(e2));
            AlertDialog.show({ title: '读取失败', message: '无法读取所选文件，文件可能过大或格式不支持', autoCancel: true });
          }
        }
      }).catch((reason: Object) => {
        console.error('DiffEditorPage.pickFileB Promise rejected:', JSON.stringify(reason));
        AlertDialog.show({ title: '选择文件失败', message: '文件选择器异常，请重试', autoCancel: true });
      });
    } catch (e) {
      console.error('DiffEditorPage.pickFileB caught:', JSON.stringify(e));
    }
  }
}