import hscript.Expr.Error;
import hscript.Printer;
import haxe.Constraints.IMap;
import haxe.EnumTools.EnumValueTools;

using StringTools;

class Util {
	static inline function isNull(a:Dynamic):Bool {
		return Type.enumEq(Type.typeof(a), TNull);
	}

	static inline function isFunction(a:Dynamic):Bool {
		return Type.enumEq(Type.typeof(a), TFunction);
	}

	// TODO: check this for bugs
	// Code from https://github.com/elnabo/equals/blob/master/src/equals/Equal.hx, (MIT License), but updated to work with haxe 4
	public static function deepEqual<T> (a:T, b:T) : Bool {
		if (a == b) { return true; } // if physical equality
		if (isNull(a) ||  isNull(b)) {
			return false;
		}

		switch (Type.typeof(a)) {
			case TNull, TInt, TBool, TUnknown:
				return a == b;
			case TFloat:
				return Math.isNaN(cast a) && Math.isNaN(cast b); // only valid true result remaining
			case TFunction:
				return Reflect.compareMethods(a, b); // only physical equality can be tested for function
			case TEnum(_):
				if (EnumValueTools.getIndex(cast a) != EnumValueTools.getIndex(cast b)) {
					return false;
				}
				var a_args = EnumValueTools.getParameters(cast a);
				var b_args = EnumValueTools.getParameters(cast b);
				return deepEqual(a_args, b_args);
			case TClass(_):
				if ((a is String) && (b is String)) {
					return a == b;
				}
				if ((a is Array) && (b is Array)) {
					var a = cast(a, Array<Dynamic>);
					var b = cast(b, Array<Dynamic>);
					if (a.length != b.length) { return false; }
					for (i in 0...a.length) {
						if (!deepEqual(a[i], b[i])) {
							return false;
						}
					}
					return true;
				}

				if ((a is IMap) && (b is IMap)) {
					var a = cast(a, IMap<Dynamic, Dynamic>);
					var b = cast(b, IMap<Dynamic, Dynamic>);
					var a_keys = [ for (key in a.keys()) key ];
					var b_keys = [ for (key in b.keys()) key ];
					a_keys.sort(Reflect.compare);
					b_keys.sort(Reflect.compare);
					if (!deepEqual(a_keys, b_keys)) { return false; }
					for (key in a_keys) {
						if (!deepEqual(a.get(key), b.get(key))) {
							return false;
						}
					}
					return true;
				}

				if ((a is Date) && (b is Date)) {
					return cast(a, Date).getTime() == cast(b, Date).getTime();
				}

				if ((a is haxe.io.Bytes) && (b is haxe.io.Bytes)) {
					return deepEqual(cast(a, haxe.io.Bytes).getData(), cast(b, haxe.io.Bytes).getData());
				}

			case TObject:
		}

		for (field in Reflect.fields(a)) {
			var pa = Reflect.field(a, field);
			var pb = Reflect.field(b, field);
			if (isFunction(pa)) {
				// ignore function as only physical equality can be tested, unless null
				if (isNull(pa) != isNull(pb)) {
					return false;
				}
				continue;
			}
			if (!deepEqual(pa, pb)) {
				return false;
			}
		}

		return true;
	}

	public static inline function passed() {
		passedTestUnits++;
		return true;
	}

	public static inline function failed() {
		failedTestUnits++;
		return false;
	}


	public static function assert(value:Bool, message:String, ?pos:haxe.PosInfos) {
		if (value) {
			return passed();
		} else {
			Sys.println("Assertion failed: " + message);
			Sys.println("> At " + pos.fileName + ":" + pos.lineNumber);
			return failed();
		}
	}

	public static function assertEq(value:Dynamic, expected:Dynamic, message:String, ?pos:haxe.PosInfos) {
		var equals = deepEqual(value, expected);
		var _passed = equals;

		if (_passed) {
			return passed();
		} else {
			Sys.println("Assertion failed: " + message + " Expected: " + expected + " Got: " + value);
			Sys.println("> At " + pos.fileName + ":" + pos.lineNumber);
			return failed();
		}
	}

	public static function assertEqPrintable(value:Dynamic, expected:Dynamic, message:String, ?pos:haxe.PosInfos) {
		var equals = deepEqual(value, expected);
		var _passed = equals;

		if (_passed) {
			return passed();
		} else {
			Sys.println("Assertion failed: " + message + " Expected: " + Printer.getEscapedString(expected) + " Got: " + Printer.getEscapedString(value));
			Sys.println("> At " + pos.fileName + ":" + pos.lineNumber);
			return failed();
		}
	}

	public static function assertNeq(value:Dynamic, expected:Dynamic, message:String, ?pos:haxe.PosInfos) {
		var equals = deepEqual(value, expected);
		var _passed = !equals;

		// WARNING THIS MIGHT NOT WORK

		if (_passed) {
			return passed();
		} else {
			Sys.println("Assertion failed: " + message + " Expected: " + expected + " Got: " + value);
			Sys.println("> At " + pos.fileName + ":" + pos.lineNumber);
			return failed();
		}
	}

	static var currentTestPath:Array<String> = [];
	static var totalTestUnits:Int = 0;
	static var passedTestUnits:Int = 0;
	static var failedTestUnits:Int = 0;
	static var skippedKnownBugs:Int = 0;

	public static function runKnownBug(name:String, func:Void->Void) {
		if (Main.SHOW_KNOWN_BUGS) {
			Sys.println("Running known bug: " + name);
			func();
		} else {
			skippedKnownBugs++;
		}
	}

	public static function startUnitTest(path:String) {
		Sys.println("Running unit tests in " + path);
		currentTestPath.push(path);
		totalTestUnits++;
	}

	public static function endUnitTest() {
		var path = currentTestPath.pop();
		//Sys.println("Finished unit tests " + path);
	}

	public static function printTestResults() {
		Sys.println(Util.getTitle('RESULTS'));
		Sys.println("Total Units: " + totalTestUnits);
		Sys.println("Total tests passed: " + passedTestUnits);
		Sys.println("Total tests failed: " + failedTestUnits);
		if(skippedKnownBugs > 0)
			Sys.println("Skipped known bugs: " + skippedKnownBugs);
		//Sys.println("Finished unit tests " + currentTestPath.pop());
		Sys.println(Util.getTitle('RESULTS'));
	}

	public static function parse(str:String) {
		var p = new Parser();
		p.allowTypes = true;
		p.allowMetadata = true;
		p.allowJSON = true;
		var result = null;
		try {
			result = p.parseString(str);
		} catch (e:Dynamic) {
			Sys.println("## Error parsing: " + str);
			Sys.println("## Error: " + e);
			// Print stack trace
			var stack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
			Sys.println("## Stack trace: " + stack);
			Sys.exit(1);
		}
		return result;
	}

	/**
	 * Parses a string without checking for errors
	 */
	public static function parseUnsafe(str:String) {
		var p = new Parser();
		p.allowTypes = true;
		p.allowMetadata = true;
		p.allowJSON = true;
		return p.parseString(str);
	}

	public static var defaultImport = true;

	public static function getInterp() {
		var interp = new Interp();
		//interp.importEnabled = true;
		//interp.allowStaticVariables = true;
		//interp.allowPublicVariables = true;
		if(defaultImport) {
			interp.variables.set("Math", Math);
			interp.variables.set("Std", Std);
			interp.variables.set("Type", Type);
			interp.variables.set("StringTools", StringTools);
		}
		return interp;
	}

	public static inline function getTime():Float {
		return untyped __global__.__time_stamp();
	}

	// expandScientificNotation but its WAY too long to write out
	public static function exScienceN(value:Float):String {
		var parts = Std.string(value).split("e");
		var coefficient = Std.parseFloat(parts[0]);
		var exponent = parts.length > 1 ? Std.parseInt(parts[1]) : 0;
		var result = "";

		if (exponent > 0) {
			result += StringTools.replace(Std.string(coefficient), ".", "");
			var decimalLength = Std.string(coefficient).split(".")[1].length;
			var additionalZeros:Int = Std.int(Math.abs(exponent - decimalLength));
			result += StringTools.lpad("", "0", additionalZeros); // repeat
		} else {
			result += "0.";
			var leadingZeros:Int = Std.int(Math.abs(exponent) - 1);
			result += StringTools.lpad("", "0", leadingZeros); // repeat
			result += StringTools.replace(Std.string(coefficient), ".", "");
		}

		return result;
	}

	public static function convertToReadableTime(seconds:Float) {
		if (seconds >= 1) return seconds + " s";
		var milliseconds = seconds * 1000;       // 1 second = 1,000 ms
		if (milliseconds >= 1) return milliseconds + " ms";
		var microseconds = seconds * 1000000;   // 1 second = 1,000,000 μs
		if (microseconds >= 1) return microseconds + " μs";
		var nanoseconds = seconds * 1000000000; // 1 second = 1,000,000,000 ns
		return nanoseconds + " ns";
	}

	public static function errorHandler(error:Error) {
		#if hscriptPos
		var fileName = error.origin;
		var fn = '$fileName:${error.line}: ';
		#else
		var fn = '';
		#end
		var err = Std.string(error);
		if (err.startsWith(fn)) err = err.substr(fn.length);

		Sys.println("ERROR: " + fn + err);
		//Logs.traceColored([
		//	Logs.logText(fn, GREEN),
		//	Logs.logText(err, RED)
		//], ERROR);
	}

	public static function deepCompareArrays(a1: Array<Dynamic>, a2: Array<Dynamic>): Bool {
		if (a1.length != a2.length)
			return false;

		for (i in 0...a1.length) {
			var item1 = a1[i];
			var item2 = a2[i];

			if (Std.isOfType(item1, Array) && Std.isOfType(item2, Array)) {
				if (!deepCompareArrays(item1, item2))
					return false;
			} else if (item1 != item2)
				return false;
		}
		return true;
	}

	public static function roundDecimal(Value:Float, Precision:Int):Float {
		var mult:Float = 1;
		for (i in 0...Precision)
			mult *= 10;
		return Math.fround(Value * mult) / mult;
	}

	public inline static function roundWith(Value:Float, Mult:Int):Float {
		return Math.fround(Value * Mult) / Mult;
	}

	public static function getTitle(title:String, ?dashsLen:Int = 46) {
		var l = StringTools.lpad("", "-", Std.int((dashsLen - title.length - 2)/2));
		return l + ' $title ' + l;
	}
}