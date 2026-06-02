/**
 * AegisDiff — LazyDiffDataSource（LazyForEach 数据源）
 *
 * 实现 IDataSource 接口，支持大 diff 列表的虚拟滚动。
 * 当 unifiedLines 行数 > 500 时使用 LazyForEach 替代 ForEach。
 */
import { DiffLine } from '../model/DiffModels';

export interface DisplayItem {
  kind: number;
  lineIdx: number;
  gapCount: number;
}

class LazyDisplayItem {
  data: DisplayItem = { kind: 0, lineIdx: 0, gapCount: 0 };
  listener?: DataChangeListener;
}

export class LazyDiffDataSource implements IDataSource {
  private items: LazyDisplayItem[] = [];
  private listeners: DataChangeListener[] = [];

  setItems(items: DisplayItem[]): void {
    this.items = items.map(item => {
      let lazy = new LazyDisplayItem();
      lazy.data = item;
      return lazy;
    });
    this.notifyDataReload();
  }

  totalCount(): number {
    return this.items.length;
  }

  getData(index: number): DisplayItem {
    return this.items[index].data;
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    });
  }

  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    });
  }

  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    });
  }

  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    });
  }
}
