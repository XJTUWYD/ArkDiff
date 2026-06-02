/**
 * AegisDiff — FolderDiffPage (文件对比)
 *
 * 文件选择 + 跳转至 DiffEditorPage（复用全部分栏/编辑/合入/搜索/导航等 Meld 功能）
 */
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { FileContentService } from '../services/FileContentService';

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

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('\u2190').fontSize(18).fontColor('#333333') }
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

      Column() {
        Text('选择两个文件后进入对比视图').fontSize(13).fontColor('#999999').margin({ bottom: 12 })

        Button('进入对比').fontSize(14).height(40).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').fontColor(Color.White).borderRadius(10)
          .padding({ left: 32, right: 32 })
          .enabled(this.fileA !== null && this.fileB !== null)
          .onClick(() => { this.openDiffEditor(); })

        Text('将使用完整的分栏对比、行内编辑、差异导航等功能')
          .fontSize(11).fontColor('#BBBBBB').margin({ top: 12 })
      }
      .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)

      Blank()
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private selectFileA(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        if (uris.length > 0) {
          const fc = FileContentService.readFileContent(uris[0]);
          this.fileA = { name: fc.fileName, size: fc.sizeBytes, content: fc.content };
          if (fc.error && !fc.isBinary) {
            AlertDialog.show({ title: '提示', message: fc.error, autoCancel: true });
          }
          if (fc.isBinary && !fc.content) {
            AlertDialog.show({ title: '提示', message: '二进制文件暂不支持文本比较', autoCancel: true });
          }
        }
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
        if (uris.length > 0) {
          const fc = FileContentService.readFileContent(uris[0]);
          this.fileB = { name: fc.fileName, size: fc.sizeBytes, content: fc.content };
          if (fc.error && !fc.isBinary) {
            AlertDialog.show({ title: '提示', message: fc.error, autoCancel: true });
          }
          if (fc.isBinary && !fc.content) {
            AlertDialog.show({ title: '提示', message: '二进制文件暂不支持文本比较', autoCancel: true });
          }
        }
      });
    } catch (e) { /* ignore */ }
  }

  /** 将选中的文件内容传递到 DiffEditorPage 并跳转 */
  private openDiffEditor(): void {
    if (!this.fileA || !this.fileB) return;
    AppStorage.setOrCreate('dirDiffContentA', this.fileA.content);
    AppStorage.setOrCreate('dirDiffContentB', this.fileB.content);
    AppStorage.setOrCreate('dirDiffNameA', this.fileA.name);
    AppStorage.setOrCreate('dirDiffNameB', this.fileB.name);
    router.pushUrl({ url: 'pages/DiffEditorPage' });
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / 1048576).toFixed(1) + ' MB';
  }
}
