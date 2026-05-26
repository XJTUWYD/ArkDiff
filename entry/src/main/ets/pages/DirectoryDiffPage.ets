/**
 * AegisDiff — DirectoryDiffPage（目录/文件列表对比）
 * 对比两组文件列表，展示差异状态，点击文件查看详细 Diff
 */
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';

interface DirFileInfo {
  name: string;
  uri: string;
  size: number;
  content: string;
}

enum FileStatus {
  IDENTICAL = 0,
  MODIFIED = 1,
  ONLY_IN_A = 2,
  ONLY_IN_B = 3,
  PENDING = 4,
}

interface FileEntry {
  name: string;
  uriA: string;
  uriB: string;
  sizeA: number;
  sizeB: number;
  status: FileStatus;
  similarity: number;
  contentA: string;
  contentB: string;
}

@Entry
@Component
struct DirectoryDiffPage {
  @State filesA: DirFileInfo[] = [];
  @State filesB: DirFileInfo[] = [];
  @State entries: FileEntry[] = [];
  @State compared: boolean = false;
  @State totalCount: number = 0;
  @State identicalCount: number = 0;
  @State modifiedCount: number = 0;

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333333') }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('目录对比').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor('#FFFFFF')

      Divider().height(1).color('#E0E0E0')

      // 操作栏
      Row() {
        Button('📂 添加A').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(10).padding({ left: 10, right: 10 })
          .onClick(() => { this.pickFilesA(); })
        Button('📂 添加B').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(10).padding({ left: 10, right: 10 }).margin({ left: 6 })
          .onClick(() => { this.pickFilesB(); })
        Button('对比').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').fontColor(Color.White).borderRadius(10).padding({ left: 10, right: 10 }).margin({ left: 6 })
          .onClick(() => { this.doCompare(); })
        Button('清空').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#E0E0E0').fontColor('#666666').borderRadius(10).padding({ left: 10, right: 10 }).margin({ left: 6 })
          .onClick(() => { this.filesA = []; this.filesB = []; this.entries = []; this.compared = false; })
        if (this.compared) {
          Text(`${this.identicalCount}同/${this.modifiedCount}异`).fontSize(11).fontColor('#999999').layoutWeight(1).textAlign(TextAlign.End)
        } else {
          Blank().layoutWeight(1)
        }
      }
      .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })

      // 文件数量提示
      if (this.filesA.length > 0 || this.filesB.length > 0) {
        Row() {
          Text(`A: ${this.filesA.length} 文件`).fontSize(11).fontColor('#1A7F37')
          Text(`B: ${this.filesB.length} 文件`).fontSize(11).fontColor('#BE2E2E').margin({ left: 12 })
          Blank()
        }
        .width('100%').height(26).padding({ left: 12, right: 12 }).backgroundColor('#FAFAFA')
      }

      // 文件列表
      if (this.compared) {
        List({ space: 1 }) {
          ForEach(this.entries, (entry: FileEntry, idx: number) => {
            ListItem() {
              Row() {
                Text(this.statusIcon(entry.status)).fontSize(14).width(24).textAlign(TextAlign.Center)
                Column() {
                  Text(entry.name).fontSize(12).fontColor('#1C1C1C').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(this.statusText(entry)).fontSize(10).fontColor(this.statusColor(entry.status))
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                if (entry.status === FileStatus.MODIFIED) {
                  Text(`${entry.similarity}%`).fontSize(10).fontColor('#D4A017')
                }
                if (entry.status !== FileStatus.ONLY_IN_B) {
                  Text(this.formatSize(entry.sizeA)).fontSize(10).fontColor('#999999').margin({ left: 6 })
                }
              }
              .width('100%').height(40).padding({ left: 8, right: 8 })
              .backgroundColor('#FFFFFF')
              .onClick(() => {
                if (entry.status === FileStatus.MODIFIED || entry.status === FileStatus.IDENTICAL) {
                  this.openDiff(entry);
                }
              })
            }
          }, (entry: FileEntry, idx: number) => `de_${idx}`)
        }
        .width('100%').layoutWeight(1).backgroundColor('#F5F5F5')
      } else {
        Column() {
          Text('添加两组文件后点击「对比」').fontSize(14).fontColor('#999999')
          Text('支持对比同名文件的内容差异').fontSize(12).fontColor('#BBBBBB').margin({ top: 4 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private statusIcon(s: FileStatus): string {
    switch (s) { case FileStatus.IDENTICAL: return '✓'; case FileStatus.MODIFIED: return '~'; case FileStatus.ONLY_IN_A: return 'A'; case FileStatus.ONLY_IN_B: return 'B'; default: return '?'; }
  }

  private statusText(e: FileEntry): string {
    switch (e.status) { case FileStatus.IDENTICAL: return '内容相同'; case FileStatus.MODIFIED: return `${e.similarity}% 相似`; case FileStatus.ONLY_IN_A: return '仅在 A 中'; case FileStatus.ONLY_IN_B: return '仅在 B 中'; default: return '待对比'; }
  }

  private statusColor(s: FileStatus): string {
    switch (s) { case FileStatus.IDENTICAL: return '#1A7F37'; case FileStatus.MODIFIED: return '#D4A017'; case FileStatus.ONLY_IN_A: return '#BE2E2E'; case FileStatus.ONLY_IN_B: return '#1565C0'; default: return '#999999'; }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + 'B';
    if (bytes < 1048576) return (bytes / 1024).toFixed(0) + 'KB';
    return (bytes / 1048576).toFixed(1) + 'MB';
  }

  private pickFilesA(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 20;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        for (let uri of uris) {
          let info = this.readFileInfo(uri);
          if (info) this.filesA.push(info);
        }
      });
    } catch (e) { /* ignore */ }
  }

  private pickFilesB(): void {
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 20;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        for (let uri of uris) {
          let info = this.readFileInfo(uri);
          if (info) this.filesB.push(info);
        }
      });
    } catch (e) { /* ignore */ }
  }

  private readFileInfo(uri: string): DirFileInfo | null {
    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(uri);
      let name = uri.split('/').pop() || 'unknown';
      let buf = new ArrayBuffer(stat.size);
      let readLen = fs.readSync(file.fd, buf);
      let arr = new Uint8Array(buf, 0, readLen);
      let content = '';
      for (let i = 0; i < arr.length; i++) content += String.fromCharCode(arr[i]);
      fs.closeSync(file);
      let info: DirFileInfo = { name: name, uri: uri, size: stat.size, content: content };
      return info;
    } catch (e) {
      return null;
    }
  }

  private doCompare(): void {
    this.entries = [];
    this.identicalCount = 0;
    this.modifiedCount = 0;

    // 按文件名建立索引
    const mapA = new Map<string, DirFileInfo>();
    for (let f of this.filesA) mapA.set(f.name, f);
    const mapB = new Map<string, DirFileInfo>();
    for (let f of this.filesB) mapB.set(f.name, f);

    const allNames = new Set<string>();
    for (let f of this.filesA) allNames.add(f.name);
    for (let f of this.filesB) allNames.add(f.name);

    const sortedNames = Array.from(allNames).sort();
    for (let name of sortedNames) {
      const fa = mapA.get(name);
      const fb = mapB.get(name);
      if (fa && fb) {
        // 同名文件 → 比较内容
        if (fa.content === fb.content) {
          this.identicalCount++;
          let entry: FileEntry = {
            name: name, uriA: fa.uri, uriB: fb.uri,
            sizeA: fa.size, sizeB: fb.size,
            status: FileStatus.IDENTICAL, similarity: 100,
            contentA: fa.content, contentB: fb.content
          };
          this.entries.push(entry);
        } else {
          this.modifiedCount++;
          const sim = this.calcSimilarity(fa.content, fb.content);
          let entry: FileEntry = {
            name: name, uriA: fa.uri, uriB: fb.uri,
            sizeA: fa.size, sizeB: fb.size,
            status: FileStatus.MODIFIED, similarity: sim,
            contentA: fa.content, contentB: fb.content
          };
          this.entries.push(entry);
        }
      } else if (fa) {
        let entry: FileEntry = {
          name: name, uriA: fa.uri, uriB: '',
          sizeA: fa.size, sizeB: 0,
          status: FileStatus.ONLY_IN_A, similarity: 0,
          contentA: fa.content, contentB: ''
        };
        this.entries.push(entry);
      } else if (fb) {
        let entry: FileEntry = {
          name: name, uriA: '', uriB: fb.uri,
          sizeA: 0, sizeB: fb.size,
          status: FileStatus.ONLY_IN_B, similarity: 0,
          contentA: '', contentB: fb.content
        };
        this.entries.push(entry);
      }
    }
    this.compared = true;
    this.totalCount = this.entries.length;
  }

  private calcSimilarity(a: string, b: string): number {
    const la = a.split('\n'); const lb = b.split('\n');
    let same = 0;
    const max = Math.max(la.length, lb.length);
    for (let i = 0; i < max; i++) {
      if (i < la.length && i < lb.length && la[i] === lb[i]) same++;
    }
    return max > 0 ? Math.round(same / max * 1000) / 10 : 100;
  }

  private openDiff(entry: FileEntry): void {
    // 通过 AppStorage 传递文件内容到 DiffEditorPage
    AppStorage.setOrCreate('dirDiffContentA', entry.contentA);
    AppStorage.setOrCreate('dirDiffContentB', entry.contentB);
    AppStorage.setOrCreate('dirDiffNameA', entry.name);
    AppStorage.setOrCreate('dirDiffNameB', entry.name);
    router.pushUrl({ url: 'pages/DiffEditorPage' });
  }
}
