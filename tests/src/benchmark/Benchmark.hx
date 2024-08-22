package benchmark;

import hscript.Expr;

class Benchmark extends HScriptRunner {
	public var haxeTimes:Array<Float> = [];
	public var haxeTotalTime:Float = 0;

	public var hscriptTimes:Array<Float> = [];
	public var hscriptTotalTime:Float = 0;

	public function new(name:String, iterations:Int) {
		super();
		doBenchmark(name, iterations);
	}

	public function doBenchmark(name:String, iterations:Int) {
		haxeTimes = cast new haxe.ds.Vector<Float>(iterations);
		hscriptTimes = cast new haxe.ds.Vector<Float>(iterations);

		for (i in 0...iterations) {
			reset();
			var haxeStartTime:Float = Util.getTime();
			haxeBenchmark();
			var haxeEndTime:Float = Util.getTime();
			haxeTimes[i] = haxeEndTime-haxeStartTime;

			reset();
			var hscriptStartTime:Float = Util.getTime();
			hscriptBenchmark();
			var hscriptEndTime:Float = Util.getTime();
			hscriptTimes[i] = hscriptEndTime-hscriptStartTime;
		}

		haxeTimes.sort(Reflect.compare);
		hscriptTimes.sort(Reflect.compare);

		for (time in haxeTimes) haxeTotalTime += time;
		for (time in hscriptTimes) hscriptTotalTime += time;

		Sys.println(Util.getTitle('$name BENCHMARK'));

		if ((haxeTotalTime == 0 || hscriptTotalTime == 0) || (haxeTimes.length <= 0 || hscriptTimes.length <= 0)) {
			Sys.println('BENCHMARK UNNOTICABLE, TOOK 0 SECONDS');
		} else {
			var haxeWon = hscriptTotalTime > haxeTotalTime;
			Sys.println('${haxeWon ? "Haxe" : "Hscript"} was faster overall (Faster by: ${Util.roundWith((haxeWon ? hscriptTotalTime/haxeTotalTime : haxeTotalTime/hscriptTotalTime), 100)}x)');
			Sys.println('Haxe average time: ${Util.convertToReadableTime(haxeTotalTime/iterations)} (Highest: ${haxeTimes[haxeTimes.length-1]})');
			Sys.println('Hscript average time: ${Util.convertToReadableTime(hscriptTotalTime/iterations)} (Highest: ${hscriptTimes[haxeTimes.length-1]})');
		}

		Sys.println(Util.getTitle('$name BENCHMARK'));
	}

	public function reset() {}

	public var expr:Expr;

	public inline function cacheExpr(script:String) {
		interp = getNewInterp();
		interp.variables.set("self", this);
		interp.scriptObject = this;
		expr = Util.parse(headerCode + script + tailCode);
	}

	public override function execute(script:String):Dynamic {
		if (expr == null)
			cacheExpr(script);
		return interp.execute(expr);
	}

	public function haxeBenchmark() {}
	public function hscriptBenchmark() {}
}