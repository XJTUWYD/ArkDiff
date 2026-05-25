import lineParserTest from './LineParser.test';
import lcsEngineTest from './LcsEngine.test';
import myersEngineTest from './MyersEngine.test';
import diffEngineTest from './DiffEngine.test';
import statsCalculatorTest from './StatsCalculator.test';

export default function testsuite() {
  lineParserTest();
  lcsEngineTest();
  myersEngineTest();
  diffEngineTest();
  statsCalculatorTest();
}
