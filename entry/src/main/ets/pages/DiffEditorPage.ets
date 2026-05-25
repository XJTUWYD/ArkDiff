import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DiffNavigator } from '../components/DiffNavigator';
import { DiffToolbar } from '../components/DiffToolbar';
import { InputPanel } from '../components/InputPanel';
import { SampleDataProvider } from '../utils/SampleDataProvider';
import { ViewMode } from '../model/DiffModels';

@Component
struct UnifiedLine {
  @Prop typeNum: number = 0;
  @Prop content: string = '';
  @Prop linenoA: number = -1;
  @Prop linenoB: number = -1;
  @Prop searchKeyword: string = '';
  @Prop isSearchMatch: boolean = false;
  @Prop isMonokai: boolean = false;
  build() {
    Row() {
      Text(this.linenoA > 0 ? `${this.linenoA}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.linenoB > 0 ? `${this.linenoB}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
      Text(this.getPrefix()).fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.getPColor()).width(14).textAlign(TextAlign.Center)
      Text(this.content).fontSize(12).fontFamily('monospace').fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 6 })
    }.width('100%').height(22).backgroundColor(this.isSearchMatch ? (this.isMonokai ? '#49483E' : '#FFD54F') : this.getBg())
  }
  private getPrefix(): string { if (this.typeNum === 1) return '+'; if (this.typeNum === 2) return '-'; if (this.typeNum === 3) return '~'; return ' '; }
  private getPColor(): string {
    if (this.isMonokai) { if (this.typeNum === 1) return '#A6E22E'; if (this.typeNum === 2) return '#F92672'; if (this.typeNum === 3) return '#E6DB74'; return '#75715E'; }
    if (this.typeNum === 1) return '#1A7F37'; if (this.typeNum === 2) return '#BE2E2E'; if (this.typeNum === 3) return '#D4A017'; return '#CCCCCC';
  }
  private getBg(): string {
    if (this.isMonokai) { if (this.typeNum === 1) return '#232D1A'; if (this.typeNum === 2) return '#351B1B'; if (this.typeNum === 3) return '#33301A'; return '#272822'; }
    if (this.typeNum === 1) return '#E6FFEC'; if (this.typeNum === 2) return '#FFEBE9'; if (this.typeNum === 3) return '#FFF3D4'; return '#FFFFFF';
  }
}

@Component
struct SideBySideRow {
  @Prop leftType: number = 0; @Prop leftContent: string = ''; @Prop leftLineNo: number = -1;
  @Prop rightType: number = 0; @Prop rightContent: string = ''; @Prop rightLineNo: number = -1;
  @Prop isSearchMatch: boolean = false; @Prop isMonokai: boolean = false;
  onSyncToRight?: () => void;
  onSyncToLeft?: () => void;
  build() {
    Row() {
      Row() {
        Text(this.leftLineNo > 0 ? `${this.leftLineNo}` : '').fontSize(10).fontColor(this.isMonokai ? '#75715E' : '#999999').width(24).textAlign(TextAlign.End).fontFamily('monospace')
        Text(this.leftContent).fontSize(11).fontFamily('monospace').fontColor(this.isMonokai ? '#F8F8F2' : '#1C1C1C').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 4, right: 4 }).layoutWeight(1)
      }.width('46%').height(22).backgroundColor(this.isSearchMatch ? (this.isMonokai ? '#49483E' : '#FFD54F') : this.getBg(this.leftType)).padding({ right: 1 })

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
      }.width('46%').height(22).backgroundColor(this.isSearchMatch ? (this.isMonokai ? '#49483E' : '#FFD54F') : this.getBg(this.rightType)).padding({ left: 1 })
    }.width('100%').height(22)
  }
  private getBg(type: number): string {
    if (this.isMonokai) { if (type === 1) return '#232D1A'; if (type === 2) return '#351B1B'; if (type === 3) return '#33301A'; return '#272822'; }
    if (type === 1) return '#E6FFEC'; if (type === 2) return '#FFEBE9'; if (type === 3) return '#FFF3D4'; return '#FFFFFF';
  }
}

interface SbsPair { leftType: number; leftContent: string; leftLineNo: number; rightType: number; rightContent: string; rightLineNo: number; }

@Entry
@Component
struct DiffEditorPage {
  @StorageLink('colorMode') colorMode: string = 'auto';
  @StorageLink('currentBreakpoint') currentBp: string = 'sm';
  @State textA: string = ''; @State textB: string = '';
  @State viewMode: ViewMode = ViewMode.UNIFIED;
  @State inputVisible: boolean = true; @State navIdx: number = 0;
  @State added: number = 0; @State deleted: number = 0; @State modified: number = 0;
  @State similarity: number = 0; @State blockCnt: number = 0; @State hasResult: boolean = false;
  @State lineTypes: number[] = []; @State lineContents: string[] = [];
  @State lineNosA: number[] = []; @State lineNosB: number[] = [];
  @State sbsPairs: SbsPair[] = [];
  @State searchActive: boolean = false; @State searchKeyword: string = '';
  @State searchMatches: number[] = []; @State searchIdx: number = 0;
  @State fileAName: string = ''; @State fileBName: string = '';

  aboutToAppear(): void { this.textA = SampleDataProvider.getSampleA(); this.textB = SampleDataProvider.getSampleB(); }

  build() {
    Column() {
      DiffToolbar({
        viewMode: this.viewMode, isComputing: false, searchActive: false,
        onRunDiff: () => { this.doDiff(); },
        onSwitchView: (m: ViewMode) => { this.viewMode = m; },
        onPasteSample: () => { this.doPaste(); },
        onOpenSettings: () => { router.pushUrl({ url: 'pages/SettingsPage' }); },
        onToggleSearch: () => { this.searchActive = !this.searchActive; this.searchKeyword = ''; this.searchMatches = []; },
        onOpenMerge: () => { router.pushUrl({ url: 'pages/MergePage' }); }
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
          .onClick(() => { router.pushUrl({ url: 'pages/FolderDiffPage' }); })
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
        // 桌面端：输入面板与 Diff 结果左右分栏
        Row() {
          if (this.inputVisible) {
            InputPanel({ textA: $textA, textB: $textB }).width('42%').height('100%')
          }
          if (this.hasResult) {
            Scroll() {
              if (this.viewMode === ViewMode.UNIFIED) {
                Column() {
                  ForEach(this.lineTypes, (t: number, i: number) => {
                    UnifiedLine({ typeNum: t, content: this.lineContents[i], linenoA: this.lineNosA[i], linenoB: this.lineNosB[i],
                      searchKeyword: this.searchKeyword, isMonokai: this.colorMode === 'monokai',
                      isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === i
                    })
                  }, (t: number, i: number) => `u_${i}`)
                }
              } else {
                Column() {
                  ForEach(this.sbsPairs, (p: SbsPair, i: number) => {
                    SideBySideRow({
                      leftType: p.leftType, leftContent: p.leftContent, leftLineNo: p.leftLineNo,
                      rightType: p.rightType, rightContent: p.rightContent, rightLineNo: p.rightLineNo,
                      isMonokai: this.colorMode === 'monokai',
                      isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === i,
                      onSyncToRight: () => { this.syncToRight(p); },
                      onSyncToLeft: () => { this.syncToLeft(p); }
                    })
                  }, (p: SbsPair, i: number) => `s_${i}`)
                }
              }
            }.width(this.inputVisible ? '58%' : '100%').height('100%').scrollBar(BarState.Auto)
          } else {
            Column() {
              Text('AegisDiff').fontSize(22).fontColor(this.colorMode === 'monokai' ? '#F8F8F2' : '#333333')
              Text('点击执行对比查看差异').fontSize(13).fontColor('#999999').margin({ top: 8 })
            }.width('100%').height('100%').justifyContent(FlexAlign.Center)
          }
        }.width('100%').layoutWeight(1)
      } else {
        // 手机/平板：保持原有纵向堆叠布局
        if (this.inputVisible) { InputPanel({ textA: $textA, textB: $textB }).width('100%').height(140) }
        if (this.hasResult) {
          Scroll() {
            if (this.viewMode === ViewMode.UNIFIED) {
              Column() {
                ForEach(this.lineTypes, (t: number, i: number) => {
                  UnifiedLine({ typeNum: t, content: this.lineContents[i], linenoA: this.lineNosA[i], linenoB: this.lineNosB[i],
                    searchKeyword: this.searchKeyword, isMonokai: this.colorMode === 'monokai',
                    isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === i
                  })
                }, (t: number, i: number) => `u_${i}`)
              }
            } else {
              Column() {
                ForEach(this.sbsPairs, (p: SbsPair, i: number) => {
                  SideBySideRow({
                    leftType: p.leftType, leftContent: p.leftContent, leftLineNo: p.leftLineNo,
                    rightType: p.rightType, rightContent: p.rightContent, rightLineNo: p.rightLineNo,
                    isMonokai: this.colorMode === 'monokai',
                    isSearchMatch: this.searchMatches.length > 0 && this.searchMatches[this.searchIdx] === i,
                    onSyncToRight: () => { this.syncToRight(p); },
                    onSyncToLeft: () => { this.syncToLeft(p); }
                  })
                }, (p: SbsPair, i: number) => `s_${i}`)
              }
            }
          }.width('100%').layoutWeight(1).scrollBar(BarState.Auto)
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

  private doDiff(): void {
    const a = this.textA.split('\n'); const b = this.textB.split('\n');
    const types: number[] = []; const contents: string[] = []; const nosA: number[] = []; const nosB: number[] = [];
    const pairs: SbsPair[] = [];
    let _added = 0, _deleted = 0, _mod = 0, _unch = 0, blk = 0, inBlk = false;
    const max = Math.max(a.length, b.length);
    for (let i = 0; i < max; i++) {
      const aEnd = i >= a.length, bEnd = i >= b.length; const va = aEnd ? '' : a[i]; const vb = bEnd ? '' : b[i];
      let t: number;
      if (!aEnd && !bEnd && va === vb) { t = 0; _unch++; inBlk = false; }
      else if (!aEnd && !bEnd) { t = 3; _mod++; if (!inBlk) { blk++; inBlk = true; } }
      else if (!aEnd) { t = 2; _deleted++; if (!inBlk) { blk++; inBlk = true; } }
      else { t = 1; _added++; if (!inBlk) { blk++; inBlk = true; } }
      types.push(t); contents.push(aEnd ? vb : va);
      nosA.push(aEnd ? -1 : i + 1); nosB.push(bEnd ? -1 : i + 1);
      pairs.push({
        leftType: aEnd ? 0 : (bEnd ? 2 : (va === vb ? 0 : 3)), leftContent: aEnd ? '' : va, leftLineNo: aEnd ? -1 : i + 1,
        rightType: bEnd ? 0 : (aEnd ? 1 : (va === vb ? 0 : 3)), rightContent: bEnd ? '' : vb, rightLineNo: bEnd ? -1 : i + 1
      });
    }
    this.lineTypes = types; this.lineContents = contents; this.lineNosA = nosA; this.lineNosB = nosB; this.sbsPairs = pairs;
    this.added = _added; this.deleted = _deleted; this.modified = _mod;
    const total = _unch + _added + _deleted + _mod;
    this.similarity = total > 0 ? Math.round(_unch / total * 1000) / 10 : 100;
    this.blockCnt = blk; this.hasResult = true;
    this.searchMatches = []; this.searchIdx = 0;
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

  private pickFileA(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          let file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
          let stat = fs.statSync(uris[0]);
          this.fileAName = uris[0].split('/').pop() || '';
          let buf = new ArrayBuffer(stat.size);
          let readLen = fs.readSync(file.fd, buf);
          let arr = new Uint8Array(buf, 0, readLen);
          let content = '';
          for (let i = 0; i < arr.length; i++) content += String.fromCharCode(arr[i]);
          this.textA = content;
          fs.closeSync(file);
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
          let file = fs.openSync(uris[0], fs.OpenMode.READ_ONLY);
          let stat = fs.statSync(uris[0]);
          this.fileBName = uris[0].split('/').pop() || '';
          let buf = new ArrayBuffer(stat.size);
          let readLen = fs.readSync(file.fd, buf);
          let arr = new Uint8Array(buf, 0, readLen);
          let content = '';
          for (let i = 0; i < arr.length; i++) content += String.fromCharCode(arr[i]);
          this.textB = content;
          fs.closeSync(file);
        }
      });
    } catch (e) { /* ignore */ }
  }
}
