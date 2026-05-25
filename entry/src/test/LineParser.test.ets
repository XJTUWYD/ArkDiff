import { describe, it, expect } from '@ohos/hypium';
import { LineParser } from '../main/ets/engine/LineParser';

export default function lineParserTest() {
  describe('LineParser', () => {

    it('parseLines_emptyString', 0, () => {
      const result = LineParser.parseLines('');
      expect(result.length).assertEqual(1);
      expect(result[0]).assertEqual('');
    });

    it('parseLines_singleLine', 0, () => {
      const result = LineParser.parseLines('Hello World');
      expect(result.length).assertEqual(1);
      expect(result[0]).assertEqual('Hello World');
    });

    it('parseLines_multipleLines_LF', 0, () => {
      const result = LineParser.parseLines('line1\nline2\nline3');
      expect(result.length).assertEqual(3);
      expect(result[0]).assertEqual('line1');
      expect(result[1]).assertEqual('line2');
      expect(result[2]).assertEqual('line3');
    });

    it('parseLines_multipleLines_CRLF', 0, () => {
      const result = LineParser.parseLines('line1\r\nline2\r\nline3');
      expect(result.length).assertEqual(3);
      expect(result[0]).assertEqual('line1');
      expect(result[1]).assertEqual('line2');
      expect(result[2]).assertEqual('line3');
    });

    it('parseLines_trailingNewline', 0, () => {
      const result = LineParser.parseLines('line1\nline2\n');
      expect(result.length).assertEqual(3);
      expect(result[0]).assertEqual('line1');
      expect(result[1]).assertEqual('line2');
      expect(result[2]).assertEqual(''); // 尾随空行保留
    });

    it('parseLines_emptyLines', 0, () => {
      const result = LineParser.parseLines('line1\n\nline3');
      expect(result.length).assertEqual(3);
      expect(result[0]).assertEqual('line1');
      expect(result[1]).assertEqual('');
      expect(result[2]).assertEqual('line3');
    });

    it('filterBlankLines_removesWhitespaceOnly', 0, () => {
      const lines = ['hello', '   ', 'world', '', 'foo'];
      const result = LineParser.filterBlankLines(lines);
      expect(result.length).assertEqual(3);
      expect(result[0]).assertEqual('hello');
      expect(result[1]).assertEqual('world');
      expect(result[2]).assertEqual('foo');
    });

    it('filterBlankLines_allBlank', 0, () => {
      const lines = ['  ', '', '\t'];
      const result = LineParser.filterBlankLines(lines);
      expect(result.length).assertEqual(0);
    });
  });
}
