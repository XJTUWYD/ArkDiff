/**
 * AegisDiff — FolderDiffPage (文件对比)
 * 使用 DiffEngine 进行文件内容差异分析
 */
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { DiffEngine } from '../engine/DiffEngine';
import { DiffLine, DiffOptions, DiffType } from '../model/DiffModels';

interface FileInfo {
  name: string;
  size: number;
  content: string;
}

@Entry
@Component
struct FolderDiffPage {
  @State fileA: FileInfo | null = null;
  @State fileB: FileInfo | null = null;
  @State added: number = 0; @State deleted: number = 0; @State modified: number = 0;
  @State similarity: number = 100;
  @State previewLines: DiffLine[] = [];

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333333') }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('文件对比').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor('#FFFFFF')

      Divider().height(1).color('#E0E0E0')

      Row() {
        Column() {
          Text('文件 A').fontSize(12).fontColor('#666666').fontWeight(FontWeight.Medium)
          if (this.fileA) {
            Text(this.fileA.name).fontSize(13).fontColor('#1A7F37')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
            Text(`${this.formatSize(this.fileA.size)} · ${this.fileA.content.split('\n').length} 行`)
              .fontSize(11).fontColor('#999999').margin({ top: 2 })
          } else {
            Text('未选择').fontSize(12).fontColor('#BBBBBB').margin({ top: 8 })
          }
          Button(this.fileA ? '更换' : '选择').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(10)
            .margin({ top: 8 }).padding({ left: 10, right: 10 })
            .onClick(() => { this.selectFileA(); })
        }
        .width('45%').alignItems(HorizontalAlign.Center)

        Column() {
          Text('VS').fontSize(20).fontColor('#CCCCCC').fontWeight(FontWeight.Bold)
        }.width('10%').alignItems(HorizontalAlign.Center)

        Column() {
          Text('文件 B').fontSize(12).fontColor('#666666').fontWeight(FontWeight.Medium)
          if (this.fileB) {
            Text(this.fileB.name).fontSize(13).fontColor('#BE2E2E')
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
            Text(`${this.formatSize(this.fileB.size)} · ${this.fileB.content.split('\n').length} 行`)
              .fontSize(11).fontColor('#999999').margin({ top: 2 })
          } else {
            Text('未选择').fontSize(12).fontColor('#BBBBBB').margin({ top: 8 })
          }
          Button(this.fileB ? '更换' : '选择').fontSize(11).height(28).type(ButtonType.Capsule)
            .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(10)
            .margin({ top: 8 }).padding({ left: 10, right: 10 })
            .onClick(() => { this.selectFileB(); })
        }
        .width('45%').alignItems(HorizontalAlign.Center)
      }
      .width('100%').padding({ top: 24, bottom: 24 }).backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#E0E0E0' })

      if (this.fileA && this.fileB) {
        Row() {
          Text(`+${this.added}`).fontSize(14).fontColor('#1A7F37').fontWeight(FontWeight.Medium)
          Text(`-${this.deleted}`).fontSize(14).fontColor('#BE2E2E').fontWeight(FontWeight.Medium).margin({ left: 16, right: 16 })
          Text(`~${this.modified}`).fontSize(14).fontColor('#D4A017').fontWeight(FontWeight.Medium).margin({ right: 16 })
          Text(`${this.similarity}%`).fontSize(14).fontColor('#333333').fontWeight(FontWeight.Medium)
          Text(' 相似').fontSize(12).fontColor('#999999')
        }
        .width('100%').height(44).justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF').borderRadius(10)
        .margin({ left: 12, right: 12, top: 12 })

        Scroll() {
          Column() {
            ForEach(this.previewLines, (line: DiffLine, i: number) => {
              Row() {
                Text(line.lineNumberA > 0 ? `${line.lineNumberA}` : line.lineNumberB > 0 ? `${line.lineNumberB}` : '')
                  .fontSize(10).fontColor('#999999').width(26).textAlign(TextAlign.End).fontFamily('monospace')
                Text(this.getPrefix(line.type)).fontSize(11).fontWeight(FontWeight.Bold)
                  .fontColor(this.getDiffColor(line.type)).width(14).textAlign(TextAlign.Center)
                Text(line.content).fontSize(11).fontFamily('monospace')
                  .fontColor('#1C1C1C')
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).padding({ left: 4, right: 4 }).layoutWeight(1)
              }
              .width('100%').height(20)
              .backgroundColor(this.getDiffBg(line.type)).padding({ left: 4 })
            }, (line: DiffLine, i: number) => `qp_${i}`)
          }.width('100%')
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Auto)
        .backgroundColor('#FFFFFF').borderRadius(10)
        .margin({ left: 12, right: 12, top: 8 })
      }

      Blank()
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private getPrefix(type: DiffType): string {
    switch (type) {
      case DiffType.ADDED: return '+';
      case DiffType.DELETED: return '-';
      case DiffType.MODIFIED: return '~';
      default: return ' ';
    }
  }

  private getDiffColor(type: DiffType): string {
    switch (type) {
      case DiffType.ADDED: return '#1A7F37';
      case DiffType.DELETED: return '#BE2E2E';
      case DiffType.MODIFIED: return '#D4A017';
      default: return '#CCCCCC';
    }
  }

  private getDiffBg(type: DiffType): string {
    switch (type) {
      case DiffType.ADDED: return '#E6FFEC';
      case DiffType.DELETED: return '#FFEBE9';
      case DiffType.MODIFIED: return '#FFF3D4';
      default: return '#FFFFFF';
    }
  }

  private selectFileA(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) this.fileA = this.readFile(uris[0]);
      });
    } catch (e) { /* ignore */ }
  }

  private selectFileB(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) this.fileB = this.readFile(uris[0]);
      });
    } catch (e) { /* ignore */ }
  }

  private readFile(uri: string): FileInfo {
    let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    let stat = fs.statSync(uri);
    let name = uri.split('/').pop() || 'unknown';
    let buf = new ArrayBuffer(stat.size);
    let readLen = fs.readSync(file.fd, buf);
    let arr = new Uint8Array(buf, 0, readLen);
    let content = '';
    for (let i = 0; i < arr.length; i++) content += String.fromCharCode(arr[i]);
    fs.closeSync(file);
    let info: FileInfo = { name: name, size: stat.size, content: content };
    this.computeDiff();
    return info;
  }

  private computeDiff(): void {
    if (!this.fileA || !this.fileB) return;
    const options: DiffOptions = {
      ignoreBlankLines: false,
      enableCharDiff: false
    };
    const result = DiffEngine.computeDiff(this.fileA.content, this.fileB.content, options);
    this.previewLines = result.unifiedLines;
    this.added = result.stats.addedCount;
    this.deleted = result.stats.deletedCount;
    this.modified = result.stats.modifiedCount;
    this.similarity = result.stats.similarityPercent;
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
  }
}
