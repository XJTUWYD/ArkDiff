/**
 * AegisDiff — DiffEditorPage（Meld 风格双栏对比编辑器）
 *
 * 仅分栏视图，左右两侧空栏可直接粘贴/打开文件。
 * 同步按钮（← →）原地 patch 不跑全量 re-diff。
 * LazyForEach 虚拟列表渲染大 diff。
 */
import { router } from '@kit.ArkUI';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffToolbar } from '../components/DiffToolbar';
import { DiffOverviewBar } from '../components/DiffOverviewBar';
import { SideBySideRenderer } from '../components/SideBySideRenderer';
import { DiffSearchBar } from '../components/DiffSearchBar';
import { SampleDataProvider } from '../utils/SampleDataProvider';
import { DiffSessionViewModel } from '../viewmodel/DiffSessionViewModel';
import { FileContentService } from '../services/FileContentService';
import { ViewMode } from '../model/DiffModels';
import {
  ThemeColorMap, getLightColors, getDarkColors, getMonokaiColors,
  ButtonColorMap, getLightButtonColors, getDarkButtonColors
} from '../utils/ThemeTokens';

interface SbsPair {
  leftType: number; leftContent: string; leftLineNo: number;
  rightType: number; rightContent: string; rightLineNo: number;
  isLeftBlockStart: boolean; isRightBlockStart: boolean;
}

class SbsDataSource implements IDataSource {
  private items: SbsPair[] = [];
  private listeners: DataChangeListener[] = [];
  setItems(items: SbsPair[]): void { this.items = items; this.notifyReload(); }
  totalCount(): number { return this.items.length; }
  getData(index: number): SbsPair { return this.items[index]; }
  registerDataChangeListener(l: DataChangeListener): void { if (this.listeners.indexOf(l) < 0) this.listeners.push(l); }
  unregisterDataChangeListener(l: DataChangeListener): void { const p = this.listeners.indexOf(l); if (p >= 0) this.listeners.splice(p, 1); }
  private notifyReload(): void { this.listeners.forEach(l => l.onDataReloaded()); }
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
  @State sbsSource: SbsDataSource = new SbsDataSource();
  @State editBuffer: string = '';
  @State session: DiffSessionViewModel = new DiffSessionViewModel();
  @State textA: string = '';
  @State textB: string = '';
  @State theme: ThemeColorMap = getLightColors();
  @State btnTheme: ButtonColorMap = getLightButtonColors();
  @State started: boolean = false;
  private scroller: Scroller = new Scroller();
  private isMonokai: boolean = false;

  aboutToAppear(): void {
    let fromA = AppStorage.get<string>('dirDiffContentA');
    let fromB = AppStorage.get<string>('dirDiffContentB');
    if (fromA !== undefined && fromA !== null && fromB !== undefined && fromB !== null) {
      this.session.textA = fromA; this.session.textB = fromB;
      this.textA = fromA; this.textB = fromB;
      this.session.fileNameA = AppStorage.get<string>('dirDiffNameA') || 'A';
      this.session.fileNameB = AppStorage.get<string>('dirDiffNameB') || 'B';
      this.session.isFileMode = true;
      AppStorage.delete('dirDiffContentA'); AppStorage.delete('dirDiffContentB');
      AppStorage.delete('dirDiffNameA'); AppStorage.delete('dirDiffNameB');
      this.syncSessionOptions();
      this.runDiffAndSync();
    }
    this.updateTheme();
  }

  private updateTheme(): void {
    this.isMonokai = this.colorMode === 'monokai';
    this.theme = this.isMonokai ? getMonokaiColors() : this.colorMode === 'dark' ? getDarkColors() : getLightColors();
    this.btnTheme = (this.colorMode === 'dark' || this.isMonokai) ? getDarkButtonColors() : getLightButtonColors();
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
          viewMode: ViewMode.SIDE_BY_SIDE, isComputing: this.session.isComputing,
          searchActive: this.session.searchVisible,
          isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
          onRunDiff: () => { this.syncSessionOptions(); this.runDiffAndSync(); },
          onPasteSample: () => { this.pasteSample(); },
          onOpenSettings: () => { router.pushUrl({ url: 'pages/SettingsPage' }); },
          onToggleSearch: () => { this.toggleSearch(); },
          onExport: () => { this.exportDiff(); },
          onPickFileA: () => { this.pickFileA(); },
          onPickFileB: () => { this.pickFileB(); }
        }).height(44)

        if (this.session.fileNameA || this.session.fileNameB) {
          if (this.session.fileNameA) Text(`A:${this.session.fileNameA}`).fontSize(10).fontColor(this.theme.diffAddedForeground).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ left: 6 })
          if (this.session.fileNameB) Text(`B:${this.session.fileNameB}`).fontSize(10).fontColor(this.theme.diffDeletedForeground).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ left: 6 })
        }
      }.width('100%').height(44).padding({ left: 4, right: 8 }).backgroundColor(this.theme.toolbarBackground)

      Divider().height(1).color(this.theme.dividerColor)

      // === 搜索栏 ===
      if (this.session.searchVisible && this.session.diffResult) {
        DiffSearchBar({
          totalMatches: this.session.totalSearchResults, currentMatchIndex: this.session.currentSearchResultIndex,
          isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
          onSearch: (kw: string) => { this.session.performSearch(kw); },
          onNavigateNext: () => { this.session.navigateSearchNext(); },
          onNavigatePrev: () => { this.session.navigateSearchPrev(); },
          onClose: () => { this.session.hideSearch(); }
        })
      }

      // === 统计栏 ===
      if (this.session.diffResult) this.diffStatsBar()

      // === SBS 内容区 ===
      if (this.session.diffResult) {
        Row() {
          Scroll(this.scroller) {
            Column() {
              LazyForEach(this.sbsSource, (p: SbsPair, i: number) => {
                SideBySideRenderer({
                  leftType: p.leftType, leftContent: p.leftContent, leftLineNo: p.leftLineNo,
                  rightType: p.rightType, rightContent: p.rightContent, rightLineNo: p.rightLineNo,
                  isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
                  isSearchMatch: this.session.isLineSearchMatch(i),
                  isHighlighted: this.session.isLineInHighlightedBlock(i),
                  isLeftEditing: this.session.isSideEditing(i, 'left'),
                  isRightEditing: this.session.isSideEditing(i, 'right'),
                  isLeftBlockStart: p.isLeftBlockStart, isRightBlockStart: p.isRightBlockStart,
                  sideEditBuffer: $editBuffer,
                  onSyncToRight: () => { this.session.syncBlockToRight(i); this.syncBothAfterEdit(); },
                  onSyncToLeft: () => { this.session.syncBlockToLeft(i); this.syncBothAfterEdit(); },
                  onLeftClick: () => { if (!this.session.isSideEditing(i, 'left') && p.leftContent.length > 0) { this.editBuffer = p.leftContent; this.session.startSideEdit(i, 'left'); } },
                  onRightClick: () => { if (!this.session.isSideEditing(i, 'right') && p.rightContent.length > 0) { this.editBuffer = p.rightContent; this.session.startSideEdit(i, 'right'); } },
                  onLeftEditSubmit: (v: string) => { this.session.submitSideEdit(v); this.syncBothAfterEdit(); },
                  onRightEditSubmit: (v: string) => { this.session.submitSideEdit(v); this.syncBothAfterEdit(); },
                  onLeftEditCancel: () => { this.session.cancelSideEdit(); },
                  onRightEditCancel: () => { this.session.cancelSideEdit(); }
                })
              }, (p: SbsPair, i: number) => `sbs_${p.leftLineNo}_${p.leftType}_${p.rightLineNo}_${p.rightType}`)
            }.alignItems(HorizontalAlign.Start)
          }.layoutWeight(1).height('100%').scrollBar(BarState.Auto)

          if (this.session.diffBlocks.length > 0) {
            DiffOverviewBar({
              blocks: this.session.diffBlocks, totalLines: this.session.diffResult.unifiedLines.length,
              isMonokai: this.isMonokai, isDark: this.colorMode === 'dark', activeIdx: this.navIdx,
              onJumpToBlock: (idx: number) => { this.navIdx = idx; this.scrollToBlock(idx); }
            }).width(10).height('100%')
          }
        }.width('100%').layoutWeight(1)
      } else {
        // Meld-style empty start: two side-by-side text areas
        Row() {
          Column() {
            Text('A').fontSize(11).fontColor(this.theme.textSecondary).padding({ left: 8, top: 4 })
            TextArea({ text: this.textA, placeholder: '粘贴或打开文件 A…' })
              .fontSize(12).fontFamily('monospace').fontColor(this.theme.textPrimary)
              .backgroundColor(this.theme.diffUnchangedBackground)
              .padding(8).layoutWeight(1)
              .onChange((v: string) => { this.textA = v; this.session.textA = v; })
          }.width('50%').height('100%').border({ width: { right: 1 }, color: this.theme.dividerColor })
          Column() {
            Text('B').fontSize(11).fontColor(this.theme.textSecondary).padding({ left: 8, top: 4 })
            TextArea({ text: this.textB, placeholder: '粘贴或打开文件 B…' })
              .fontSize(12).fontFamily('monospace').fontColor(this.theme.textPrimary)
              .backgroundColor(this.theme.diffUnchangedBackground)
              .padding(8).layoutWeight(1)
              .onChange((v: string) => { this.textB = v; this.session.textB = v; })
          }.width('50%').height('100%')
        }.width('100%').layoutWeight(1)
      }

      // === 底部导航栏 ===
      if (this.session.diffResult) {
        Divider().height(1).color(this.theme.dividerColor)
        DiffNavigator({
          totalBlocks: this.session.diffBlocks.length, currentIndex: this.navIdx,
          isMonokai: this.isMonokai, isDark: this.colorMode === 'dark',
          onNavigateTo: (i: number) => { this.navIdx = i; this.scrollToBlock(i); },
          onPickFileA: () => { this.pickFileA(); },
          onPickFileB: () => { this.pickFileB(); }
        }).width('100%').height(40)
      }
    }.width('100%').height('100%').backgroundColor(this.theme.pageBackground)
    .onKeyEvent((event: Object) => {
      const kc = (event as Record<string, Object>)['keyCode'] as number;
      const kt = (event as Record<string, Object>)['type'] as number;
      if (kt === 1 && kc === 2055) { this.session.cancelSideEdit(); this.session.hideSearch(); }
      if (kt === 1) {
        const ctrl = (event as Record<string, Object>)['ctrlKey'] as boolean;
        if (ctrl && kc === 2116) { this.runDiffAndSync(); }
        if (ctrl && kc === 2109) { this.toggleSearch(); }
      }
      return true;
    })
  }

  @Builder diffStatsBar() {
    Row() {
      Text(`+${this.session.diffResult!.stats.addedCount}`).fontSize(11).fontColor(this.theme.diffAddedForeground).fontWeight(FontWeight.Medium)
      Text(` -${this.session.diffResult!.stats.deletedCount}`).fontSize(11).fontColor(this.theme.diffDeletedForeground).fontWeight(FontWeight.Medium).margin({ left: 8, right: 8 })
      Text(` ~${this.session.diffResult!.stats.modifiedCount}`).fontSize(11).fontColor(this.theme.diffModifiedForeground).fontWeight(FontWeight.Medium)
      Text(`  ${this.session.diffResult!.stats.similarityPercent}%`).fontSize(11).fontColor(this.theme.textSecondary).layoutWeight(1)
      Text(`${this.session.diffBlocks.length}块`).fontSize(11).fontColor(this.theme.textSecondary)
    }.width('100%').height(30).padding({ left: 12, right: 12 }).backgroundColor(this.theme.surfaceBackground).border({ width: { bottom: 1 }, color: this.theme.dividerColor })
  }

  // ==================== 状态同步 ====================

  private runDiffAndSync(): void {
    this.session.textA = this.textA; this.session.textB = this.textB;
    this.session.runTextDiff();
    this.syncStateFromSession();
    if (this.session.lastError) AlertDialog.show({ title: 'Diff 执行失败', message: this.session.lastError, autoCancel: true, confirm: { value: '确定', action: () => {} } });
  }

  private syncStateFromSession(): void {
    if (!this.session?.diffResult) return;
    const L = this.session.diffResult.leftLines, R = this.session.diffResult.rightLines;
    const len = Math.max(L.length, R.length);
    const pairs: SbsPair[] = [];
    for (let i = 0; i < len; i++) {
      const l = L[i], r = R[i];
      const lt = l ? l.type : 0, rt = r ? r.type : 0;
      pairs.push({
        leftType: lt, leftContent: l ? l.content : '', leftLineNo: l ? l.lineNumberA : -1,
        rightType: rt, rightContent: r ? r.content : '', rightLineNo: r ? r.lineNumberB : -1,
        isLeftBlockStart: (lt === 2 || lt === 3) && (i === 0 || (L[i - 1] ? L[i - 1].type !== lt : true)),
        isRightBlockStart: (rt === 1 || rt === 3) && (i === 0 || (R[i - 1] ? R[i - 1].type !== rt : true))
      });
    }
    this.sbsSource.setItems(pairs);
    this.navIdx = this.session.highlightBlockIndex >= 0 ? this.session.highlightBlockIndex : 0;
  }

  private syncBothAfterEdit(): void {
    this.textA = this.session.textA; this.textB = this.session.textB;
    this.syncStateFromSession();
  }

  private scrollToBlock(idx: number): void {
    if (idx < 0 || idx >= this.session.diffBlocks.length) return;
    this.scroller.scrollToIndex(this.session.diffBlocks[idx].startIndex, true);
    this.navIdx = idx;
  }

  private toggleSearch(): void { this.session.searchVisible ? this.session.hideSearch() : this.session.showSearch(); }

  private pasteSample(): void {
    this.session.textA = SampleDataProvider.getSampleA(); this.session.textB = SampleDataProvider.getSampleB();
    this.textA = this.session.textA; this.textB = this.session.textB;
    this.syncSessionOptions(); this.session.runTextDiff(); this.syncStateFromSession();
  }

  private exportDiff(): void {
    if (!this.session.diffResult) return;
    const t = this.session.generateUnifiedDiff();
    if (!t) return;
    this.session.copyToClipboard(t, (): void => { AlertDialog.show({ title: '导出成功', message: `${this.session.diffBlocks.length}个差异块 → 已复制到剪贴板`, autoCancel: true }); });
  }

  private pickFileA(): void {
    try {
      let ctx = getContext(this);
      new picker.DocumentViewPicker(ctx).select({ maxSelectNumber: 1 } as picker.DocumentSelectOptions).then((uris: string[]) => {
        if (uris.length > 0) {
          const r = FileContentService.readFileContent(uris[0]);
          this.session.textA = r.content; this.textA = r.content; this.session.fileNameA = r.fileName;
          if (r.error) AlertDialog.show({ title: '提示', message: r.error, autoCancel: true });
          if (this.session.textA.length > 0 && this.session.textB.length > 0) { this.syncSessionOptions(); this.runDiffAndSync(); }
        }
      }).catch(() => {});
    } catch (e) {}
  }

  private pickFileB(): void {
    try {
      let ctx = getContext(this);
      new picker.DocumentViewPicker(ctx).select({ maxSelectNumber: 1 } as picker.DocumentSelectOptions).then((uris: string[]) => {
        if (uris.length > 0) {
          const r = FileContentService.readFileContent(uris[0]);
          this.session.textB = r.content; this.textB = r.content; this.session.fileNameB = r.fileName;
          if (r.error) AlertDialog.show({ title: '提示', message: r.error, autoCancel: true });
          if (this.session.textA.length > 0 && this.session.textB.length > 0) { this.syncSessionOptions(); this.runDiffAndSync(); }
        }
      }).catch(() => {});
    } catch (e) {}
  }

  private saveDiffToFile(): void {
    const t = this.session.generateUnifiedDiff();
    if (!t) { AlertDialog.show({ title: '无差异', message: '请先执行对比', autoCancel: true }); return; }
    try {
      let ctx = getContext(this);
      let fp = new picker.DocumentViewPicker(ctx);
      fp.save({ newFileNames: ['diff_output.patch'] } as picker.DocumentSaveOptions).then((uris: string[]) => {
        if (uris.length > 0) {
          try { let f = fs.openSync(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE); fs.writeSync(f.fd, t); fs.closeSync(f); AlertDialog.show({ title: '保存成功', message: '差异已保存', autoCancel: true }); } catch (_) { AlertDialog.show({ title: '保存失败', message: '', autoCancel: true }); }
        }
      });
    } catch (_) {}
  }
}
