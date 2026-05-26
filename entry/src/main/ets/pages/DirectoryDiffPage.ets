/**
 * AegisDiff — DirectoryDiffPage（递归目录对比）
 * 支持选择目录后递归扫描所有子文件，按相对路径智能匹配对比
 */
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';

interface DirFileInfo {
  name: string;       // 相对路径（含子目录，如 "src/utils/file.ets"）
  uri: string;
  size: number;
  content: string;
  isDir: boolean;
}

enum FileStatus {
  IDENTICAL = 0,
  MODIFIED = 1,
  ONLY_IN_A = 2,
  ONLY_IN_B = 3,
  PENDING = 4,
}

interface FileEntry {
  name: string;       // 相对路径
  uriA: string;
  uriB: string;
  sizeA: number;
  sizeB: number;
  status: FileStatus;
  similarity: number;
  contentA: string;
  contentB: string;
}

// 目录树节点
interface DirNode {
  name: string;
  isDir: boolean;
  files: DirFileInfo[];
  children: DirNode[];
  expanded: boolean;
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
  @State onlyACount: number = 0;
  @State onlyBCount: number = 0;
  @State recursive: boolean = false;
  @State scanning: boolean = false;
  @State scanStatus: string = '';

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor('#333333') }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('目录对比').fontSize(16).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)

        Row() {
          Text('递归').fontSize(11).fontColor(this.recursive ? '#007AFF' : '#999999')
          Toggle({ type: ToggleType.Switch, isOn: this.recursive })
            .width(36).height(20).margin({ left: 4 })
            .onChange((on: boolean) => { this.recursive = on; })
        }
      }
      .width('100%').height(48).padding({ left: 8, right: 8 }).backgroundColor('#FFFFFF')

      Divider().height(1).color('#E0E0E0')

      // 操作栏
      Row() {
        Button('📂 选择目录A').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(10).padding({ left: 10, right: 10 })
          .onClick(() => { this.pickDirA(); })
        Button('📂 选择目录B').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(10).padding({ left: 10, right: 10 })
          .margin({ left: 6 })
          .onClick(() => { this.pickDirB(); })
        Button('对比').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').fontColor(Color.White).borderRadius(10).padding({ left: 10, right: 10 })
          .margin({ left: 6 }).enabled(!this.scanning)
          .onClick(() => { this.doCompare(); })
        Button('清空').fontSize(12).height(32).type(ButtonType.Capsule)
          .backgroundColor('#E0E0E0').fontColor('#666666').borderRadius(10).padding({ left: 10, right: 10 })
          .margin({ left: 6 })
          .onClick(() => {
            this.filesA = []; this.filesB = [];
            this.entries = []; this.compared = false;
            this.identicalCount = 0; this.modifiedCount = 0;
            this.onlyACount = 0; this.onlyBCount = 0;
          })
        if (this.compared) {
          Text(`✓${this.identicalCount}/~${this.modifiedCount}/A${this.onlyACount}/B${this.onlyBCount}`)
            .fontSize(11).fontColor('#999999').layoutWeight(1).textAlign(TextAlign.End)
        } else {
          Blank().layoutWeight(1)
        }
      }
      .width('100%').padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 1 }, color: '#E0E0E0' })

      // 状态提示
      if (this.scanning) {
        Row() {
          LoadingProgress().width(16).height(16).color('#007AFF')
          Text(this.scanStatus).fontSize(12).fontColor('#666666').margin({ left: 8 })
          Blank()
        }
        .width('100%').height(30).padding({ left: 12, right: 12 }).backgroundColor('#E3F2FD')
      }

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
              Column() {
                // 目录路径头（首次出现新目录时显示）
                if (idx === 0 || this.getDirName(entry.name) !== this.getDirName(this.entries[idx - 1].name)) {
                  Row() {
                    Text(this.getDirName(entry.name) || '/')
                      .fontSize(10).fontColor('#999999').fontWeight(FontWeight.Medium)
                      .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                  }
                  .width('100%').backgroundColor('#F5F5F5')
                }
                // 文件行
                Row() {
                  Text(this.statusIcon(entry.status)).fontSize(14).width(24).textAlign(TextAlign.Center)
                  Column() {
                    Text(this.getFileName(entry.name)).fontSize(12).fontColor('#1C1C1C')
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
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
              }
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
          Text('选择两个目录后点击「对比」').fontSize(14).fontColor('#999999')
          Text(this.recursive ? '开启递归后会自动扫描子目录中的全部文件' : '将对比同名文件的内容差异')
            .fontSize(12).fontColor('#BBBBBB').margin({ top: 4 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  private getDirName(path: string): string {
    const idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(0, idx) : '';
  }

  private getFileName(path: string): string {
    const idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
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

  // ===================== 递归目录扫描 =====================

  private pickDirA(): void {
    this.scanning = true;
    this.scanStatus = '选择目录A...';
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 50;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        this.filesA = [];
        this.scanStatus = '扫描文件A...';
        for (let uri of uris) {
          let info = this.readFileInfo(uri, '');
          if (info) this.filesA.push(info);
        }
        // 递归模式：从已选文件推断目录并扫描同级/子目录
        if (this.recursive && this.filesA.length > 0) {
          this.filesA = this.scanRecursive(this.filesA);
        }
        this.scanning = false;
      }).catch(() => { this.scanning = false; });
    } catch (e) { this.scanning = false; }
  }

  private pickDirB(): void {
    this.scanning = true;
    this.scanStatus = '选择目录B...';
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 50;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        this.filesB = [];
        this.scanStatus = '扫描文件B...';
        for (let uri of uris) {
          let info = this.readFileInfo(uri, '');
          if (info) this.filesB.push(info);
        }
        if (this.recursive && this.filesB.length > 0) {
          this.filesB = this.scanRecursive(this.filesB);
        }
        this.scanning = false;
      }).catch(() => { this.scanning = false; });
    } catch (e) { this.scanning = false; }
  }

  /**
   * 递归扫描：从已收集文件的 URI 中推断父目录，遍历同级和子目录
   */
  private scanRecursive(files: DirFileInfo[]): DirFileInfo[] {
    const result = new Map<string, DirFileInfo>();
    const visited = new Set<string>(); // 已扫描的目录防止死循环

    // 从文件 URI 提取父目录 URI
    const dirs = new Set<string>();
    for (let f of files) {
      result.set(f.uri, f);
      const parentUri = f.uri.substring(0, f.uri.lastIndexOf('/'));
      if (parentUri) dirs.add(parentUri);
    }

    this.scanStatus = `递归扫描中...`;
    // 对每个目录，尝试列出所有文件
    for (let dirUri of dirs) {
      if (visited.has(dirUri)) continue;
      visited.add(dirUri);
      this.collectFromDir(dirUri, '', result, visited, 3);
    }

    return Array.from(result.values()).sort((a, b) => a.name.localeCompare(b.name));
  }

  /**
   * 递归收集目录中的文件
   */
  private collectFromDir(
    dirUri: string, prefix: string,
    result: Map<string, DirFileInfo>,
    visited: Set<string>, depth: number
  ): void {
    if (depth <= 0) return;
    try {
      const fileNames = fs.listFileSync(dirUri);
      for (let fname of fileNames) {
        const uri = `${dirUri}/${fname}`;
        const stat = fs.statSync(uri);
        const relPath = prefix ? `${prefix}/${fname}` : fname;

        if (stat.isDirectory()) {
          if (!visited.has(uri)) {
            visited.add(uri);
            this.scanStatus = `递归扫描: ${relPath}/`;
            this.collectFromDir(uri, relPath, result, visited, depth - 1);
          }
        } else {
          if (!result.has(uri)) {
            let info = this.readFileInfo(uri, relPath);
            if (info) result.set(uri, info);
          }
        }
      }
    } catch (_e) { /* 权限不足或非目录 */ }
  }

  // ===================== 文件读取 =====================

  private readFileInfo(uri: string, relPath: string): DirFileInfo | null {
    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(uri);
      let name = relPath || uri.split('/').pop() || 'unknown';
      let buf = new ArrayBuffer(stat.size > 0 ? stat.size : 1);
      let readLen = stat.size > 0 ? fs.readSync(file.fd, buf) : 0;
      let arr = new Uint8Array(buf, 0, readLen);
      let content = '';
      for (let i = 0; i < arr.length; i++) content += String.fromCharCode(arr[i]);
      fs.closeSync(file);
      return { name: name, uri: uri, size: stat.size, content: content, isDir: false };
    } catch (e) {
      return null;
    }
  }

  // ===================== 对比逻辑 =====================

  private doCompare(): void {
    this.entries = [];
    this.identicalCount = 0;
    this.modifiedCount = 0;
    this.onlyACount = 0;
    this.onlyBCount = 0;

    // 按相对路径建立索引
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
        if (fa.content === fb.content) {
          this.identicalCount++;
          this.entries.push({
            name, uriA: fa.uri, uriB: fb.uri, sizeA: fa.size, sizeB: fb.size,
            status: FileStatus.IDENTICAL, similarity: 100, contentA: fa.content, contentB: fb.content
          });
        } else {
          this.modifiedCount++;
          const sim = this.calcSimilarity(fa.content, fb.content);
          this.entries.push({
            name, uriA: fa.uri, uriB: fb.uri, sizeA: fa.size, sizeB: fb.size,
            status: FileStatus.MODIFIED, similarity: sim, contentA: fa.content, contentB: fb.content
          });
        }
      } else if (fa) {
        this.onlyACount++;
        this.entries.push({
          name, uriA: fa.uri, uriB: '', sizeA: fa.size, sizeB: 0,
          status: FileStatus.ONLY_IN_A, similarity: 0, contentA: fa.content, contentB: ''
        });
      } else if (fb) {
        this.onlyBCount++;
        this.entries.push({
          name, uriA: '', uriB: fb.uri, sizeA: 0, sizeB: fb.size,
          status: FileStatus.ONLY_IN_B, similarity: 0, contentA: '', contentB: fb.content
        });
      }
    }
    this.compared = true;
    this.totalCount = this.entries.length;

    // 按目录分组排序
    this.entries.sort((a, b) => a.name.localeCompare(b.name));
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
    AppStorage.setOrCreate('dirDiffContentA', entry.contentA);
    AppStorage.setOrCreate('dirDiffContentB', entry.contentB);
    AppStorage.setOrCreate('dirDiffNameA', entry.name);
    AppStorage.setOrCreate('dirDiffNameB', entry.name);
    router.pushUrl({ url: 'pages/DiffEditorPage' });
  }
}
