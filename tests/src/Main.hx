#if BENCHMARK
import benchmark.*;
#else
import tests.*;
#end

class Main {
	public static var SHOW_KNOWN_BUGS:Bool = false;

	static function main() {
		#if BENCHMARK
		Sys.println("Running benchmark");
		
		//new Benchmark("Test", 1000);
		var haxeTotalTime:Float = 0;
		var hscriptTotalTime:Float = 0;

		var haxeTimes:Array<Float> = [];
		var hscriptTimes:Array<Float> = [];		

		var iterations:Int = 10;
		for (i in 0...iterations) {
			var benchmark:TestBenchmark = new TestBenchmark();

			haxeTimes.push(benchmark.haxeTotalTime);
			hscriptTimes.push(benchmark.hscriptTotalTime);

			haxeTotalTime += benchmark.haxeTotalTime;
			hscriptTotalTime += benchmark.hscriptTotalTime;
		}
		
		haxeTimes.sort((a, b) -> return a > b ? 1 : -1);
		hscriptTimes.sort((a, b) -> return a > b ? 1 : -1);
		
		var slowestHaxeTime:Float = haxeTimes[haxeTimes.length-1];
		var slowestHscriptTime:Float = hscriptTimes[hscriptTimes.length-1];
		var fastestHaxeTime:Float = haxeTimes[0];
		var fastestHscriptTime:Float = hscriptTimes[0];

		var haxeWon = hscriptTotalTime > haxeTotalTime;
		Sys.println('${haxeWon ? "Haxe" : "Hscript"} was faster overall (Faster by: ${Util.roundWith((haxeWon ? hscriptTotalTime/haxeTotalTime : haxeTotalTime/hscriptTotalTime), 100)}x)');
		Sys.println('Haxe average time: ${Util.convertToReadableTime(haxeTotalTime/iterations)} (Highest: ${Util.convertToReadableTime(slowestHaxeTime)}) (Lowest: ${Util.convertToReadableTime(fastestHaxeTime)})');
		Sys.println('Hscript average time: ${Util.convertToReadableTime(hscriptTotalTime/iterations)} (Highest: ${Util.convertToReadableTime(slowestHscriptTime)}) (Lowest: ${Util.convertToReadableTime(fastestHscriptTime)})');
		#else
		Sys.println("Beginning tests");
		if(!Main.SHOW_KNOWN_BUGS) {
			Sys.println("Hiding known bugs [TEMPORARY]");
		}
		runTest("Array", new ArrayCase());
		runTest("BinOp", new BinOpCase());
		runTest("Enum", new EnumCase());
		runTest("EvalOrder", new EvalOrderCase());
		runTest("Error", new ErrorCase());
		runTest("Float", new FloatCase());
		runTest("IntIterator", new IntIteratorCase());
		runTest("Lambda", new LambdaCase());
		runTest("List", new ListCase());
		runTest("Math", new MathCase());
		runTest("Map", new MapCase());
		runTest("Misc", new MiscCase());
		runTest("Reflect", new ReflectCase());
		runTest("Regex", new RegexCase());
		runTest("Std", new StdCase());
		runTest("String", new StringCase());
		runTest("StringBuf", new StringBufCase());
		runTest("StringTools", new StringToolsCase());
		runTest("SwitchStatement", new SwitchCase());
		// TODO: UnicodeCase.hx?
		// TODO: UnicodeStringCase.hx?
		runTest("Final", new FinalCase());
		Util.printTestResults();
		#end
	}

	#if !BENCHMARK
	static function runTest(name:String, test:TestCase) {
		Util.startUnitTest(name);
		test.setup();
		test.run();
		test.teardown();
		Util.endUnitTest();
	}
	#end
}
