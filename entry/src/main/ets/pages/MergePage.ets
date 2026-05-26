/**
 * AegisDiff — MergePage（三路合并）
 * 使用 MergeEngine 进行 Base/Mine/Theirs 三路合并
 */
import { router } from '@kit.ArkUI';
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
  @State selectedTab: number = 0; // 0=base, 1=mine, 2=theirs, 3=result

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333333') }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('三路合并').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)

        Button('合并')
          .fontSize(12).height(28).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').borderRadius(14)
          .padding({ left: 10, right: 10 })
          .onClick(() => { this.doMerge(); })
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor('#FFFFFF')

      Divider().height(1).color('#E0E0E0')

      Row() {
        this.tabButton('Base', 0)
        this.tabButton('Mine', 1)
        this.tabButton('Theirs', 2)
        this.tabButton('结果', 3)
      }
      .width('100%').height(28).backgroundColor('#F5F5F5')

      if (this.selectedTab === 3) {
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: MergeLine, i: number) => {
              this.mergeResultLine(line, i)
            }, (line: MergeLine, i: number) => `mr_${i}`)
          }
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      } else {
        TextArea({ text: this.selectedTab === 0 ? this.baseText : this.selectedTab === 1 ? this.mineText : this.theirsText,
          placeholder: '输入代码...' })
          .fontSize(12).fontFamily('monospace').fontColor('#1C1C1C')
          .backgroundColor('#FFFFFF').padding(8)
          .width('100%').layoutWeight(1)
          .onChange((v: string) => {
            if (this.selectedTab === 0) this.baseText = v;
            else if (this.selectedTab === 1) this.mineText = v;
            else this.theirsText = v;
          })
      }

      if (this.mergeResult.length > 0) {
        Row() {
          if (this.hasConflicts) {
            Text(`⚠ ${this.conflictCount} 处冲突`).fontSize(12).fontColor('#BE2E2E').fontWeight(FontWeight.Medium)
          } else {
            Text('✓ 无冲突，已自动合并').fontSize(12).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
          }
        }
        .width('100%').height(32).justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF').border({ width: { top: 1 }, color: '#E0E0E0' })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  @Builder
  tabButton(label: string, tabIdx: number) {
    Text(label)
      .fontSize(11)
      .fontColor(this.selectedTab === tabIdx ? '#007AFF' : '#999999')
      .fontWeight(this.selectedTab === tabIdx ? FontWeight.Medium : FontWeight.Normal)
      .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 4, bottom: 4 })
      .onClick(() => { this.selectedTab = tabIdx; })
  }

  @Builder
  mergeResultLine(line: MergeLine, i: number) {
    Row() {
      Text(`${i + 1}`).fontSize(10).fontColor('#999999').width(30).textAlign(TextAlign.End)
      Text(line.content)
        .fontSize(12).fontFamily('monospace')
        .fontColor(this.getLineColor(line.type))
        .backgroundColor(this.getLineBg(line.type))
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
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

  private getLineColor(type: MergeLineType): string {
    switch (type) {
      case MergeLineType.MINE_ONLY: return '#1A7F37';
      case MergeLineType.THEIRS_ONLY: return '#1565C0';
      case MergeLineType.CONFLICT: return '#BE2E2E';
      default: return '#1C1C1C';
    }
  }

  private getLineBg(type: MergeLineType): string {
    switch (type) {
      case MergeLineType.MINE_ONLY: return '#E6FFEC';
      case MergeLineType.THEIRS_ONLY: return '#E3F2FD';
      case MergeLineType.CONFLICT: return '#FFEBE9';
      default: return '#FFFFFF';
    }
  }

  private doMerge(): void {
    const result: MergeResult = MergeEngine.merge(this.baseText, this.mineText, this.theirsText);
    this.mergeResult = result.lines;
    this.hasConflicts = result.hasConflicts;
    this.conflictCount = result.conflictCount;
    this.selectedTab = 3;
  }

  private acceptMine(index: number): void {
    if (index < this.mergeResult.length) {
      const line = this.mergeResult[index];
      this.mergeResult[index] = {
        content: line.mineContent,
        type: MergeLineType.MINE_ONLY,
        mineContent: line.mineContent,
        theirsContent: line.theirsContent
      };
      this.recountConflicts();
    }
  }

  private acceptTheirs(index: number): void {
    if (index < this.mergeResult.length) {
      const line = this.mergeResult[index];
      this.mergeResult[index] = {
        content: line.theirsContent,
        type: MergeLineType.THEIRS_ONLY,
        mineContent: line.mineContent,
        theirsContent: line.theirsContent
      };
      this.recountConflicts();
    }
  }

  private recountConflicts(): void {
    let count = 0;
    for (const line of this.mergeResult) {
      if (line.type === MergeLineType.CONFLICT) count++;
    }
    this.conflictCount = count;
    this.hasConflicts = count > 0;
  }
}
