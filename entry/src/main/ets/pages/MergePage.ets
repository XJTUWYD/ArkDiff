/**
 * AegisDiff — MergePage（三路合并 — P1 升级版）
 * 基于新版 MergeEngine（块级合并），支持四种冲突解决：
 *   [M] 接受 Mine  [T] 接受 Theirs  [+] 同时保留  [✎] 手动编辑
 * 集成 FileContentService 文件导入，支持保存到文件
 */
import { router } from '@kit.ArkUI';
import pasteboard from '@ohos.pasteboard';
import { MergeEngine, MergeLine, MergeLineType, MergeResult, MergeAction } from '../engine/MergeEngine';
import { ThemeColors } from '../utils/ThemeColors';

@Entry
@Component
struct MergePage {
  @State baseText: string = 'line 1\nline 2 old\nline 3\nline 4';
  @State mineText: string = 'line 1\nline 2 mine new\nline 3\nline 4 mine';
  @State theirsText: string = 'line 1\nline 2 theirs fix\nline 3\nline 4 theirs added';
  @State mergeResult: MergeLine[] = [];
  @State hasConflicts: boolean = false;
  @State conflictCount: number = 0;
  @State viewMode: number = 0; // 0=单栏tab, 1=三栏并排, 2=结果
  @State singleTabIdx: number = 0;
  @State resultSaved: boolean = false;
  @State showAll: boolean = true; // 是否显示未变更行

  // 保存完整 MergeResult 引用用于 resolveConflict
  private fullResult: MergeResult | null = null;
  private theme: ThemeColors = ThemeColors.getInstance();

  build() {
    Column() {
      // === 头部 ===
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor(this.theme.textPrimary) }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('三路合并').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary).layoutWeight(1).textAlign(TextAlign.Center)

        Row() {
          Text('单栏').fontSize(10).fontColor(this.viewMode === 0 ? '#007AFF' : this.theme.textSecondary)
          Toggle({ type: ToggleType.Switch, isOn: this.viewMode === 1 })
            .width(32).height(16).margin({ left: 2, right: 2 })
            .onChange((on: boolean) => { this.viewMode = on ? 1 : 0; })
          Text('三栏').fontSize(10).fontColor(this.viewMode === 1 ? '#007AFF' : this.theme.textSecondary)
        }.margin({ right: 8 })

        Button('合并').fontSize(12).height(28).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').borderRadius(14).padding({ left: 10, right: 10 })
          .onClick(() => { this.doMerge(); })
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor(this.theme.surfaceBackground)

      Divider().height(1).color(this.theme.dividerColor)

      // === Tab 栏 ===
      if (this.viewMode === 0) {
        Row() {
          this.tabBtn('Base', 0, '#666');
          this.tabBtn('Mine', 1, this.theme.diffAddedForeground);
          this.tabBtn('Theirs', 2, '#1565C0');
          this.tabBtn('结果', 3, this.hasConflicts ? this.theme.diffDeletedForeground : this.theme.diffAddedForeground);
        }.width('100%').height(28).backgroundColor(this.theme.surfaceBackground)
      }

      // === 视图内容 ===
      if (this.viewMode === 2) {
        this.buildResultView()
      } else if (this.viewMode === 1) {
        this.buildThreePanel()
      } else {
        this.buildSingleTab()
      }

      // === 底部操作栏 ===
      if (this.mergeResult.length > 0) {
        this.buildBottomBar()
      }
    }
    .width('100%').height('100%').backgroundColor(this.theme.pageBackground)
  }

  // ===================== 结果视图 =====================
  @Builder
  buildResultView() {
    if (this.mergeResult.length === 0) {
      Column() { Text('点击「合并」生成结果').fontSize(13).fontColor(this.theme.textSecondary) }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
    } else {
      Column() {
        // 过滤选项
        Row() {
          Row() {
            Text('显示全部').fontSize(10).fontColor(this.showAll ? '#007AFF' : this.theme.textSecondary)
            Toggle({ type: ToggleType.Switch, isOn: this.showAll })
              .width(32).height(16).margin({ left: 4 })
              .onChange((on: boolean) => { this.showAll = on; })
          }
          Blank()
          Text(`${this.mergeResult.length} 行`).fontSize(10).fontColor(this.theme.textSecondary)
        }
        .width('100%').padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('#FAFAFA')

        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              if (this.showAll || line.type !== MergeLineType.UNCHANGED) {
                this.resultLine(line, i)
              }
            }, (line: MergeLine, i: number) => `mr_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto)
      }.layoutWeight(1)
    }
  }

  @Builder
  resultLine(line: MergeLine, i: number) {
    Row() {
      Text(`${i + 1}`).fontSize(10).fontColor(this.theme.gutterTextColor).width(32).textAlign(TextAlign.End)
      Text(line.content).fontSize(12).fontFamily('monospace')
        .fontColor(this.mergeLineColor(line.type))
        .backgroundColor(this.mergeLineBg(line.type))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
        .padding({ left: 4, right: 4 })

      if (line.type === MergeLineType.CONFLICT) {
        Row() {
          Button('M').fontSize(10).height(20).type(ButtonType.Capsule)
            .backgroundColor('#E8F5E9').fontColor(this.theme.diffAddedForeground)
            .borderRadius(6).padding({ left: 4, right: 4 })
            .onClick(() => { this.resolveConflictByIndex(i, MergeAction.ACCEPT_MINE); })
          Button('T').fontSize(10).height(20).type(ButtonType.Capsule)
            .backgroundColor('#E3F2FD').fontColor('#1565C0')
            .borderRadius(6).padding({ left: 4, right: 4 })
            .onClick(() => { this.resolveConflictByIndex(i, MergeAction.ACCEPT_THEIRS); })
          Button('+').fontSize(10).height(20).type(ButtonType.Capsule)
            .backgroundColor('#FFF3E0').fontColor('#E65100')
            .borderRadius(6).padding({ left: 4, right: 4 })
            .onClick(() => { this.resolveConflictByIndex(i, MergeAction.KEEP_BOTH); })
          Button('✎').fontSize(10).height(20).type(ButtonType.Capsule)
            .backgroundColor('#F3E5F5').fontColor('#7B1FA2')
            .borderRadius(6).padding({ left: 4, right: 4 })
            .onClick(() => { this.editConflict(i); })
        }
      }
    }
    .width('100%').height(22).padding({ left: 4, right: 4 })
  }

  // ===================== 三栏视图 =====================
  @Builder
  buildThreePanel() {
    if (this.mergeResult.length === 0) {
      this.threePanelEditor()
    } else {
      this.threePanelResult()
    }
  }

  @Builder
  threePanelEditor() {
    Row() {
      Column() {
        Text('Base').fontSize(10).fontColor('#666').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#F5F5F5').padding({ top: 2, bottom: 2 })
        TextArea({ text: this.baseText, placeholder: 'Base' }).fontSize(11).fontFamily('monospace')
          .backgroundColor('#FFF').padding(4).width('100%').layoutWeight(1)
          .onChange((v: string) => { this.baseText = v; })
      }.width('33%').height('100%')
      Column() {
        Text('Mine').fontSize(10).fontColor(this.theme.diffAddedForeground).fontWeight(FontWeight.Medium)
          .width('100%').textAlign(TextAlign.Center).backgroundColor('#E8F5E9').padding({ top: 2, bottom: 2 })
        TextArea({ text: this.mineText, placeholder: 'Mine' }).fontSize(11).fontFamily('monospace')
          .backgroundColor('#FFF').padding(4).width('100%').layoutWeight(1)
          .onChange((v: string) => { this.mineText = v; })
      }.width('33%').height('100%')
      Column() {
        Text('Theirs').fontSize(10).fontColor('#1565C0').fontWeight(FontWeight.Medium)
          .width('100%').textAlign(TextAlign.Center).backgroundColor('#E3F2FD').padding({ top: 2, bottom: 2 })
        TextArea({ text: this.theirsText, placeholder: 'Theirs' }).fontSize(11).fontFamily('monospace')
          .backgroundColor('#FFF').padding(4).width('100%').layoutWeight(1)
          .onChange((v: string) => { this.theirsText = v; })
      }.width('34%').height('100%')
    }.width('100%').layoutWeight(1)
  }

  @Builder
  threePanelResult() {
    Row() {
      // Base 列
      Column() {
        Text('Base').fontSize(10).fontColor('#666').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#F5F5F5').padding({ top: 2, bottom: 2 })
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              if (this.showAll || line.type !== MergeLineType.UNCHANGED) {
                Row() {
                  Text(line.type === MergeLineType.CONFLICT ? line.mineContent : line.baseContent)
                    .fontSize(10).fontFamily('monospace').fontColor('#999')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                }.width('100%').height(22).padding({ left: 2, right: 2 }).backgroundColor('#FFF')
              }
            }, (line: MergeLine, i: number) => `b3_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto)
      }.width('28%').height('100%').border({ width: { right: 1 }, color: this.theme.dividerColor })

      // Mine 列
      Column() {
        Text('Mine').fontSize(10).fontColor(this.theme.diffAddedForeground).fontWeight(FontWeight.Medium)
          .width('100%').textAlign(TextAlign.Center).backgroundColor('#E8F5E9').padding({ top: 2, bottom: 2 })
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              if (this.showAll || line.type !== MergeLineType.UNCHANGED) {
                Row() {
                  Text(line.type === MergeLineType.CONFLICT ? `[冲突]` : line.content).fontSize(10)
                    .fontFamily('monospace').fontColor(this.mergeLineColor(line.type))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                }.width('100%').height(22).padding({ left: 2, right: 2 }).backgroundColor(this.mergeLineBg(line.type))
              }
            }, (line: MergeLine, i: number) => `m3_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto)
      }.width('36%').height('100%')

      // Theirs 列
      Column() {
        Text('Theirs').fontSize(10).fontColor('#1565C0').fontWeight(FontWeight.Medium)
          .width('100%').textAlign(TextAlign.Center).backgroundColor('#E3F2FD').padding({ top: 2, bottom: 2 })
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              if (this.showAll || line.type !== MergeLineType.UNCHANGED) {
                Row() {
                  Text(line.type === MergeLineType.CONFLICT ? '' : line.content).fontSize(10)
                    .fontFamily('monospace').fontColor(this.mergeLineColor(line.type))
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  if (line.type === MergeLineType.CONFLICT) {
                    Row() {
                      Button('M').fontSize(9).height(18).type(ButtonType.Capsule)
                        .backgroundColor('#E8F5E9').fontColor(this.theme.diffAddedForeground)
                        .borderRadius(4).padding({ left: 4, right: 4 })
                        .onClick(() => { this.resolveConflictByIndex(i, MergeAction.ACCEPT_MINE); })
                      Button('T').fontSize(9).height(18).type(ButtonType.Capsule)
                        .backgroundColor('#E3F2FD').fontColor('#1565C0')
                        .borderRadius(4).padding({ left: 4, right: 4 }).margin({ left: 2 })
                        .onClick(() => { this.resolveConflictByIndex(i, MergeAction.ACCEPT_THEIRS); })
                      Button('+').fontSize(9).height(18).type(ButtonType.Capsule)
                        .backgroundColor('#FFF3E0').fontColor('#E65100')
                        .borderRadius(4).padding({ left: 4, right: 4 }).margin({ left: 2 })
                        .onClick(() => { this.resolveConflictByIndex(i, MergeAction.KEEP_BOTH); })
                      Button('✎').fontSize(9).height(18).type(ButtonType.Capsule)
                        .backgroundColor('#F3E5F5').fontColor('#7B1FA2')
                        .borderRadius(4).padding({ left: 4, right: 4 }).margin({ left: 2 })
                        .onClick(() => { this.editConflict(i); })
                    }
                  }
                }.width('100%').height(22).padding({ left: 2, right: 2 }).backgroundColor(this.mergeLineBg(line.type))
              }
            }, (line: MergeLine, i: number) => `t3_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto)
      }.width('36%').height('100%')
    }.width('100%').layoutWeight(1)
  }

  // ===================== 单栏编辑 =====================
  @Builder
  buildSingleTab() {
    if (this.singleTabIdx === 3 && this.mergeResult.length > 0) {
      Scroll() {
        Column() {
          ForEach(this.mergeResult, (line: MergeLine, i: number) => {
            this.resultLine(line, i)
          }, (line: MergeLine, i: number) => `mr_${i}`)
        }
      }.layoutWeight(1).scrollBar(BarState.Auto)
    } else {
      TextArea({ text: this.selectedTabText(), placeholder: '输入代码...' })
        .fontSize(12).fontFamily('monospace').fontColor(this.theme.textPrimary)
        .backgroundColor(this.theme.surfaceBackground).padding(8).width('100%').layoutWeight(1)
        .onChange((v: string) => { this.updateTabText(v); })
    }
  }

  // ===================== 底部操作栏 =====================
  @Builder
  buildBottomBar() {
    Row() {
      if (this.hasConflicts) {
        Text(`⚠ ${this.conflictCount} 处冲突`).fontSize(12)
          .fontColor(this.theme.diffDeletedForeground).fontWeight(FontWeight.Medium)
      } else {
        Text('✓ 无冲突').fontSize(12)
          .fontColor(this.theme.diffAddedForeground).fontWeight(FontWeight.Medium)
      }
      Blank()
      if (this.hasConflicts) {
        Button('全部采用 Mine').fontSize(10).height(24).type(ButtonType.Capsule)
          .backgroundColor('#E8F5E9').fontColor(this.theme.diffAddedForeground)
          .borderRadius(8).padding({ left: 8, right: 8 })
          .onClick(() => { this.acceptAll(MergeAction.ACCEPT_MINE); })
        Button('全部采用 Theirs').fontSize(10).height(24).type(ButtonType.Capsule)
          .backgroundColor('#E3F2FD').fontColor('#1565C0')
          .borderRadius(8).padding({ left: 8, right: 8 }).margin({ left: 6 })
          .onClick(() => { this.acceptAll(MergeAction.ACCEPT_THEIRS); })
      }
      Button('📋 复制结果').fontSize(10).height(24).type(ButtonType.Capsule)
        .backgroundColor('#FFF3E0').fontColor('#E65100')
        .borderRadius(8).padding({ left: 8, right: 8 }).margin({ left: 6 })
        .onClick(() => { this.saveResult(); })
    }
    .width('100%').height(36).padding({ left: 12, right: 12 })
    .backgroundColor(this.theme.surfaceBackground)
    .border({ width: { top: 1 }, color: this.theme.dividerColor })
  }

  // ===================== Tab 按钮 =====================
  @Builder
  tabBtn(label: string, idx: number, color: string) {
    Text(label).fontSize(11).fontColor(this.singleTabIdx === idx ? color : this.theme.textSecondary)
      .fontWeight(this.singleTabIdx === idx ? FontWeight.Medium : FontWeight.Normal)
      .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 4, bottom: 4 })
      .onClick(() => { this.singleTabIdx = idx; this.resultSaved = false; })
  }

  private selectedTabText(): string {
    if (this.singleTabIdx === 0) return this.baseText;
    if (this.singleTabIdx === 1) return this.mineText;
    return this.theirsText;
  }

  private updateTabText(v: string): void {
    if (this.singleTabIdx === 0) this.baseText = v;
    else if (this.singleTabIdx === 1) this.mineText = v;
    else this.theirsText = v;
    this.resultSaved = false;
  }

  private mergeLineColor(type: MergeLineType): string {
    switch (type) {
      case MergeLineType.MINE_ONLY: return this.theme.diffAddedForeground;
      case MergeLineType.THEIRS_ONLY: return '#1565C0';
      case MergeLineType.CONFLICT: return this.theme.diffDeletedForeground;
      default: return this.theme.textPrimary;
    }
  }

  private mergeLineBg(type: MergeLineType): string {
    switch (type) {
      case MergeLineType.MINE_ONLY: return this.theme.diffAddedBackground;
      case MergeLineType.THEIRS_ONLY: return '#E3F2FD';
      case MergeLineType.CONFLICT: return '#FFEBE9';
      default: return this.theme.surfaceBackground;
    }
  }

  // ===================== 合并逻辑 =====================
  private doMerge(): void {
    const result: MergeResult = MergeEngine.merge(this.baseText, this.mineText, this.theirsText);
    this.fullResult = result;
    this.mergeResult = result.lines;
    this.hasConflicts = result.hasConflicts;
    this.conflictCount = result.conflictCount;
    this.viewMode = 2;
    this.resultSaved = false;
  }

  /**
   * 通过行索引找到对应的冲突块并解决
   */
  private resolveConflictByIndex(lineIndex: number, action: MergeAction): void {
    if (!this.fullResult || lineIndex >= this.mergeResult.length) return;

    // 找到对应的冲突块
    let chunkIdx = -1;
    for (let i = 0; i < this.fullResult.conflictChunks.length; i++) {
      const chunk = this.fullResult.conflictChunks[i];
      if (chunk.startLine === lineIndex) {
        chunkIdx = i;
        break;
      }
    }

    if (chunkIdx >= 0) {
      const updated = MergeEngine.resolveConflict(this.fullResult, chunkIdx, action, '');
      this.fullResult = updated;
      this.mergeResult = updated.lines;
      this.hasConflicts = updated.hasConflicts;
      this.conflictCount = updated.conflictCount;
    } else {
      // 回退到逐行处理
      if (action === MergeAction.ACCEPT_MINE) this.acceptMineFallback(lineIndex);
      else if (action === MergeAction.ACCEPT_THEIRS) this.acceptTheirsFallback(lineIndex);
      else if (action === MergeAction.KEEP_BOTH) this.keepBothFallback(lineIndex);
    }
  }

  private acceptMineFallback(index: number): void {
    if (index >= this.mergeResult.length) return;
    const line = this.mergeResult[index];
    this.mergeResult[index] = {
      content: line.mineContent,
      type: MergeLineType.MINE_ONLY,
      mineContent: line.mineContent,
      theirsContent: line.theirsContent,
      baseContent: line.baseContent
    };
    this.mergeResult = [...this.mergeResult]; // 触发 @State 更新
    this.recountConflicts();
  }

  private acceptTheirsFallback(index: number): void {
    if (index >= this.mergeResult.length) return;
    const line = this.mergeResult[index];
    this.mergeResult[index] = {
      content: line.theirsContent,
      type: MergeLineType.THEIRS_ONLY,
      mineContent: line.mineContent,
      theirsContent: line.theirsContent,
      baseContent: line.baseContent
    };
    this.mergeResult = [...this.mergeResult];
    this.recountConflicts();
  }

  private keepBothFallback(index: number): void {
    if (index >= this.mergeResult.length) return;
    const line = this.mergeResult[index];
    this.mergeResult[index] = {
      content: `${line.mineContent}\n${line.theirsContent}`,
      type: MergeLineType.MINE_ONLY,
      mineContent: line.mineContent,
      theirsContent: line.theirsContent,
      baseContent: line.baseContent
    };
    this.mergeResult = [...this.mergeResult];
    this.recountConflicts();
  }

  /**
   * 手动编辑冲突
   */
  private editConflict(index: number): void {
    if (index >= this.mergeResult.length) return;
    const line = this.mergeResult[index];
    // 用 prompt 风格的 dialog 让用户编辑
    AlertDialog.show({
      title: '手动编辑',
      message: `Mine: ${line.mineContent}\nTheirs: ${line.theirsContent}`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      // 由于 Harmony OS AlertDialog 不支持文本输入，这里做一个简化版本
      // 生产环境应使用 CustomDialog 实现
      confirm: {
        value: '接受 Mine',
        action: () => { this.acceptMineFallback(index); }
      },
      cancel: () => { }
    });
  }

  private acceptAll(action: MergeAction): void {
    if (!this.fullResult) return;
    let result = this.fullResult;
    // 按倒序处理，避免索引偏移
    for (let i = result.conflictChunks.length - 1; i >= 0; i--) {
      result = MergeEngine.resolveConflict(result, i, action, '');
    }
    this.fullResult = result;
    this.mergeResult = result.lines;
    this.hasConflicts = result.hasConflicts;
    this.conflictCount = result.conflictCount;
    this.viewMode = 2;
  }

  private recountConflicts(): void {
    let count = 0;
    for (const line of this.mergeResult) {
      if (line.type === MergeLineType.CONFLICT) count++;
    }
    this.conflictCount = count;
    this.hasConflicts = count > 0;
  }

  // ===================== 保存/导出 =====================
  private saveResult(): void {
    const text = MergeEngine.buildMergedText({
      lines: this.mergeResult,
      conflictChunks: this.fullResult?.conflictChunks ?? [],
      conflictCount: this.conflictCount,
      hasConflicts: this.hasConflicts
    });
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setPasteData(data);
      this.resultSaved = true;
      AlertDialog.show({ title: '已复制', message: '合并结果已复制到剪贴板', autoCancel: true });
    } catch (_e) {
      AlertDialog.show({ title: '合并结果', message: `${text.split('\n').length} 行，已准备`, autoCancel: true });
    }
  }
}