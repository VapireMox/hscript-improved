package tests;

import hscript.Printer;
import hscript.Tools;
import hscript.Expr.Error;

@:access(hscript.Interp)
@:access(hscript.Parser)
class TestCase extends HScriptRunner {
	public function assertEq(script:String, expected:Dynamic, ?message:String, ?vars:Dynamic, ?pos:haxe.PosInfos) {
		if(message == null)
			message = script;
		var result = if(vars != null)
			executeWithVars(script, vars);
		else
			execute(script);
		if(!Util.assertEq(result, expected, message, pos)) {
			Sys.println("> " + Printer.convertExprToString(lastExpr));
			Sys.println("> " + interp._variablesNames);
			Sys.println("> " + interp._variables);
			return false;
		}
		return true;
	}

	public function assertCompiles(script:String, ?message:String, ?pos:haxe.PosInfos) {
		if(message == null)
			message = script;
		try {
			var result = Util.parseUnsafe(script);
		} catch(e:Error) {
			var e = Printer.getPrintableError(e);
			Sys.println("# Error trying to compile: " + script);
			Sys.println("## Error: " + e);
			return Util.failed();
		}
		return Util.passed();
	}

	public function assertError(script:String, expectedError:Error, ?message:String, ?vars:Dynamic, ?pos:haxe.PosInfos) {
		var expectedError = Printer.getPrintableError(expectedError);
		if(message == null)
			message = script;
		try {
			var result = if(vars != null)
				executeWithVarsUnsafe(script, vars);
			else
				executeUnsafe(script);
			Sys.println("# For script: " + script);
			Sys.println("## Expected error: " + expectedError);
			Sys.println("## Got result: " + result);
			Sys.println("> " + Printer.convertExprToString(lastExpr));
			return Util.failed();
		} catch(e:hscript.Error) {
			var e = Printer.getPrintableError(e);
			if(Type.enumEq(e, expectedError)) {
				return Util.passed();
			} else {
				Sys.println("# For script: " + script);
				Sys.println("## Expected error: " + expectedError);
				Sys.println("## Actual error: " + e);
				return Util.failed();
			}
		}
		return Util.failed();
	}

	public function assertEqPrintable(script:String, expected:Dynamic, ?message:String, ?vars:Dynamic, ?pos:haxe.PosInfos) {
		if(message == null)
			message = script;
		var result = if(vars != null)
			executeWithVars(script, vars);
		else
			execute(script);
		if(!Util.assertEqPrintable(result, expected, message, pos)) {
			Sys.println("> " + Printer.convertExprToString(lastExpr));
			return false;
		}
		return true;
	}

	public function assertNeq(script:String, expected:Dynamic, ?message:String, ?vars:Dynamic, ?pos:haxe.PosInfos) {
		if(message == null)
			message = script;
		var result = if(vars != null)
			executeWithVars(script, vars);
		else
			execute(script);
		if(!Util.assertNeq(result, expected, message, pos)) {
			Sys.println("> " + Printer.convertExprToString(lastExpr));
			return false;
		}
		return true;
	}
}