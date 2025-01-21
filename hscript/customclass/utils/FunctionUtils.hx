package hscript.customclass.utils;

import hscript.Expr.FunctionDecl;

@:access(hscript.customclass.CustomClassDecl)
class FunctionUtils {
    public static function callStaticFunction(name:String, classDecl:CustomClassDecl, interp:Interp, fn:FunctionDecl, args:Array<Dynamic> = null) {
		var r:Dynamic = null;

		var previousValues:Map<String, Dynamic> = [];
		var i = 0;
		for (a in fn.args) {
			var value:Dynamic = null;

			if (args != null && i < args.length) {
				value = args[i];
			} else if (a.value != null) {
				value = interp.expr(a.value);
			}
			// NOTE: We assign these as variables rather than locals because those get wiped when we enter the function.
			if (interp.variables.exists(a.name)) {
				previousValues.set(a.name, interp.variables.get(a.name));
			}
			interp.variables.set(a.name, value);
			i++;
		}
		try {
			r = interp.execute(fn.body);
		} catch (e:hscript.Expr.Error) {
			// A script error occurred while executing the script function.
			// Purge the function from the cache so it is not called again.
            classDecl.purgeFunction(name);
			interp.error(#if hscriptPos e.e #else e #end);
		}

		for (a in fn.args) {
			if (previousValues.exists(a.name)) {
				interp.variables.set(a.name, previousValues.get(a.name));
			} else {
				interp.variables.remove(a.name);
			}
		}

		return r;
	}
}