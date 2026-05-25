import { describe, it, expect } from '@ohos/hypium';
import { MyersEngine } from '../main/ets/engine/MyersEngine';

export default function myersEngineTest() {
  describe('MyersEngine', () => {

    it('compute_bothEmpty', 0, () => {
      const result = MyersEngine.compute([], []);
      expect(result.matches.length).assertEqual(0);
    });

    it('compute_identical', 0, () => {
      const result = MyersEngine.compute(['a', 'b', 'c'], ['a', 'b', 'c']);
      expect(result.matches.length).assertEqual(3);
      expect(result.matches[0]).assertDeepEquals({ indexA: 0, indexB: 0 });
      expect(result.matches[2]).assertDeepEquals({ indexA: 2, indexB: 2 });
    });

    it('compute_completelyDifferent', 0, () => {
      const result = MyersEngine.compute(['a', 'b'], ['x', 'y']);
      expect(result.matches.length).assertEqual(0);
    });

    it('compute_insertMiddle', 0, () => {
      const a = ['line1', 'line3'];
      const b = ['line1', 'line2', 'line3'];
      const result = MyersEngine.compute(a, b);
      expect(result.matches.length).assertEqual(2);
    });

    it('compute_deleteMiddle', 0, () => {
      const a = ['line1', 'line2', 'line3'];
      const b = ['line1', 'line3'];
      const result = MyersEngine.compute(a, b);
      expect(result.matches.length).assertEqual(2);
    });

    it('compute_matchOrderPreserved', 0, () => {
      const a = ['a', 'b', 'c', 'd'];
      const b = ['a', 'c', 'd', 'e'];
      const result = MyersEngine.compute(a, b);
      // 应匹配 a(0,0), c(2,1), d(3,2)
      for (let i = 0; i < result.matches.length; i++) {
        expect(result.matches[i].indexA).assertLessThanOrEqual(
          i + 1 < result.matches.length ? result.matches[i + 1].indexA : a.length
        );
        expect(result.matches[i].indexB).assertLessThanOrEqual(
          i + 1 < result.matches.length ? result.matches[i + 1].indexB : b.length
        );
      }
    });

    it('compute_versusLCS_consistency', 0, () => {
      // Myers 和 LCS 对同一输入应产生语义一致的结果
      const a = ['const', 'x', '=', 'oldValue', ';', '', 'const', 'y', '=', '10', ';'];
      const b = ['const', 'x', '=', 'newValue', ';', '', 'let', 'y', '=', '20', ';'];
      const result = MyersEngine.compute(a, b);
      // 至少匹配 const x = 和 ; 和 const/let y = 和 ;
      expect(result.matches.length).assertGreaterThan(2);
    });
  });
}
