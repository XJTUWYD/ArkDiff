/**
 * AegisDiff — DiffEditorPage（Meld 风格双栏对比编辑器）
 *
 * 没有独立的输入面板，所有编辑在 diff 视图内行内完成。
 * 同步按钮（← →）修改源码后立即重算 diff 并刷新显示。
 */
import { router } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { DiffBlockLocator, DiffBlock } from '../engine/DiffBlockLocator';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffToolbar } from '../components/DiffToolbar';
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
}

@Entry
@Component
struct DiffEditorPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @StorageLink('ignoreBlankLines') ignoreBlankLines: boolean = false;
  @StorageLink('ignoreCase') ignoreCase: boolean = false;
  @StorageLink('ignoreWhitespace') ignoreWhitespace: boolean = false;
  @State navIdx: number = 0;
  @State sbsPairs: SbsPair[] = [];
  @State displayItems: DisplayItem[] = [];
  @State collapsedGaps: Set<number> = new Set();
  @State editBuffer: string = '';
  @State session: DiffSessionViewModel = new DiffSessionViewModel();
  @State textA: string = '';
  @State textB: string = '';
  @State theme: ThemeColorMap = getLightColors();
  @State btnTheme: ButtonColorMap = getLightButtonColors();
  @State sbsVersion: number = 0;  // 每次同步刷新强制 ForEach 检测变化
  private unifiedScroller: Scroller = new Scroller();
  private isMonokai: boolean = false;

  aboutToAppear(): void {
    let fromDirA = AppStorage.get<string>('dirDiffContentA');
    let fromDirB = AppStorage.get<string>('dirDiffContentB');
    if (fromDirA !== undefined && fromDirA !== null && fromDirB !== undefined && fromDirB !== null) {
      this.session.textA = fromDirA;
      this.session.textB = fromDirB;
      this.textA = fromDirA;
      this.textB = fromDirB;
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
      this.textA = this.session.textA;
      this.textB = this.session.textB;
    }
    this.syncSessionOptions();
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

  private syncSessionOptions(): void {
    this.session.ignoreBlankLines = this.ignoreBlankLines;
    this.session.ignoreCase = this.ignoreCase;
    this.session.ignoreWhitespace = this.ignoreWhitespace;
  }

  build() {
    Column() {
      // === 工具栏 ===
      Row() {
        DiffToolbar({
          viewMode: this.session.viewMode, isComputing: this.session.isComputing,
          searchActive: this.session.searchVisible,
          isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
          onRunDiff: () => { this.syncSessionOptions(); this.runDiffAndSync(); },
          onSwitchView: (m: ViewMode) => { this.session.switchView(m); },
          onPasteSample: () => { this.pasteSample(); },
          onOpenSettings: () => { router.pushUrl({ url: 'pages/SettingsPage' }); },
          onToggleSearch: () => { this.toggleSearch(); },
          onOpenMerge: () => { router.pushUrl({ url: 'pages/MergePage' }); },
          onExport: () => { this.exportDiff(); },
          onPickFileA: () => { this.pickFileA(); },
          onPickFileB: () => { this.pickFileB(); }
        }).height(44)

        if (this.session.fileNameA !== '' || this.session.fileNameB !== '') {
          Text(this.session.fileNameA !== '' ? `A:${this.session.fileNameA}` : '')
            .fontSize(10).fontColor(this.theme.diffAddedForeground).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ left: 6 })
          Text(this.session.fileNameB !== '' ? `B:${this.session.fileNameB}` : '')
            .fontSize(10).fontColor(this.theme.diffDeletedForeground).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ left: 6 })
        }
      }.width('100%').height(44).padding({ left: 4, right: 8 })
      .backgroundColor(this.theme.toolbarBackground)

      Divider().height(1).color(this.theme.dividerColor)

      // === 搜索栏 ===
      if (this.session.searchVisible && this.session.diffResult) {
        DiffSearchBar({
          totalMatches: this.session.totalSearchResults,
          currentMatchIndex: this.session.currentSearchResultIndex,
          isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
          onSearch: (keyword: string) => { this.session.performSearch(keyword); },
          onNavigateNext: () => { this.session.navigateSearchNext(); },
          onNavigatePrev: () => { this.session.navigateSearchPrev(); },
          onClose: () => { this.session.hideSearch(); }
        })
      }

      // === 统计栏 ===
      if (this.session.diffResult) {
        this.diffStatsBar()
      }

      // === Diff 内容区（全高，无输入面板） ===
      if (this.session.diffResult) {
        Row() {
          Scroll(this.unifiedScroller) { this.diffContentArea() }
          .layoutWeight(1).height('100%').scrollBar(BarState.Auto)

          if (this.session.diffBlocks.length > 0) {
            DiffOverviewBar({
              blocks: this.session.diffBlocks,
              totalLines: this.session.diffResult.unifiedLines.length,
              isMonokai: this.isMonokai, isDark: this.colorMode === 'dark', activeIdx: this.navIdx,
              onJumpToBlock: (idx: number) => { this.navIdx = idx; this.scrollToBlock(idx); }
            }).width(10).height('100%')
          }
        }.width('100%').layoutWeight(1)
      } else {
        this.emptyState()
      }

      // === 底部导航栏 ===
      Divider().height(1).color(this.theme.dividerColor)
      DiffNavigator({
        totalBlocks: this.session.diffBlocks.length, currentIndex: this.navIdx,
        isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
        onNavigateTo: (i: number) => { this.navIdx = i; this.scrollToBlock(i); },
        onPickFileA: () => { this.pickFileA(); },
        onPickFileB: () => { this.pickFileB(); }
      }).width('100%').height(40)
    }.width('100%').height('100%').backgroundColor(this.theme.pageBackground)
    .onKeyEvent((event: Object) => {
      const keyCode = (event as Record<string, Object>)['keyCode'] as number;
      const keyType = (event as Record<string, Object>)['type'] as number;
      if (keyType === 1) {
        switch (keyCode) {
          case 2055:
            this.session.cancelEdit();
            this.session.cancelSideEdit();
            this.session.hideSearch();
            break;
          default:
            if (keyCode >= 2048 && keyCode <= 2059) break;
            const ctrl = (event as Record<string, Object>)['ctrlKey'] as boolean;
            if (ctrl && keyCode === 2116) {
              this.syncSessionOptions();
              this.session.textA = this.textA;
              this.session.textB = this.textB;
              this.session.runTextDiff();
              this.syncStateFromSession();
            }
            if (ctrl && keyCode === 2109) {
              this.toggleSearch();
            }
            if (ctrl && keyCode === 2127) {
              this.session.switchView(ViewMode.UNIFIED);
            }
            if (ctrl && keyCode === 2098) {
              this.session.switchView(ViewMode.SIDE_BY_SIDE);
            }
        }
      }
      return true;
    })
  }

  // ==================== 内容区 ====================

  @Builder
  diffContentArea() {
    if (this.session.viewMode === ViewMode.UNIFIED) {
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
              isDark: this.colorMode === 'dark',
              isSearchMatch: this.session.isLineSearchMatch(item.lineIdx),
              isHighlighted: this.session.isLineInHighlightedBlock(item.lineIdx),
              charSegments: this.session.diffResult!.unifiedLines[item.lineIdx].charSegments,
              isEditing: this.session.isEditing(item.lineIdx),
              editBuffer: $editBuffer,
              onLineClick: () => { this.session.startEdit(item.lineIdx); },
              onEditSubmit: (v: string) => { this.session.submitEdit(v); this.syncBothAfterEdit(); },
              onEditCancel: () => { this.session.cancelEdit(); }
            })
          }
          }, (item: DisplayItem, idx: number) => `ud_v${this.sbsVersion}_${idx}_${item.kind}_${item.lineIdx}`)
      }.alignItems(HorizontalAlign.Start)
    } else {
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
            isDark: this.colorMode === 'dark',
            isSearchMatch: this.session.isLineSearchMatch(i),
            isHighlighted: this.session.isLineInHighlightedBlock(i),
            isLeftEditing: this.session.isSideEditing(i, 'left'),
            isRightEditing: this.session.isSideEditing(i, 'right'),
            sideEditBuffer: $editBuffer,
            onSyncToRight: () => { this.session.syncToRight(i); this.syncBothAfterEdit(); },
            onSyncToLeft: () => { this.session.syncToLeft(i); this.syncBothAfterEdit(); },
            onLeftClick: () => {
              if (!this.session.isSideEditing(i, 'left') && p.leftContent.length > 0) {
                this.editBuffer = p.leftContent;
                this.session.startSideEdit(i, 'left');
              }
            },
            onRightClick: () => {
              if (!this.session.isSideEditing(i, 'right') && p.rightContent.length > 0) {
                this.editBuffer = p.rightContent;
                this.session.startSideEdit(i, 'right');
              }
            },
            onLeftEditSubmit: (v: string) => { this.session.submitSideEdit(v); this.syncBothAfterEdit(); },
            onRightEditSubmit: (v: string) => { this.session.submitSideEdit(v); this.syncBothAfterEdit(); },
            onLeftEditCancel: () => { this.session.cancelSideEdit(); },
            onRightEditCancel: () => { this.session.cancelSideEdit(); }
          })
        }, (p: SbsPair, i: number) => `sbs_v${this.sbsVersion}_${i}_${p.leftLineNo}_${p.leftType}_${p.rightLineNo}_${p.rightType}`)
      }.alignItems(HorizontalAlign.Start)
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
      Text(`+${this.session.diffResult!.stats.addedCount}`).fontSize(11).fontColor(this.theme.diffAddedForeground).fontWeight(FontWeight.Medium)
      Text(` -${this.session.diffResult!.stats.deletedCount}`).fontSize(11).fontColor(this.theme.diffDeletedForeground).fontWeight(FontWeight.Medium).margin({ left: 8, right: 8 })
      Text(` ~${this.session.diffResult!.stats.modifiedCount}`).fontSize(11).fontColor(this.theme.diffModifiedForeground).fontWeight(FontWeight.Medium)
      Text(`  ${this.session.diffResult!.stats.similarityPercent}%`).fontSize(11).fontColor(this.theme.textSecondary).layoutWeight(1)
      Text(`${this.session.diffBlocks.length}块`).fontSize(11).fontColor(this.theme.textSecondary)
    }.width('100%').height(30).padding({ left: 12, right: 12 }).backgroundColor(this.theme.surfaceBackground)
    .border({ width: { bottom: 1 }, color: this.theme.dividerColor })
  }

  @Builder
  emptyState() {
    Column() {
      Text('AegisDiff').fontSize(22).fontColor(this.theme.textPrimary)
      Text('粘贴示例代码或使用 Ctrl+O 打开文件').fontSize(13).fontColor(this.theme.textSecondary).margin({ top: 8 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  // ==================== 状态同步 ====================

  private runDiffAndSync(): void {
    this.session.textA = this.textA;
    this.session.textB = this.textB;
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

  /**
   * 【修复】将 sbsPairs 一次性构建并赋值为新数组引用，
   * 确保 ArkTS @State 能检测到变化并触发 ForEach 重新渲染。
   */
  private syncStateFromSession(): void {
    if (!this.session || !this.session.diffResult) return;

    const leftLines = this.session.diffResult.leftLines;
    const rightLines = this.session.diffResult.rightLines;
    const len = Math.max(leftLines.length, rightLines.length);
    const newPairs: SbsPair[] = [];
    for (let i = 0; i < len; i++) {
      const left = leftLines[i];
      const right = rightLines[i];
      newPairs.push({
        leftType: left ? left.type : 0,
        leftContent: left ? left.content : '',
        leftLineNo: left ? left.lineNumberA : -1,
        rightType: right ? right.type : 0,
        rightContent: right ? right.content : '',
        rightLineNo: right ? right.lineNumberB : -1
      });
    }
    this.sbsPairs = newPairs;
    this.sbsVersion++;  // 强制 ForEach key 失效，确保 @Prop 重新传递

    this.collapsedGaps = new Set();
    this.buildDisplayItems();
    this.navIdx = this.session.highlightBlockIndex >= 0 ? this.session.highlightBlockIndex : 0;
  }

  /**
   * 行内编辑/同步后刷新 SBS + Unified 双视图状态，
   * 同时也把编辑后的 textA/textB 同步回页面 @State
   */
  private syncBothAfterEdit(): void {
    this.textA = this.session.textA;
    this.textB = this.session.textB;
    this.syncStateFromSession();
  }

  private buildDisplayItems(): void {
    const GAP_MIN = 8;
    const result: DisplayItem[] = [];
    if (!this.session.diffResult) {
      this.displayItems = result;
      return;
    }

    const lines = this.session.diffResult.unifiedLines;
    let i = 0;
    while (i < lines.length) {
      if (lines[i].type === 0) {
        let runStart = i;
        while (i < lines.length && lines[i].type === 0) i++;
        let runLen = i - runStart;
        if (runLen > GAP_MIN && !this.collapsedGaps.has(runStart)) {
          for (let j = 0; j < 3 && runStart + j < runStart + runLen; j++) {
            result.push({ kind: 0, lineIdx: runStart + j, gapCount: 0 });
          }
          result.push({ kind: 1, lineIdx: runStart + 3, gapCount: runLen - 6 });
          for (let j = runLen - 3; j < runLen; j++) {
            if (runStart + j >= runStart + 3) {
              result.push({ kind: 0, lineIdx: runStart + j, gapCount: 0 });
            }
          }
        } else {
          for (let j = runStart; j < i; j++) {
            result.push({ kind: 0, lineIdx: j, gapCount: 0 });
          }
        }
      } else {
        result.push({ kind: 0, lineIdx: i, gapCount: 0 });
        i++;
      }
    }
    this.displayItems = result;
  }

  private scrollToBlock(blockIdx: number): void {
    if (blockIdx < 0 || blockIdx >= this.session.diffBlocks.length) return;
    const block = this.session.diffBlocks[blockIdx];
    this.unifiedScroller.scrollToIndex(block.startIndex, true);
    this.navIdx = blockIdx;
  }

  // ==================== 操作 ====================

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
    this.textA = this.session.textA;
    this.textB = this.session.textB;
    this.syncSessionOptions();
    this.session.runTextDiff();
    this.syncStateFromSession();
  }

  private exportDiff(): void {
    if (!this.session.diffResult) return;
    let exportText = this.session.generateUnifiedDiff();
    if (!exportText) return;
    this.session.copyToClipboard(exportText, () => {
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
      new picker.DocumentViewPicker(context).select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          try {
            const result = FileContentService.readFileContent(uris[0]);
            this.session.textA = result.content;
            this.textA = result.content;
            this.session.fileNameA = result.fileName;
            if (result.error) {
              AlertDialog.show({ title: '提示', message: result.error, autoCancel: true });
            }
            if (this.session.textA.length > 0 && this.session.textB.length > 0) {
              this.syncSessionOptions();
              this.runDiffAndSync();
            }
          } catch (e2) {
            AlertDialog.show({ title: '读取失败', message: '无法读取文件', autoCancel: true });
          }
        }
      }).catch(() => {});
    } catch (e) {}
  }

  private pickFileB(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      new picker.DocumentViewPicker(context).select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          try {
            const result = FileContentService.readFileContent(uris[0]);
            this.session.textB = result.content;
            this.textB = result.content;
            this.session.fileNameB = result.fileName;
            if (result.error) {
              AlertDialog.show({ title: '提示', message: result.error, autoCancel: true });
            }
            if (this.session.textA.length > 0 && this.session.textB.length > 0) {
              this.syncSessionOptions();
              this.runDiffAndSync();
            }
          } catch (e2) {
            AlertDialog.show({ title: '读取失败', message: '无法读取文件', autoCancel: true });
          }
        }
      }).catch(() => {});
    } catch (e) {}
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
            AlertDialog.show({ title: '保存成功', message: '差异已保存到文件', autoCancel: true });
          } catch (err) {
            AlertDialog.show({ title: '保存失败', message: '无法写入文件', autoCancel: true });
          }
        }
      });
    } catch (e) {
      AlertDialog.show({ title: '保存失败', message: '导出文件时出错', autoCancel: true });
    }
  }
}
