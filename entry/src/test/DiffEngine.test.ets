import { describe, it, expect } from '@ohos/hypium';
import { DiffEngine } from '../main/ets/engine/DiffEngine';
import { DiffType, DiffOptions } from '../main/ets/model/DiffModels';

const defaultOptions: DiffOptions = {
  ignoreBlankLines: false,
  enableCharDiff: false
};

export default function diffEngineTest() {
  describe('DiffEngine', () => {

    it('computeDiff_identicalTexts', 0, () => {
      const text = 'line1\nline2\nline3';
      const result = DiffEngine.computeDiff(text, text, defaultOptions);
      expect(result.unifiedLines.length).assertEqual(3);
      for (let i = 0; i < result.unifiedLines.length; i++) {
        expect(result.unifiedLines[i].type).assertEqual(DiffType.UNCHANGED);
      }
      expect(result.stats.addedCount).assertEqual(0);
      expect(result.stats.deletedCount).assertEqual(0);
      expect(result.stats.similarityPercent).assertEqual(100);
    });

    it('computeDiff_oneLineAdded', 0, () => {
      const a = 'line1\nline2';
      const b = 'line1\nline1.5\nline2';
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      expect(result.stats.addedCount).assertEqual(1);
      expect(result.stats.deletedCount).assertEqual(0);
      expect(result.stats.unchangedCount).assertEqual(2);
    });

    it('computeDiff_oneLineDeleted', 0, () => {
      const a = 'line1\nline2\nline3';
      const b = 'line1\nline3';
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      expect(result.stats.deletedCount).assertEqual(1);
      expect(result.stats.addedCount).assertEqual(0);
    });

    it('computeDiff_oneLineModified', 0, () => {
      const a = 'line1\nold line2\nline3';
      const b = 'line1\nnew line2\nline3';
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      // Modified: 相邻的 delete+add 合并
      expect(result.stats.modifiedCount).assertEqual(1);
      expect(result.stats.unchangedCount).assertEqual(2);
    });

    it('computeDiff_completelyDifferent', 0, () => {
      const a = 'aaaa\nbbbb\ncccc';
      const b = 'xxxx\nyyyy\nzzzz';
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      expect(result.stats.unchangedCount).assertEqual(0);
      expect(result.stats.similarityPercent).assertEqual(0);
    });

    it('computeDiff_multipleBlocks', 0, () => {
      const a = 'A1\nB1\nC1\nD1\nE1';
      const b = 'A1\nB2\nC1\nD2\nE1';
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      // B1→B2 一处修改，D1→D2 又一处 → 应有 2 个差异块
      expect(result.stats.diffBlockCount).assertEqual(2);
    });

    it('computeDiff_sideBySideLinesMatchCount', 0, () => {
      const a = 'line1\nline2';
      const b = 'line1\nadded\nline2';
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      // SBS 左右列行数应一致
      expect(result.leftLines.length).assertEqual(result.rightLines.length);
    });

    it('computeDiff_elapsedMs', 0, () => {
      const a = Array.from({ length: 100 }, (_, i) => `line${i}`).join('\n');
      const b = Array.from({ length: 100 }, (_, i) => `line${i}`).join('\n');
      const result = DiffEngine.computeDiff(a, b, defaultOptions);
      expect(result.elapsedMs).assertGreaterThanOrEqual(0);
    });

    it('computeDiff_ignoreBlankLines', 0, () => {
      const a = 'hello\n\nworld';
      const b = 'hello\n\n\nworld';
      const options: DiffOptions = { ignoreBlankLines: true, enableCharDiff: false };
      const result = DiffEngine.computeDiff(a, b, options);
      // 忽略空白行后，hello 和 world 匹配，应无差异
      expect(result.stats.addedCount).assertEqual(0);
      expect(result.stats.deletedCount).assertEqual(0);
    });
  });
}
