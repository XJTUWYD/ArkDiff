/**
 * AegisDiff — MergePage（三路合并）
 */
import { router } from '@kit.ArkUI';

@Entry
@Component
struct MergePage {
  @State baseText: string = 'line 1\nline 2 old\nline 3\nline 4';
  @State mineText: string = 'line 1\nline 2 mine new\nline 3\nline 4 mine';
  @State theirsText: string = 'line 1\nline 2 theirs fix\nline 3\nline 4 theirs added';
  @State mergeResult: string[] = [];
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
        Text('Base').fontSize(11).fontColor(this.selectedTab === 0 ? '#007AFF' : '#999999')
          .fontWeight(this.selectedTab === 0 ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1).textAlign(TextAlign.Center).padding({ top: 4, bottom: 4 })
          .onClick(() => { this.selectedTab = 0; })
        Text('Mine').fontSize(11).fontColor(this.selectedTab === 1 ? '#007AFF' : '#999999')
          .fontWeight(this.selectedTab === 1 ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => { this.selectedTab = 1; })
        Text('Theirs').fontSize(11).fontColor(this.selectedTab === 2 ? '#007AFF' : '#999999')
          .fontWeight(this.selectedTab === 2 ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => { this.selectedTab = 2; })
        Text('结果').fontSize(11).fontColor(this.selectedTab === 3 ? '#007AFF' : '#999999')
          .fontWeight(this.selectedTab === 3 ? FontWeight.Medium : FontWeight.Normal)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => { this.selectedTab = 3; })
      }
      .width('100%').height(28).backgroundColor('#F5F5F5')

      if (this.selectedTab === 3) {
        Scroll() {
          Column() {
            ForEach(this.mergeResult, (line: string, i: number) => {
              Row() {
                Text(`${i + 1}`).fontSize(10).fontColor('#999999').width(30).textAlign(TextAlign.End)
                Text(line).fontSize(12).fontFamily('monospace')
                  .fontColor(line.startsWith('<<<<<<<') ? '#BE2E2E' : line.startsWith('=======') ? '#D4A017' : line.startsWith('>>>>>>>') ? '#BE2E2E' : '#1C1C1C')
                  .backgroundColor(line.startsWith('<<<<<<<') ? '#FFEBE9' : line.startsWith('=======') ? '#FFF3D4' : line.startsWith('>>>>>>>') ? '#FFEBE9' : '#FFFFFF')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }.width('100%').height(22).padding({ left: 4 })
            }, (line: string, i: number) => `mr_${i}`)
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
            Text('✓ 无冲突，可自动合并').fontSize(12).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
          }
        }
        .width('100%').height(32).justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF').border({ width: { top: 1 }, color: '#E0E0E0' })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private doMerge(): void {
    const bl = this.baseText.split('\n');
    const ml = this.mineText.split('\n');
    const tl = this.theirsText.split('\n');
    const result: string[] = [];
    let bi = 0, mi = 0, ti = 0;
    let conflicts = 0;

    while (bi < bl.length || mi < ml.length || ti < tl.length) {
      const b = bi < bl.length ? bl[bi] : '';
      const m = mi < ml.length ? ml[mi] : '';
      const t = ti < tl.length ? tl[ti] : '';

      if (bi < bl.length && mi < ml.length && ti < tl.length &&
        b === m && b === t) {
        result.push(b); bi++; mi++; ti++;
      } else if (bi < bl.length && mi < ml.length && b === m) {
        result.push(t); bi++; mi++; ti++;
      } else if (bi < bl.length && ti < tl.length && b === t) {
        result.push(m); bi++; mi++; ti++;
      } else if (mi < ml.length && ti < tl.length && m === t) {
        result.push(m); mi++; ti++;
        if (bi < bl.length) bi++;
      } else {
        // Conflict
        conflicts++;
        result.push('<<<<<<< mine');
        while (mi < ml.length && (ti >= tl.length || ml[mi] !== tl[ti])) {
          result.push(ml[mi]); mi++;
        }
        result.push('=======');
        while (ti < tl.length && (mi >= ml.length || ml[mi] !== tl[ti])) {
          result.push(tl[ti]); ti++;
        }
        result.push('>>>>>>> theirs');
        bi++;
      }
    }

    this.mergeResult = result;
    this.hasConflicts = conflicts > 0;
    this.conflictCount = conflicts;
    this.selectedTab = 3;
  }
}
