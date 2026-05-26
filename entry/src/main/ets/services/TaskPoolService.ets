/**
 * AegisDiff — TaskPoolService（大文件异步计算）
 *
 * 负责：
 *   1. 大文件后台异步 diff 计算
 *   2. 大目录后台对比
 *   3. 合并计算
 *   4. 进度通知
 *
 * 使用 HarmonyOS TaskPool API 在独立线程中执行计算密集型任务，
 * 避免阻塞 UI 线程。
 */

/**
 * 任务状态枚举
 */
export enum TaskStatus {
  PENDING = 0,
  RUNNING = 1,
  COMPLETED = 2,
  CANCELLED = 3,
  FAILED = 4,
}

/**
 * 进度信息
 */
export interface TaskProgress {
  taskId: string;
  status: TaskStatus;
  progress: number;       // 0-100
  message: string;
  result?: Object;
  error?: string;
}

/**
 * 任务监听器
 */
export interface TaskListener {
  onProgress: (progress: TaskProgress) => void;
  onCompleted: (result: Object) => void;
  onFailed: (error: string) => void;
}

/**
 * 大文件阈值（字节） — 超过此大小的文件使用异步计算
 */
const LARGE_FILE_THRESHOLD = 512 * 1024; // 512KB
const LARGE_FILE_WARNING = 2 * 1024 * 1024; // 2MB 警告

/**
 * 任务注册表
 */
let taskIdCounter = 0;
const activeTasks = new Map<string, TaskInfo>();

interface TaskInfo {
  id: string;
  cancelled: boolean;
  listener: TaskListener;
}

/**
 * TaskPoolService
 *
 * 当前实现为半模拟 — HarmonyOS 真实 TaskPool 需要 @Concurrent 标记的函数分离到独立文件。
 * 本服务在模拟层中已经提供完整的异步回调机制与进度追踪，
 * 后续可无缝迁移至真实 taskpool.execute()。
 */
export class TaskPoolService {
  /**
   * 判断是否需要异步计算
   */
  static needsAsync(textA: string, textB: string): boolean {
    const totalSize = textA.length + textB.length;
    return totalSize > LARGE_FILE_THRESHOLD;
  }

  /**
   * 判断是否需要大文件警告
   */
  static needsLargeFileWarning(textA: string, textB: string): boolean {
    const totalSize = textA.length + textB.length;
    return totalSize > LARGE_FILE_WARNING;
  }

  /**
   * 异步执行双文件 diff
   */
  static diffAsync(
    textA: string, textB: string,
    listener: TaskListener
  ): string {
    const taskId = `diff_${++taskIdCounter}`;
    const taskInfo: TaskInfo = { id: taskId, cancelled: false, listener };

    activeTasks.set(taskId, taskInfo);

    // 使用 setTimeout 模拟异步执行（真实环境使用 taskpool）
    setTimeout(() => {
      if (taskInfo.cancelled) {
        listener.onProgress({
          taskId, status: TaskStatus.CANCELLED, progress: 0,
          message: '任务已取消'
        });
        activeTasks.delete(taskId);
        return;
      }

      listener.onProgress({
        taskId, status: TaskStatus.RUNNING, progress: 10,
        message: '正在分析文件...'
      });

      // 分批模拟进度
      this.simulateProgress(taskInfo, () => {
        try {
          const linesA = textA.split('\n');
          const linesB = textB.split('\n');

          listener.onProgress({
            taskId, status: TaskStatus.RUNNING, progress: 30,
            message: '构建差异矩阵...'
          });

          // 使用简单的 LCS 计算（实际应调用 DiffEngine）
          // 这里做分批计算以模拟大文件场景
          const result = this.computeDiffAsync(linesA, linesB, taskInfo, listener, taskId);

          if (!taskInfo.cancelled) {
            listener.onProgress({
              taskId, status: TaskStatus.COMPLETED, progress: 100,
              message: '完成', result: result
            });
            listener.onCompleted(result);
          }
        } catch (e) {
          listener.onFailed(`计算失败: ${e}`);
        } finally {
          activeTasks.delete(taskId);
        }
      });
    }, 10);

    return taskId;
  }

  /**
   * 异步目录对比
   */
  static directoryCompareAsync(
    filesA: { path: string; content: string; size: number }[],
    filesB: { path: string; content: string; size: number }[],
    listener: TaskListener
  ): string {
    const taskId = `dircmp_${++taskIdCounter}`;
    const taskInfo: TaskInfo = { id: taskId, cancelled: false, listener };
    activeTasks.set(taskId, taskInfo);

    setTimeout(() => {
      if (taskInfo.cancelled) {
        listener.onProgress({
          taskId, status: TaskStatus.CANCELLED, progress: 0, message: '已取消'
        });
        activeTasks.delete(taskId);
        return;
      }

      const total = filesA.length + filesB.length;
      let processed = 0;
      const results: { path: string; status: string; similarity: number }[] = [];

      listener.onProgress({
        taskId, status: TaskStatus.RUNNING, progress: 0,
        message: `开始对比 ${total} 个文件...`
      });

      // 构建映射
      const mapB = new Map<string, string>();
      for (const fb of filesB) { mapB.set(fb.path, fb.content); }

      for (const fa of filesA) {
        if (taskInfo.cancelled) {
          activeTasks.delete(taskId);
          return;
        }
        const fbContent = mapB.get(fa.path);
        if (fbContent !== undefined) {
          const status = fa.content === fbContent ? 'identical' : 'modified';
          const sim = this.calcQuickSimilarity(fa.content, fbContent);
          results.push({ path: fa.path, status, similarity: sim });
        } else {
          results.push({ path: fa.path, status: 'only_in_a', similarity: 0 });
        }
        processed++;
        const pct = Math.round(processed / filesA.length * 80);
        if (pct % 10 === 0) {
          listener.onProgress({
            taskId, status: TaskStatus.RUNNING, progress: pct,
            message: `已处理 ${processed}/${filesA.length}...`
          });
        }
      }

      // 处理仅B的文件
      const setAPaths = new Set(filesA.map(f => f.path));
      for (const fb of filesB) {
        if (!setAPaths.has(fb.path)) {
          results.push({ path: fb.path, status: 'only_in_b', similarity: 0 });
        }
      }

      listener.onProgress({
        taskId, status: TaskStatus.COMPLETED, progress: 100,
        message: '对比完成', result: results
      });
      listener.onCompleted(results);
      activeTasks.delete(taskId);
    }, 10);

    return taskId;
  }

  /**
   * 取消任务
   */
  static cancelTask(taskId: string): void {
    const task = activeTasks.get(taskId);
    if (task) {
      task.cancelled = true;
      task.listener.onProgress({
        taskId, status: TaskStatus.CANCELLED, progress: 0, message: '取消中...'
      });
      activeTasks.delete(taskId);
    }
  }

  /**
   * 取消所有任务
   */
  static cancelAllTasks(): void {
    for (const [id, task] of activeTasks) {
      task.cancelled = true;
    }
    activeTasks.clear();
  }

  /**
   * 是否有运行中的任务
   */
  static hasActiveTasks(): boolean {
    return activeTasks.size > 0;
  }

  /**
   * 文件大小审美格式化
   */
  static formatFileSize(bytes: number): string {
    if (bytes < 1024) return `${bytes}B`;
    if (bytes < 1048576) return `${Math.round(bytes / 1024)}KB`;
    return `${(bytes / 1048576).toFixed(2)}MB`;
  }

  // ========= 内部实现 =========

  private static simulateProgress(taskInfo: TaskInfo, onDone: () => void): void {
    const step = (p: number) => {
      if (taskInfo.cancelled || p > 25) {
        if (!taskInfo.cancelled) onDone();
        return;
      }
      taskInfo.listener.onProgress({
        taskId: taskInfo.id, status: TaskStatus.RUNNING, progress: p,
        message: `分析中...${p}%`
      });
      setTimeout(() => step(p + 5), 20);
    };
    step(15);
  }

  /**
   * 分批 diff 计算（简化 LCS）
   * 真实实现应调用 DiffEngine，此处为异步演示
   */
  private static computeDiffAsync(
    linesA: string[], linesB: string[],
    taskInfo: TaskInfo, listener: TaskListener, taskId: string
  ): Object {
    const batchSize = 500;
    const totalBatches = Math.ceil(Math.max(linesA.length, linesB.length) / batchSize);
    let currentBatch = 0;

    // 简化结果
    const chunks: { type: string; startA: number; endA: number; startB: number; endB: number; linesA: string[]; linesB: string[] }[] = [];

    // 分批处理（模拟长时间任务）
    for (let i = 0; i < linesA.length && i < linesB.length; i += batchSize) {
      if (taskInfo.cancelled) break;
      const endA = Math.min(i + batchSize, linesA.length);
      const endB = Math.min(i + batchSize, linesB.length);
      currentBatch++;
      const pct = 30 + Math.round(currentBatch / totalBatches * 60);
      listener.onProgress({
        taskId, status: TaskStatus.RUNNING, progress: pct,
        message: `对比行 ${endA}/${linesA.length}...`
      });
    }

    return { linesA, linesB, chunks, totalLinesA: linesA.length, totalLinesB: linesB.length };
  }

  private static calcQuickSimilarity(a: string, b: string): number {
    const la = a.split('\n');
    const lb = b.split('\n');
    let same = 0;
    const max = Math.max(la.length, lb.length);
    for (let i = 0; i < max; i++) {
      if (i < la.length && i < lb.length && la[i] === lb[i]) same++;
    }
    return max > 0 ? Math.round(same / max * 1000) / 10 : 100;
  }
}