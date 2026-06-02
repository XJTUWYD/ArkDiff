/**
 * AegisDiff — DirectoryDiffPage（文件集合比较 — P1 升级版 — 树状工作区）
 *
 * ⚠ 当前实现定位：文件集合比较（File Collection Compare），非真正的目录树对比。
 *   原因：HarmonyOS DocumentViewPicker 当前只能选择文件列表，不可选择目录根。
 *   因此页面通过用户选择多文件并推断相对路径来模拟目录结构。
 *   未来若 HarmonyOS 支持目录选择器，需重构本页为真正的 DirectoryDiff 模型。
 *
 * 已知模型限制：
 *   - FileEntry.contentA/contentB 全量加载到内存，大文件集合 (>10MB) 可能导致 OOM
 *   - V0.3+ 计划改为惰性加载 + LRU 缓存模式
 *
 * 新增能力：
 *   - 树形目录结构，展开/折叠
 *   - 过滤：仅显示差异 / 显示全部
 *   - 排序：按名称 / 状态 / 相似度
 *   - 过滤：忽略相同文件
 *   - 文件读取统一走 FileContentService
 *   - 点击文件直接跳转 DiffEditorPage
 *   - 相似度计算使用 DiffEngine.computeDiff
 */
import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { FileContentService, FileContent } from '../services/FileContentService';
import { ThemeColors } from '../utils/ThemeColors';
import { DiffEngine } from '../engine/DiffEngine';
import { DiffOptions } from '../model/DiffModels';

/** 文件差异状态 */
enum FileStatus {
  IDENTICAL = 0,
  MODIFIED = 1,
  ONLY_IN_A = 2,
  ONLY_IN_B = 3,
  PENDING = 4,
}

/** 单个文件条目 */
interface FileEntry {
  name: string;          // 文件名
  path: string;          // 相对路径（含子目录）
  uriA: string;
  uriB: string;
  sizeA: number;
  sizeB: number;
  status: FileStatus;
  similarity: number;
  contentA: string;
  contentB: string;
}

/** 目录树节点 */
interface TreeNode {
  name: string;           // 目录名或文件名
  path: string;           // 完整相对路径
  isDir: boolean;
  level: number;          // 层级（0=根）
  status: FileStatus;     // 目录的状态为其子文件的最差状态
  similarity: number;     // 目录平均相似度
  fileEntry?: FileEntry;  // 若是文件节点
  children: TreeNode[];
  expanded: boolean;
  parentPath: string;     // 父目录路径
}

/** 排序方式 */
enum SortMode {
  BY_NAME = 0,
  BY_STATUS = 1,
  BY_SIMILARITY = 2
}

@Entry
@Component
struct DirectoryDiffPage {
  @State filesA: FileEntry[] = [];
  @State filesB: FileEntry[] = [];
  @State treeNodes: TreeNode[] = [];
  @State compared: boolean = false;
  @State totalCount: number = 0;
  @State identicalCount: number = 0;
  @State modifiedCount: number = 0;
  @State onlyACount: number = 0;
  @State onlyBCount: number = 0;
  @State scanning: boolean = false;
  @State scanStatus: string = '';
  @State showOnlyDiff: boolean = false;   // 仅显示差异项
  @State sortMode: SortMode = SortMode.BY_NAME;
  @State expandAll: boolean = true;

  private theme: ThemeColors = ThemeColors.getInstance();

  build() {
    Column() {
      // === 头部导航 ===
      Row() {
        Button({ type: ButtonType.Circle }) { Text('←').fontSize(18).fontColor(this.theme.textPrimary) }
        .width(32).height(32).backgroundColor(Color.Transparent)
        .onClick(() => { router.back(); })

        Text('目录对比').fontSize(16).fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary).layoutWeight(1).textAlign(TextAlign.Center)
      }
      .width('100%').height(48).padding({ left: 8 }).backgroundColor(this.theme.surfaceBackground)

      Divider().height(1).color(this.theme.dividerColor)

      // === 操作栏 ===
      Row() {
        Button('📂 选择文件组A').fontSize(11).height(30).type(ButtonType.Capsule)
          .backgroundColor('#E8F5E9').fontColor('#1A7F37').borderRadius(8)
          .padding({ left: 8, right: 8 }).enabled(!this.scanning)
          .onClick(() => { this.pickGroupA(); })
        Button('📂 选择文件组B').fontSize(11).height(30).type(ButtonType.Capsule)
          .backgroundColor('#FFEBEE').fontColor('#BE2E2E').borderRadius(8)
          .padding({ left: 8, right: 8 }).enabled(!this.scanning)
          .margin({ left: 4 }).onClick(() => { this.pickGroupB(); })
        Button('对比').fontSize(11).height(30).type(ButtonType.Capsule)
          .backgroundColor('#007AFF').fontColor(Color.White).borderRadius(8)
          .padding({ left: 8, right: 8 }).margin({ left: 4 }).enabled(!this.scanning)
          .onClick(() => { this.doCompare(); })
        Button('清空').fontSize(11).height(30).type(ButtonType.Capsule)
          .backgroundColor('#E0E0E0').fontColor('#666').borderRadius(8)
          .padding({ left: 8, right: 8 }).margin({ left: 4 })
          .onClick(() => {
            this.filesA = []; this.filesB = []; this.treeNodes = [];
            this.compared = false;
            this.identicalCount = 0; this.modifiedCount = 0;
            this.onlyACount = 0; this.onlyBCount = 0;
          })
      }
      .width('100%').padding({ left: 8, right: 4, top: 6, bottom: 6 })
      .backgroundColor(this.theme.surfaceBackground)
      .border({ width: { bottom: 1 }, color: this.theme.dividerColor })

      // === 状态栏 / 统计 ===
      if (this.scanning) {
        Row() {
          LoadingProgress().width(14).height(14).color('#007AFF')
          Text(this.scanStatus).fontSize(11).fontColor('#666').margin({ left: 6 })
        }
        .width('100%').height(26).padding({ left: 12 }).backgroundColor('#E3F2FD')
      }

      if (this.compared) {
        Row() {
          Text(`相同 ${this.identicalCount}`).fontSize(10).fontColor('#1A7F37')
            .fontWeight(FontWeight.Medium)
          Text(`差异 ${this.modifiedCount}`).fontSize(10).fontColor('#D4A017')
            .fontWeight(FontWeight.Medium).margin({ left: 6 })
          Text(`仅A ${this.onlyACount}`).fontSize(10).fontColor('#BE2E2E')
            .fontWeight(FontWeight.Medium).margin({ left: 6 })
          Text(`仅B ${this.onlyBCount}`).fontSize(10).fontColor('#1565C0')
            .fontWeight(FontWeight.Medium).margin({ left: 6 })
        }
        .width('100%').height(22).padding({ left: 12, right: 8 })
        .backgroundColor('#FAFAFA').border({ width: { bottom: 1 }, color: this.theme.dividerColor })
      }

      if (this.filesA.length > 0 || this.filesB.length > 0) {
        Row() {
          Text(`A: ${this.filesA.length}文件`).fontSize(10).fontColor('#1A7F37')
          Text(`B: ${this.filesB.length}文件`).fontSize(10).fontColor('#BE2E2E').margin({ left: 10 })
          Blank()
          if (this.compared) {
            Button(this.expandAll ? '折叠全部' : '展开全部').fontSize(10).height(20)
              .type(ButtonType.Normal).backgroundColor(Color.Transparent).fontColor('#007AFF')
              .onClick(() => { this.toggleExpandAll(); })
          }
        }
        .width('100%').height(22).padding({ left: 12, right: 8 }).backgroundColor('#F5F5F5')
      }

      // === 工具栏（排序/过滤） ===
      if (this.compared) {
        Row() {
          Row() {
            Text('仅差异').fontSize(10).fontColor(this.showOnlyDiff ? '#007AFF' : this.theme.textSecondary)
            Toggle({ type: ToggleType.Switch, isOn: this.showOnlyDiff })
              .width(28).height(14).margin({ left: 2 })
              .onChange((on: boolean) => { this.showOnlyDiff = on; })
          }

          Blank()

          Text('排序').fontSize(10).fontColor(this.theme.textSecondary).margin({ right: 2 })
          Row() {
            Button('名称').fontSize(9).height(18).type(ButtonType.Capsule)
              .padding({ left: 6, right: 6 }).borderRadius(6)
              .backgroundColor(this.sortMode === SortMode.BY_NAME ? '#007AFF' : '#E0E0E0')
              .fontColor(this.sortMode === SortMode.BY_NAME ? Color.White : '#666')
              .onClick(() => { this.sortMode = SortMode.BY_NAME; this.rebuildTree(); })
            Button('状态').fontSize(9).height(18).type(ButtonType.Capsule)
              .padding({ left: 6, right: 6 }).borderRadius(6).margin({ left: 2 })
              .backgroundColor(this.sortMode === SortMode.BY_STATUS ? '#007AFF' : '#E0E0E0')
              .fontColor(this.sortMode === SortMode.BY_STATUS ? Color.White : '#666')
              .onClick(() => { this.sortMode = SortMode.BY_STATUS; this.rebuildTree(); })
            Button('相似度').fontSize(9).height(18).type(ButtonType.Capsule)
              .padding({ left: 6, right: 6 }).borderRadius(6).margin({ left: 2 })
              .backgroundColor(this.sortMode === SortMode.BY_SIMILARITY ? '#007AFF' : '#E0E0E0')
              .fontColor(this.sortMode === SortMode.BY_SIMILARITY ? Color.White : '#666')
              .onClick(() => { this.sortMode = SortMode.BY_SIMILARITY; this.rebuildTree(); })
          }
        }
        .width('100%').height(28).padding({ left: 10, right: 10 })
        .backgroundColor(this.theme.surfaceBackground)
      }

      // === 树状文件列表 ===
      if (this.compared) {
        List({ space: 0 }) {
          ForEach(this.filteredNodes(), (node: TreeNode, idx: number) => {
            ListItem() {
              this.treeNodeItem(node)
            }
          }, (node: TreeNode, idx: number) => `tn_${node.path}_${idx}`)
        }
        .width('100%').layoutWeight(1).backgroundColor(this.theme.pageBackground)
      } else {
        Column() {
          Text('选择两组文件后点击「对比」').fontSize(13).fontColor(this.theme.textSecondary)
          Text('将对比文件列表差异，点击文件可查看详细 diff')
            .fontSize(11).fontColor('#BBBBBB').margin({ top: 4 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor(this.theme.pageBackground)
  }

  // ===================== 树节点 =====================
  @Builder
  treeNodeItem(node: TreeNode) {
    Column() {
      Row() {
        // 缩进 + 展开图标
        if (node.isDir) {
          Text(node.expanded ? '▼' : '▶').fontSize(10).fontColor('#999')
            .width(node.level * 12 + 16).textAlign(TextAlign.End)
            .onClick(() => { node.expanded = !node.expanded; this.treeNodes = [...this.treeNodes]; })
        } else {
          Blank().width(node.level * 12 + 16)
        }

        // 状态图标
        Text(this.statusIcon(node.status)).fontSize(12).width(20).textAlign(TextAlign.Center)

        // 文件/目录名
        Text(node.name).fontSize(12)
          .fontColor(node.status === FileStatus.MODIFIED ? '#D4A017'
            : node.status === FileStatus.ONLY_IN_A ? '#BE2E2E'
            : node.status === FileStatus.ONLY_IN_B ? '#1565C0'
            : this.theme.textPrimary)
          .fontWeight(node.isDir ? FontWeight.Medium : FontWeight.Normal)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)

        // 相似度
        if (node.status === FileStatus.MODIFIED && !node.isDir) {
          Text(`${node.similarity}%`).fontSize(10).fontColor('#D4A017').margin({ left: 4 })
        }

        // 大小
        if (!node.isDir && node.fileEntry) {
          Text(this.formatSize(Math.max(node.fileEntry.sizeA, node.fileEntry.sizeB))).fontSize(9).fontColor('#999').margin({ left: 6, right: 6 })
        }

        // 子文件数
        if (node.isDir) {
          Text(`${this.countFiles(node)}`).fontSize(9).fontColor('#BBB').margin({ right: 6 })
        }
      }
      .width('100%').height(32).padding({ left: 0, right: 4 })
      .backgroundColor('#FFFFFF').border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
      .onClick(() => {
        if (!node.isDir && node.fileEntry) {
          if (node.status === FileStatus.MODIFIED || node.status === FileStatus.IDENTICAL) {
            this.openDiff(node.fileEntry);
          }
        } else {
          node.expanded = !node.expanded;
          this.treeNodes = [...this.treeNodes];
        }
      })

      // 递归渲染子节点
      if (node.isDir && node.expanded) {
        ForEach(this.sortChildren(node.children), (child: TreeNode, ci: number) => {
          this.treeNodeItem(child)
        }, (child: TreeNode, ci: number) => `tchild_${child.path}_${ci}`)
      }
    }
  }

  // ===================== 过滤 + 排序 =====================
  private filteredNodes(): TreeNode[] {
    let nodes = this.sortChildren(this.treeNodes);
    if (this.showOnlyDiff) {
      nodes = nodes.filter(n => n.status !== FileStatus.IDENTICAL);
    }
    return nodes;
  }

  private sortChildren(children: TreeNode[]): TreeNode[] {
    const sorted = [...children];
    if (this.sortMode === SortMode.BY_NAME) {
      sorted.sort((a, b) => {
        if (a.isDir !== b.isDir) return a.isDir ? -1 : 1;
        return a.name.localeCompare(b.name);
      });
    } else if (this.sortMode === SortMode.BY_STATUS) {
      sorted.sort((a, b) => {
        if (a.isDir !== b.isDir) return a.isDir ? -1 : 1;
        return a.status - b.status;
      });
    } else if (this.sortMode === SortMode.BY_SIMILARITY) {
      sorted.sort((a, b) => {
        if (a.isDir !== b.isDir) return a.isDir ? -1 : 1;
        return a.similarity - b.similarity;
      });
    }
    return sorted;
  }

  // ===================== 文件选择 =====================
  private pickGroupA(): void {
    this.scanning = true;
    this.scanStatus = '选择文件组A...';
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 50;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        this.filesA = [];
        for (let uri of uris) {
          const entry = this.fileInfoFromUri(uri, '', uris);
          if (entry) this.filesA.push(entry);
        }
        this.scanning = false;
      }).catch(() => { this.scanning = false; });
    } catch (e) { this.scanning = false; }
  }

  private pickGroupB(): void {
    this.scanning = true;
    this.scanStatus = '选择文件组B...';
    try {
      let context = getContext(this);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 50;
      const docPicker = new picker.DocumentViewPicker(context);
      docPicker.select(opts).then((uris: string[]) => {
        this.filesB = [];
        for (let uri of uris) {
          const entry = this.fileInfoFromUri(uri, '', uris);
          if (entry) this.filesB.push(entry);
        }
        this.scanning = false;
      }).catch(() => { this.scanning = false; });
    } catch (e) { this.scanning = false; }
  }

  /** 推断相对路径：取 URI 在整体 URI 列表中的最大公共前缀后的路径 */
  private fileInfoFromUri(uri: string, forcedPath: string, allUris: string[]): FileEntry | null {
    try {
      const fc: FileContent = FileContentService.readFileContent(uri);
      const fileName = uri.split('/').pop() || 'unknown';
      // 计算公共前缀推断目录结构
      let relPath = forcedPath;
      if (!relPath) {
        relPath = this.inferRelativePath(uri, allUris);
        if (!relPath) relPath = fileName;
      }
      return {
        name: fileName, path: relPath, uriA: uri, uriB: '',
        sizeA: fc.sizeBytes, sizeB: 0, status: FileStatus.PENDING,
        similarity: 0, contentA: fc.content, contentB: ''
      };
    } catch (e) {
      return null;
    }
  }

  /** 从 URI 列表中推断相对路径 */
  private inferRelativePath(uri: string, allUris: string[]): string {
    // 简单策略：找共同的目录前缀，剩余作为相对路径
    if (allUris.length <= 1) return uri.split('/').pop() || '';
    const parts = allUris.map(u => u.split('/').slice(0, -1));
    let prefixLength = 0;
    const first = parts[0];
    for (let i = 0; i < first.length; i++) {
      let allMatch = true;
      for (let j = 1; j < parts.length; j++) {
        if (i >= parts[j].length || parts[j][i] !== first[i]) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) prefixLength = i + 1;
      else break;
    }
    const uriParts = uri.split('/');
    return uriParts.slice(prefixLength).join('/');
  }

  // ===================== 对比逻辑 =====================
  private doCompare(): void {
    this.treeNodes = [];
    this.compared = false;
    this.identicalCount = 0; this.modifiedCount = 0;
    this.onlyACount = 0; this.onlyBCount = 0;

    // 按相对路径建立索引
    const mapA = new Map<string, FileEntry>();
    for (let f of this.filesA) mapA.set(f.path, f);
    const mapB = new Map<string, FileEntry>();
    for (let f of this.filesB) mapB.set(f.path, f);

    // 合并：找出所有文件路径
    const allPaths = new Set<string>();
    for (let f of this.filesA) allPaths.add(f.path);
    for (let f of this.filesB) allPaths.add(f.path);

    // 对比每个文件
    const mergedFiles: FileEntry[] = [];
    for (let path of allPaths) {
      const fa = mapA.get(path);
      const fb = mapB.get(path);
      if (fa && fb) {
        if (fa.contentA === fb.contentA) {
          this.identicalCount++;
          mergedFiles.push({
            name: fa.name, path, uriA: fa.uriA, uriB: fb.uriA,
            sizeA: fa.sizeA, sizeB: fb.sizeA, status: FileStatus.IDENTICAL,
            similarity: 100, contentA: fa.contentA, contentB: fb.contentA
          });
        } else {
          this.modifiedCount++;
          const sim = this.calcSimilarity(fa.contentA, fb.contentA);
          mergedFiles.push({
            name: fa.name, path, uriA: fa.uriA, uriB: fb.uriA,
            sizeA: fa.sizeA, sizeB: fb.sizeA, status: FileStatus.MODIFIED,
            similarity: sim, contentA: fa.contentA, contentB: fb.contentA
          });
        }
      } else if (fa) {
        this.onlyACount++;
        mergedFiles.push({
          name: fa.name, path, uriA: fa.uriA, uriB: '',
          sizeA: fa.sizeA, sizeB: 0, status: FileStatus.ONLY_IN_A,
          similarity: 0, contentA: fa.contentA, contentB: ''
        });
      } else if (fb) {
        this.onlyBCount++;
        mergedFiles.push({
          name: fb.name, path, uriA: '', uriB: fb.uriA,
          sizeA: 0, sizeB: fb.sizeA, status: FileStatus.ONLY_IN_B,
          similarity: 0, contentA: '', contentB: fb.contentA
        });
      }
    }

    this.totalCount = mergedFiles.length;
    this.compared = true;

    // 构建树结构
    this.treeNodes = this.buildTree(mergedFiles);
  }

  // ===================== 树构建 =====================
  private buildTree(files: FileEntry[]): TreeNode[] {
    const rootNodes: TreeNode[] = [];
    const dirMap = new Map<string, TreeNode>();

    // 先按路径排序
    files.sort((a, b) => a.path.localeCompare(b.path));

    for (const file of files) {
      const pathParts = file.path.split('/');
      let currentParentPath = '';

      for (let i = 0; i < pathParts.length; i++) {
        const isLast = i === pathParts.length - 1;
        const currentPath = isLast ? '' : pathParts.slice(0, i + 1).join('/');
        const name = pathParts[i];

        if (isLast) {
          // 文件节点
          const fileNode: TreeNode = {
            name, path: file.path, isDir: false, level: i,
            status: file.status, similarity: file.similarity,
            fileEntry: file, children: [], expanded: false,
            parentPath: currentParentPath
          };

          if (currentParentPath && dirMap.has(currentParentPath)) {
            dirMap.get(currentParentPath)!.children.push(fileNode);
          } else {
            rootNodes.push(fileNode);
          }
        } else {
          // 目录节点
          if (!dirMap.has(currentPath)) {
            const dirNode: TreeNode = {
              name, path: currentPath, isDir: true, level: i,
              status: FileStatus.IDENTICAL, similarity: 100,
              children: [], expanded: this.expandAll,
              parentPath: currentParentPath
            };
            dirMap.set(currentPath, dirNode);

            if (currentParentPath && dirMap.has(currentParentPath)) {
              dirMap.get(currentParentPath)!.children.push(dirNode);
            } else {
              rootNodes.push(dirNode);
            }
          }
          currentParentPath = currentPath;
        }
      }
    }

    // 自底向上更新目录状态
    this.updateDirStatus(rootNodes);

    return rootNodes;
  }

  /** 递归更新目录状态 = 子节点中的最差状态 */
  private updateDirStatus(nodes: TreeNode[]): void {
    for (const node of nodes) {
      if (node.isDir) {
        this.updateDirStatus(node.children);
        if (node.children.length > 0) {
          // 最差状态
          let worst = FileStatus.IDENTICAL;
          let totalSim = 0;
          let simCount = 0;
          for (const child of node.children) {
            if (child.status > worst) worst = child.status;
            totalSim += child.similarity;
            simCount++;
          }
          node.status = worst;
          node.similarity = simCount > 0 ? Math.round(totalSim / simCount) : 100;
        }
      }
    }
  }

  private rebuildTree(): void {
    // 从已存在的文件条目重建树
    const allFiles: FileEntry[] = [];
    const collectFiles = (nodes: TreeNode[]) => {
      for (const node of nodes) {
        if (node.fileEntry) allFiles.push(node.fileEntry);
        if (node.isDir) collectFiles(node.children);
      }
    };
    collectFiles(this.treeNodes);
    this.treeNodes = this.buildTree(allFiles);
  }

  private toggleExpandAll(): void {
    const toggleExpand = (nodes: TreeNode[]) => {
      for (const node of nodes) {
        node.expanded = !this.expandAll;
        if (node.isDir) toggleExpand(node.children);
      }
    };
    toggleExpand(this.treeNodes);
    this.expandAll = !this.expandAll;
    this.treeNodes = [...this.treeNodes];
  }

  // ===================== 工具方法 =====================
  private statusIcon(s: FileStatus): string {
    switch (s) { case FileStatus.IDENTICAL: return '='; case FileStatus.MODIFIED: return '~'; case FileStatus.ONLY_IN_A: return '←'; case FileStatus.ONLY_IN_B: return '→'; default: return '?'; }
  }

  private calcSimilarity(a: string, b: string): number {
    if (a === b) return 100;
    if (a.length === 0 || b.length === 0) return 0;
    const options: DiffOptions = { ignoreBlankLines: false, enableCharDiff: false, ignoreCase: false, ignoreWhitespace: false, ignoreAllWhitespace: false, manualAlignments: new Map<number, number>() };
    try {
      const result = DiffEngine.computeDiff(a, b, options);
      return Math.round(result.stats.similarityPercent * 10) / 10;
    } catch (e) {
      console.error('DirectoryDiffPage: DiffEngine similarity calc failed, using fallback');
      return 0;
    }
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) return bytes + 'B';
    if (bytes < 1048576) return Math.round(bytes / 1024).toString() + 'KB';
    return (bytes / 1048576).toFixed(1) + 'MB';
  }

  private countFiles(node: TreeNode): number {
    let count = 0;
    for (const child of node.children) {
      if (!child.isDir) count++;
      else count += this.countFiles(child);
    }
    return count;
  }

  private openDiff(entry: FileEntry): void {
    AppStorage.setOrCreate('dirDiffContentA', entry.contentA);
    AppStorage.setOrCreate('dirDiffContentB', entry.contentB);
    AppStorage.setOrCreate('dirDiffNameA', entry.path);
    AppStorage.setOrCreate('dirDiffNameB', entry.path);
    router.pushUrl({ url: 'pages/DiffEditorPage' });
  }
}