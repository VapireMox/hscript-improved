package hscript.customclass;

import hscript.customclass.utils.FunctionUtils;
import haxe.Constraints.Function;
import hscript.Expr.FieldDecl;
import hscript.Expr.VarDecl;
import hscript.Expr.FunctionDecl;

@:structInit
class CustomClassDecl implements IHScriptCustomAccessBehaviour {
	public var classDecl:Expr.ClassDecl; //This holds the class instantiation info
	public var imports:Map<String, CustomClassImport>;
	public var pkg:Null<Array<String>> = null;

	public var staticInterp:Interp = new Interp();

	var _cachedStaticFields:Map<String, FieldDecl> = [];
	var _cachedStaticFunctions:Map<String, FunctionDecl> = [];
	var _cachedStaticVariables:Map<String, VarDecl> = [];

	public var __allowSetGet:Bool = true;

	public function cacheFields() {
		for (f in classDecl.fields) {
			if (f.access.contains(AStatic)) {
				_cachedStaticFields.set(f.name, f);
				switch (f.kind) {
					case KFunction(fn):
						_cachedStaticFunctions.set(f.name, fn);
						#if hscriptPos
						var fexpr:Expr = {
							e: ExprDef.EFunction(fn.args, fn.body, f.name, fn.ret, false, false),
							pmin: fn.body.pmin,
							pmax: fn.body.pmax,
							line: fn.body.line,
							origin: fn.body.origin
						};
						#else
						var fexpr = Expr.EFunction(fn.args, fn.body, f.name, fn.ret, false, false);
						#end
						var f0 = this.staticInterp.expr(fexpr);
						this.staticInterp.variables.set(f.name, f0);
					case KVar(v):
						_cachedStaticVariables.set(f.name, v);
						if (v.expr != null) {
							var varValue = this.staticInterp.expr(v.expr);
							this.staticInterp.variables.set(f.name, varValue);
						}
				}
			}
		}
	}

	public function callFunction(name:String, ?args:Array<Dynamic>):Dynamic {
		var func:Function = getFunction(name);

		return FunctionUtils.callStaticFunction(name, this, staticInterp, func, args != null ? args : []);
	}

	public function hasField(name:String):Bool {
		return _cachedStaticFields.exists(name);
	}

	private function hasFunction(name:String) {
		return _cachedStaticFunctions.exists(name);
	}

	private function getFunction(name:String):Function {
		var fn = this.staticInterp.variables.get(name);
		return Reflect.isFunction(fn) ? fn : null;
	}

	private function hasVar(name:String):Bool {
		return _cachedStaticVariables.exists(name);
	}

	private function getVar(name:String):Dynamic {
		var staticVar = _cachedStaticVariables.get(name);

		if(staticVar != null) {
			var varValue:Dynamic = null;
			if(!this.staticInterp.variables.exists(name)) {
				if(staticVar.expr != null) {
					varValue = this.staticInterp.expr(staticVar.expr);
					this.staticInterp.variables.set(name, varValue);
				}
			}
			else {
				varValue = this.staticInterp.variables.get(name);
			}
			return varValue;
		}

		return null;
	}

	/**
	 * Remove a function from the cache.
	 * This is useful when a function is broken and needs to be skipped.
	 * @param name The name of the function to remove from the cache.
	 */
	private function purgeFunction(name:String):Void {
		if (_cachedStaticFunctions != null) {
			_cachedStaticFunctions.remove(name);
		}
	}

	public function hget(name:String):Dynamic {
		var r:Dynamic = null;

		if(hasVar(name)) {
			if(__allowSetGet && hasFunction('get_${name}'))
				r = __callGetter(name);
			else 
				r = getVar(name);
			return r;
		}
		if(hasFunction(name)) {
			var fn:Function = Reflect.makeVarArgs(function(args:Array<Dynamic>) {
				return this.callFunction(name, args);
			});
			return fn;
		}

		throw "static field '" + name + "' does not exist in custom class '" + this.classDecl.name + "'";
	}

	public function hset(name:String, val:Dynamic):Dynamic {
		if (hasVar(name)) {
			if (__allowSetGet && hasFunction('set_${name}'))
				return __callSetter(name, val);
			else {
				this.staticInterp.variables.set(name, val);
				return val;
			}
		}

		throw "static field '" + name + "' does not exist in custom class '" + this.classDecl.name + "'";
	}

	public function __callGetter(name:String):Dynamic {
		__allowSetGet = false;
		var r = callFunction('get_${name}');
		__allowSetGet = true;
		return r;
	}

	public function __callSetter(name:String, val:Dynamic):Dynamic {
		__allowSetGet = false;
		var r = callFunction('set_${name}', [val]);
		__allowSetGet = true;
		return r;
	}
}

typedef CustomClassImport = {
	var ?name:String;
	var ?pkg:Array<String>;
	var ?fullPath:String; // pkg.pkg.pkg.name
}
