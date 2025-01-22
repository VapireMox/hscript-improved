package hscript.customclass.utils;

import hscript.utils.UnsafeReflect;
import haxe.Constraints.Function;

@:access(hscript.customclass.CustomClassDecl)
class FunctionUtils {
	public static inline function callStaticFunction(name:String, classDecl:CustomClassDecl, interp:Interp, fn:Function, args:Array<Dynamic> = null) {
		var r:Dynamic = null;

		try {
			if (fn == null)
				interp.error(ECustom('${name} is not a function'));

			r = UnsafeReflect.callMethodUnsafe(null, fn, args);
		} catch (e:hscript.Expr.Error) {
			// A script error occurred while executing the custom class function.
			// Purge the function from the cache so it is not called again.
			classDecl.purgeFunction(name);
			interp.error(#if hscriptPos e.e #else e #end);
		}

		return r;
	}
}