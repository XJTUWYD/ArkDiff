/**
 * AegisDiff — MergePage（三路合并 — 增强版）
 * 三栏并排视图、冲突逐行选择、Accept All、结果导出
 */
import { router } from '@kit.ArkUI';
import pasteboard from '@ohos.pasteboard';
import { MergeEngine, MergeLine, MergeLineType, MergeResult } from '../engine/MergeEngine';

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
  @State singleTabIdx: number = 0; // 单栏模式下的 tab 索引
  @State resultSaved: boolean = false;

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333') }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('三路合并').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)

        Row() {
          Text('单栏').fontSize(10).fontColor(this.viewMode === 0 ? '#007AFF' : '#999')
          Toggle({ type: ToggleType.Switch, isOn: this.viewMode === 1 }).width(32).height(16).margin({ left: 2, right: 2 })
            .onChange((on: boolean) => { this.viewMode = on ? 1 : 0; })
          Text('三栏').fontSize(10).fontColor(this.viewMode === 1 ? '#007AFF' : '#999')
        }.margin({ right: 8 })

        Button('合并').fontSize(12).height(28).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').borderRadius(14).padding({ left: 10, right: 10 })
          .onClick(() => { this.doMerge(); })
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor('#FFF')
      Divider().height(1).color('#E0E0E0')

      // ===== 视图切换 Tab（单栏模式） =====
      if (this.viewMode === 0) {
        Row() {
          this.tbutton('Base', 0, '#666'); this.tbutton('Mine', 1, '#1A7F37'); this.tbutton('Theirs', 2, '#1565C0'); this.tbutton('结果', 3, this.hasConflicts ? '#BE2E2E' : '#1A7F37')
        }.width('100%').height(28).backgroundColor('#F5F5F5')
      }

      // ===== 视图内容 =====
      if (this.viewMode === 2) {
        // 结果视图
        if (this.mergeResult.length === 0) {
          Column() { Text('点击「合并」生成结果').fontSize(13).fontColor('#999') }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column() {
              ForEach(this.mergeResult, (line: MergeLine, i: number) => {
                this.resultLine(line, i)
              }, (line: MergeLine, i: number) => `mr_${i}`)
            }
          }.layoutWeight(1).scrollBar(BarState.Auto)
        }
      } else if (this.viewMode === 1) {
        // ===== 三栏并排视图 =====
        if (this.mergeResult.length === 0) {
          this.threePanelEditor()
        } else {
          this.threePanelResult()
        }
      } else {
        // 单栏 Tab 视图
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
            .fontSize(12).fontFamily('monospace').fontColor('#1C1C1C')
            .backgroundColor('#FFF').padding(8).width('100%').layoutWeight(1)
            .onChange((v: string) => { this.updateTabText(v); })
        }
      }

      // ===== 底部操作栏 =====
      if (this.mergeResult.length > 0) {
        Row() {
          if (this.hasConflicts) {
            Text(`⚠ ${this.conflictCount} 处冲突`).fontSize(12).fontColor('#BE2E2E').fontWeight(FontWeight.Medium)
          } else {
            Text('✓ 无冲突').fontSize(12).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
          }
          Blank()
          if (this.hasConflicts) {
            Button('全部采用 Mine').fontSize(10).height(24).type(ButtonType.Capsule)
              .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(8).padding({ left: 8, right: 8 })
              .onClick(() => { this.acceptAllMine(); })
            Button('全部采用 Theirs').fontSize(10).height(24).type(ButtonType.Capsule)
              .backgroundColor('#E3F2FD').fontColor('#1565C0').borderRadius(8).padding({ left: 8, right: 8 }).margin({ left: 6 })
              .onClick(() => { this.acceptAllTheirs(); })
          }
          Button('📋 复制结果').fontSize(10).height(24).type(ButtonType.Capsule)
            .backgroundColor('#FFF3E0').fontColor('#E65100').borderRadius(8).padding({ left: 8, right: 8 }).margin({ left: 6 })
            .onClick(() => { this.saveResult(); })
        }
        .width('100%').height(36).padding({ left: 12, right: 12 })
        .backgroundColor('#FFF').border({ width: { top: 1 }, color: '#E0E0E0' })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  // ===================== 三栏编辑器（编辑模式下并排显示输入） =====================
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
        Text('Mine').fontSize(10).fontColor('#1A7F37').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#E8F5E9').padding({ top: 2, bottom: 2 })
        TextArea({ text: this.mineText, placeholder: 'Mine' }).fontSize(11).fontFamily('monospace')
          .backgroundColor('#FFF').padding(4).width('100%').layoutWeight(1)
          .onChange((v: string) => { this.mineText = v; })
      }.width('33%').height('100%')
      Column() {
        Text('Theirs').fontSize(10).fontColor('#1565C0').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#E3F2FD').padding({ top: 2, bottom: 2 })
        TextArea({ text: this.theirsText, placeholder: 'Theirs' }).fontSize(11).fontFamily('monospace')
          .backgroundColor('#FFF').padding(4).width('100%').layoutWeight(1)
          .onChange((v: string) => { this.theirsText = v; })
      }.width('34%').height('100%')
    }.width('100%').layoutWeight(1)
  }

  // ===================== 三栏结果（合并后并排对比） =====================
  @Builder
  threePanelResult() {
    Row() {
      // Base 栏
      Column() {
        Text('Base').fontSize(10).fontColor('#666').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#F5F5F5').padding({ top: 2, bottom: 2 })
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              Row() {
                Text(line.type === MergeLineType.CONFLICT ? line.mineContent : '').fontSize(10).fontFamily('monospace')
                  .fontColor('#999').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              }.width('100%').height(22).padding({ left: 2, right: 2 }).backgroundColor('#FFF')
            }, (line: MergeLine, i: number) => `b3_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto).onClick(() => { this.viewMode = 2; })
      }.width('28%').height('100%').border({ width: { right: 1 }, color: '#E0E0E0' })

      // Mine 栏
      Column() {
        Text('Mine').fontSize(10).fontColor('#1A7F37').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#E8F5E9').padding({ top: 2, bottom: 2 })
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              Row() {
                Text(line.type === MergeLineType.CONFLICT ? `[冲突${i + 1}]` : line.content)
                  .fontSize(10).fontFamily('monospace').fontColor(this.lineColor(line.type))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
              }.width('100%').height(22).padding({ left: 2, right: 2 }).backgroundColor(this.lineBg(line.type))
            }, (line: MergeLine, i: number) => `m3_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto)
      }.width('36%').height('100%')

      // Theirs 栏
      Column() {
        Text('Theirs').fontSize(10).fontColor('#1565C0').fontWeight(FontWeight.Medium).width('100%')
          .textAlign(TextAlign.Center).backgroundColor('#E3F2FD').padding({ top: 2, bottom: 2 })
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              Row() {
                Text(line.type === MergeLineType.CONFLICT ? '' : line.content).fontSize(10).fontFamily('monospace')
                  .fontColor(this.lineColor(line.type)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                if (line.type === MergeLineType.CONFLICT) {
                  Row() {
                    Button('M').fontSize(9).height(18).type(ButtonType.Capsule)
                      .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(4).padding({ left: 4, right: 4 })
                      .onClick(() => { this.acceptMine(i); })
                    Button('T').fontSize(9).height(18).type(ButtonType.Capsule)
                      .backgroundColor('#E3F2FD').fontColor('#1565C0').borderRadius(4).padding({ left: 4, right: 4 }).margin({ left: 2 })
                      .onClick(() => { this.acceptTheirs(i); })
                  }
                }
              }.width('100%').height(22).padding({ left: 2, right: 2 }).backgroundColor(this.lineBg(line.type))
            }, (line: MergeLine, i: number) => `t3_${i}`)
          }
        }.layoutWeight(1).scrollBar(BarState.Auto)
      }.width('36%').height('100%')
    }.width('100%').layoutWeight(1)
  }

  // ===================== 结果视图 =====================
  @Builder resultLine(line: MergeLine, i: number) {
    Row() {
      Text(`${i + 1}`).fontSize(10).fontColor('#999').width(30).textAlign(TextAlign.End)
      Text(line.content).fontSize(12).fontFamily('monospace').fontColor(this.lineColor(line.type))
        .backgroundColor(this.lineBg(line.type)).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
      if (line.type === MergeLineType.CONFLICT) {
        Row() {
          Button('M').fontSize(10).height(20).type(ButtonType.Capsule)
            .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(6).padding({ left: 4, right: 4 })
            .onClick(() => { this.acceptMine(i); })
          Button('T').fontSize(10).height(20).type(ButtonType.Capsule)
            .backgroundColor('#E3F2FD').fontColor('#1565C0').borderRadius(6).padding({ left: 4, right: 4 })
            .onClick(() => { this.acceptTheirs(i); })
        }
      }
    }.width('100%').height(22).padding({ left: 4, right: 4 })
  }

  // ===================== Tab 按钮 =====================
  @Builder tbutton(label: string, idx: number, color: string) {
    Text(label).fontSize(11).fontColor(this.singleTabIdx === idx ? color : '#999')
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

  private lineColor(type: MergeLineType): string {
    switch (type) {
      case MergeLineType.MINE_ONLY: return '#1A7F37';
      case MergeLineType.THEIRS_ONLY: return '#1565C0';
      case MergeLineType.CONFLICT: return '#BE2E2E';
      default: return '#1C1C1C';
    }
  }

  private lineBg(type: MergeLineType): string {
    switch (type) {
      case MergeLineType.MINE_ONLY: return '#E6FFEC';
      case MergeLineType.THEIRS_ONLY: return '#E3F2FD';
      case MergeLineType.CONFLICT: return '#FFEBE9';
      default: return '#FFF';
    }
  }

  // ===================== 合并逻辑 =====================
  private doMerge(): void {
    const result: MergeResult = MergeEngine.merge(this.baseText, this.mineText, this.theirsText);
    this.mergeResult = result.lines;
    this.hasConflicts = result.hasConflicts;
    this.conflictCount = result.conflictCount;
    this.viewMode = 2;
    this.resultSaved = false;
  }

  private acceptMine(index: number): void {
    if (index >= this.mergeResult.length) return;
    const line = this.mergeResult[index];
    this.mergeResult[index] = { content: line.mineContent, type: MergeLineType.MINE_ONLY, mineContent: line.mineContent, theirsContent: line.theirsContent };
    this.recountConflicts();
  }

  private acceptTheirs(index: number): void {
    if (index >= this.mergeResult.length) return;
    const line = this.mergeResult[index];
    this.mergeResult[index] = { content: line.theirsContent, type: MergeLineType.THEIRS_ONLY, mineContent: line.mineContent, theirsContent: line.theirsContent };
    this.recountConflicts();
  }

  private acceptAllMine(): void {
    for (let i = 0; i < this.mergeResult.length; i++) {
      if (this.mergeResult[i].type === MergeLineType.CONFLICT) this.acceptMine(i);
    }
    this.viewMode = 2;
  }

  private acceptAllTheirs(): void {
    for (let i = 0; i < this.mergeResult.length; i++) {
      if (this.mergeResult[i].type === MergeLineType.CONFLICT) this.acceptTheirs(i);
    }
    this.viewMode = 2;
  }

  private recountConflicts(): void {
    let count = 0;
    for (const line of this.mergeResult) { if (line.type === MergeLineType.CONFLICT) count++; }
    this.conflictCount = count;
    this.hasConflicts = count > 0;
  }

  // ===================== 保存/导出结果 =====================
  private saveResult(): void {
    const lines: string[] = [];
    for (const line of this.mergeResult) lines.push(line.content);
    const text = lines.join('\n');
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setPasteData(data);
      this.resultSaved = true;
      AlertDialog.show({ title: '已复制', message: '合并结果已复制到剪贴板', autoCancel: true });
    } catch (_e) {
      AlertDialog.show({ title: '合并结果', message: `${lines.length} 行，已准备`, autoCancel: true });
    }
  }
}
