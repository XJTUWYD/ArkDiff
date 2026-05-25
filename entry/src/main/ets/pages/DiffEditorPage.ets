import { router } from '@kit.ArkUI';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffToolbar } from '../components/DiffToolbar';
import { InputPanel } from '../components/InputPanel';
import { SampleDataProvider } from '../utils/SampleDataProvider';
import { ViewMode } from '../model/DiffModels';

@Component
struct SimpleLine {
  @Prop typeNum: number = 0;
  @Prop content: string = '';
  @Prop linenoA: number = -1;
  @Prop linenoB: number = -1;

  build() {
    Row() {
      Text(this.getPrefix()).fontSize(12).fontWeight(FontWeight.Bold)
        .fontColor(this.getPColor()).width(16).textAlign(TextAlign.Center)
      Text(this.linenoA > 0 ? `${this.linenoA}` : '').fontSize(12).fontColor('#999999').width(36).textAlign(TextAlign.End)
      Text(this.content).fontSize(13).fontFamily('monospace').fontColor('#1C1C1C')
        .maxLines(1).textOverflow({ overflow: TextOverflow.None }).padding({ left: 8, right: 8 })
    }
    .width('100%').height(24).backgroundColor(this.getBg())
  }

  private getPrefix(): string {
    if (this.typeNum === 1) return '+';
    if (this.typeNum === 2) return '-';
    if (this.typeNum === 3) return '~';
    return ' ';
  }
  private getPColor(): string {
    if (this.typeNum === 1) return '#1A7F37';
    if (this.typeNum === 2) return '#BE2E2E';
    if (this.typeNum === 3) return '#D4A017';
    return '#999999';
  }
  private getBg(): string {
    if (this.typeNum === 1) return '#E6FFEC';
    if (this.typeNum === 2) return '#FFEBE9';
    if (this.typeNum === 3) return '#FFF3D4';
    return '#FFFFFF';
  }
}

@Entry
@Component
struct DiffEditorPage {
  @State textA: string = '';
  @State textB: string = '';
  @State viewMode: ViewMode = ViewMode.UNIFIED;
  @State inputVisible: boolean = true;
  @State navIdx: number = 0;
  @State added: number = 0;
  @State deleted: number = 0;
  @State modified: number = 0;
  @State similarity: number = 0;
  @State blockCnt: number = 0;
  @State hasResult: boolean = false;
  @State lineTypes: number[] = [];
  @State lineContents: string[] = [];
  @State lineNosA: number[] = [];
  @State lineNosB: number[] = [];

  aboutToAppear(): void {
    this.textA = SampleDataProvider.getSampleA();
    this.textB = SampleDataProvider.getSampleB();
  }

  build() {
    Column() {
      DiffToolbar({
        viewMode: this.viewMode, isComputing: false,
        onRunDiff: () => { this.doDiff(); },
        onSwitchView: (m: ViewMode) => { this.viewMode = m; },
        onPasteSample: () => { this.doPaste(); },
        onOpenSettings: () => { router.pushUrl({ url: 'pages/SettingsPage' }); }
      }).width('100%').height(48)

      Divider().height(1).color('#E0E0E0')

      if (this.hasResult) {
        Row() {
          Text(`+${this.added}`).fontSize(13).fontColor('#1A7F37').fontWeight(FontWeight.Medium).margin({ right: 12 })
          Text(`-${this.deleted}`).fontSize(13).fontColor('#BE2E2E').fontWeight(FontWeight.Medium).margin({ right: 12 })
          Text(`~${this.modified}`).fontSize(13).fontColor('#D4A017').fontWeight(FontWeight.Medium).margin({ right: 16 })
          Text(`相似度 ${this.similarity}%`).fontSize(13).fontColor('#666666').layoutWeight(1)
          Text(`${this.blockCnt} 处差异`).fontSize(13).fontColor('#666666')
        }
        .width('100%').height(36).padding({ left: 16, right: 16 }).backgroundColor('#FFFFFF')
        .border({ width: { bottom: 1 }, color: '#E0E0E0' })
      }

      if (this.inputVisible) {
        InputPanel({ textA: $textA, textB: $textB }).width('100%').height(180)
      }

      if (this.hasResult && this.lineTypes.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.lineTypes, (t: number, i: number) => {
              SimpleLine({
                typeNum: t,
                content: this.lineContents[i],
                linenoA: this.lineNosA[i],
                linenoB: this.lineNosB[i]
              })
            }, (t: number, i: number) => `line_${i}`)
          }
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
      } else {
        Column() {
          Text('AegisDiff').fontSize(24).fontColor('#333333')
          Text('点击「执行对比」查看差异').fontSize(14).fontColor('#999999').margin({ top: 8 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }

      Divider().height(1).color('#E0E0E0')

      DiffNavigator({
        totalBlocks: this.blockCnt,
        currentIndex: this.navIdx,
        inputPanelVisible: this.inputVisible,
        onNavigateTo: (i: number) => { this.navIdx = i; },
        onToggleInput: () => { this.inputVisible = !this.inputVisible; }
      }).width('100%').height(40)
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private doDiff(): void {
    const a = this.textA.split('\n');
    const b = this.textB.split('\n');
    const types: number[] = [];
    const contents: string[] = [];
    const nosA: number[] = [];
    const nosB: number[] = [];
    let _added = 0, _deleted = 0, _mod = 0, _unch = 0, blk = 0, inBlk = false;
    const max = Math.max(a.length, b.length);
    for (let i = 0; i < max; i++) {
      const aEnd = i >= a.length, bEnd = i >= b.length;
      const va = aEnd ? '' : a[i];
      const vb = bEnd ? '' : b[i];
      let t: number;
      if (!aEnd && !bEnd && va === vb) { t = 0; _unch++; inBlk = false; }
      else if (!aEnd && !bEnd) { t = 3; _mod++; if (!inBlk) { blk++; inBlk = true; } }
      else if (!aEnd) { t = 2; _deleted++; if (!inBlk) { blk++; inBlk = true; } }
      else { t = 1; _added++; if (!inBlk) { blk++; inBlk = true; } }
      types.push(t);
      contents.push(aEnd ? vb : va);
      nosA.push(aEnd ? -1 : i + 1);
      nosB.push(bEnd ? -1 : i + 1);
    }
    this.lineTypes = types; this.lineContents = contents;
    this.lineNosA = nosA; this.lineNosB = nosB;
    this.added = _added; this.deleted = _deleted; this.modified = _mod;
    const total = _unch + _added + _deleted + _mod;
    this.similarity = total > 0 ? Math.round(_unch / total * 1000) / 10 : 100;
    this.blockCnt = blk; this.hasResult = true;
  }

  private doPaste(): void {
    this.textA = SampleDataProvider.getSampleA();
    this.textB = SampleDataProvider.getSampleB();
  }
}
