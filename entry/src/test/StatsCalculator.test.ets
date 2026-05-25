import { describe, it, expect } from '@ohos/hypium';
import { StatsCalculator } from '../main/ets/engine/StatsCalculator';
import { DiffLine, DiffType } from '../main/ets/model/DiffModels';

function makeLine(type: DiffType, lineNumberA: number, lineNumberB: number, content: string): DiffLine {
  return {
    lineNumberA,
    lineNumberB,
    content,
    type,
    charSegments: []
  };
}

export default function statsCalculatorTest() {
  describe('StatsCalculator', () => {

    it('calculate_emptyLines', 0, () => {
      const stats = StatsCalculator.calculate([]);
      expect(stats.addedCount).assertEqual(0);
      expect(stats.deletedCount).assertEqual(0);
      expect(stats.modifiedCount).assertEqual(0);
      expect(stats.unchangedCount).assertEqual(0);
      expect(stats.similarityPercent).assertEqual(100);
      expect(stats.diffBlockCount).assertEqual(0);
    });

    it('calculate_allUnchanged', 0, () => {
      const lines: DiffLine[] = [
        makeLine(DiffType.UNCHANGED, 1, 1, 'a'),
        makeLine(DiffType.UNCHANGED, 2, 2, 'b'),
        makeLine(DiffType.UNCHANGED, 3, 3, 'c'),
      ];
      const stats = StatsCalculator.calculate(lines);
      expect(stats.unchangedCount).assertEqual(3);
      expect(stats.similarityPercent).assertEqual(100);
      expect(stats.diffBlockCount).assertEqual(0);
    });

    it('calculate_allAdded', 0, () => {
      const lines: DiffLine[] = [
        makeLine(DiffType.ADDED, -1, 1, 'x'),
        makeLine(DiffType.ADDED, -1, 2, 'y'),
      ];
      const stats = StatsCalculator.calculate(lines);
      expect(stats.addedCount).assertEqual(2);
      expect(stats.similarityPercent).assertEqual(0);
      expect(stats.diffBlockCount).assertEqual(1);
    });

    it('calculate_mixed', 0, () => {
      const lines: DiffLine[] = [
        makeLine(DiffType.UNCHANGED, 1, 1, 'keep'),
        makeLine(DiffType.DELETED, 2, -1, 'old'),
        makeLine(DiffType.ADDED, -1, 2, 'new'),
        makeLine(DiffType.UNCHANGED, 3, 3, 'keep2'),
        makeLine(DiffType.MODIFIED, 4, 4, 'changed'),
        makeLine(DiffType.UNCHANGED, 5, 5, 'keep3'),
      ];
      const stats = StatsCalculator.calculate(lines);
      expect(stats.unchangedCount).assertEqual(3);
      expect(stats.addedCount).assertEqual(1);
      expect(stats.deletedCount).assertEqual(1);
      expect(stats.modifiedCount).assertEqual(1);
      expect(stats.diffBlockCount).assertEqual(2);
      expect(stats.similarityPercent).assertEqual(50);
    });

    it('calculate_similarityHalf', 0, () => {
      const lines: DiffLine[] = [
        makeLine(DiffType.UNCHANGED, 1, 1, 'a'),
        makeLine(DiffType.DELETED, 2, -1, 'b'),
        makeLine(DiffType.ADDED, -1, 2, 'c'),
      ];
      const stats = StatsCalculator.calculate(lines);
      // 1 unchanged / 3 total = 33.3%
      expect(stats.similarityPercent).assertEqual(33.3);
    });
  });
}
