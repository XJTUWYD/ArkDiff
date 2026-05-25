import { describe, it, expect } from '@ohos/hypium';
import { LcsEngine } from '../main/ets/engine/LcsEngine';

export default function lcsEngineTest() {
  describe('LcsEngine', () => {

    it('compute_bothEmpty', 0, () => {
      const result = LcsEngine.compute([], []);
      expect(result.matches.length).assertEqual(0);
      expect(result.lengthA).assertEqual(0);
      expect(result.lengthB).assertEqual(0);
    });

    it('compute_oneEmpty', 0, () => {
      const result = LcsEngine.compute(['a', 'b', 'c'], []);
      expect(result.matches.length).assertEqual(0);
      expect(result.lengthA).assertEqual(3);
      expect(result.lengthB).assertEqual(0);
    });

    it('compute_identical', 0, () => {
      const result = LcsEngine.compute(['a', 'b', 'c'], ['a', 'b', 'c']);
      expect(result.matches.length).assertEqual(3);
      expect(result.matches[0].indexA).assertEqual(0);
      expect(result.matches[0].indexB).assertEqual(0);
      expect(result.matches[1].indexA).assertEqual(1);
      expect(result.matches[1].indexB).assertEqual(1);
      expect(result.matches[2].indexA).assertEqual(2);
      expect(result.matches[2].indexB).assertEqual(2);
    });

    it('compute_completelyDifferent', 0, () => {
      const result = LcsEngine.compute(['a', 'b', 'c'], ['x', 'y', 'z']);
      expect(result.matches.length).assertEqual(0);
    });

    it('compute_partialMatch', 0, () => {
      const a = ['line1', 'line2', 'line3', 'line4'];
      const b = ['line1', 'changed', 'line3', 'added'];
      const result = LcsEngine.compute(a, b);
      // 应匹配 line1(index 0,0) 和 line3(index 2,2)
      expect(result.matches.length).assertEqual(2);
      expect(result.matches[0]).assertDeepEquals({ indexA: 0, indexB: 0 });
      expect(result.matches[1]).assertDeepEquals({ indexA: 2, indexB: 2 });
    });

    it('compute_insertAtBeginning', 0, () => {
      const a = ['b', 'c'];
      const b = ['a', 'b', 'c'];
      const result = LcsEngine.compute(a, b);
      expect(result.matches.length).assertEqual(2);
      expect(result.matches[0]).assertDeepEquals({ indexA: 0, indexB: 1 });
      expect(result.matches[1]).assertDeepEquals({ indexA: 1, indexB: 2 });
    });

    it('compute_duplicateLines', 0, () => {
      const a = ['dup', 'unique_a', 'dup'];
      const b = ['dup', 'unique_b', 'dup'];
      const result = LcsEngine.compute(a, b);
      // LCS 可能匹配第一个 dup 或第二个 dup，但至少应匹配两端各一个
      expect(result.matches.length).assertGreaterThanOrEqual(2);
    });
  });
}
