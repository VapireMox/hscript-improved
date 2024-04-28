/*
 * Copyright (C)2008-2017 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/*
 * YoshiCrafter Engine fixes:
 * - Added Error handler
 * - Added Imports
 * - Added @:bypassAccessor
 */
package hscript;

import haxe.Constraints.IMap;
import haxe.EnumTools;
import haxe.PosInfos;
import haxe.display.Protocol.InitializeResult;
import haxe.iterators.StringKeyValueIteratorUnicode;
import hscript.Expr;
import hscript.utils.UnsafeReflect;
import haxe.iterators.ArrayIterator;

using StringTools;

private enum Stop {
	SBreak;
	SContinue;
	SReturn;
}

enum abstract ScriptObjectType(Int) {
	var SClass;
	var SObject;
	var SStaticClass;
	var SNull;
}

@:structInit
class DeclaredVar {
	public var r:Dynamic;
	public var depth:Int;
}

@:structInit
class RedeclaredVar {
	public var n:String;
	public var old:DeclaredVar;
	public var depth:Int;
}

class Interp {
	public var scriptObject(default, set):Dynamic;
	private var _hasScriptObject(default, null):Bool = false;
	private var _scriptObjectType(default, null):ScriptObjectType = SNull;
	public function set_scriptObject(v:Dynamic) {
		switch(Type.typeof(v)) {
			case TClass(c): // Class Access
				__instanceFields = Type.getInstanceFields(c);
				_scriptObjectType = SClass;
			case TObject: // Object Access or Static Class Access
				var cls = Type.getClass(v);
				switch(Type.typeof(cls)) {
					case TClass(c): // Static Class Access
						__instanceFields = Type.getInstanceFields(c);
						_scriptObjectType = SStaticClass;
					default: // Object Access
						__instanceFields = Reflect.fields(v);
						_scriptObjectType = SObject;
				}
			default: // Null or other
				__instanceFields = [];
				_scriptObjectType = SNull;
		}
		_hasScriptObject = v != null;
		return scriptObject = v;
	}
	public var errorHandler:Error->Void;
	public var importFailedCallback:Array<String>->Bool;

	public var _variablesNames:Array<String> = [];
	public var _variables:Array<Dynamic> = [];
	public var _publicVariables:Array<Dynamic> = [];
	public var _staticVariables:Array<Dynamic> = [];
	public var _customClasses:Array<Dynamic> = [];
	public var _locals:Array<DeclaredVar> = [];

	// !BACKWARDS COMPAT
	public var customClasses:HScriptVariables;
	public var variables:HScriptVariables;
	public var publicVariables:HScriptVariables;
	public var staticVariables:HScriptVariables;

	#if haxe3
	public var locals:Map<String, DeclaredVar>;
	var binops:Map<String, Expr->Expr->Dynamic>;
	#else
	public var locals:Hash<DeclaredVar>;
	var binops:Hash<Expr->Expr->Dynamic>;
	#end

	var depth:Int = 0;
	var inTry:Bool;
	var declared:Array<RedeclaredVar>;
	var returnValue:Dynamic;

	var isBypassAccessor:Bool = false;

	public var importEnabled:Bool = true;

	public var allowStaticVariables:Bool = false;
	public var allowPublicVariables:Bool = false;

	public var importBlocklist:Array<String> = [
		// "flixel.FlxG"
	];

	var __instanceFields:Array<String> = [];
	#if hscriptPos
	var curExpr:Expr;
	#end

	public function new() {
		declared = new Array();
		resetVariables();
		initOps();
	}

	private function resetVariables() {
		_variablesNames = [];
		_variables = [];
		_publicVariables = [];
		_staticVariables = [];
		_customClasses = [];
		_locals = [];

		staticVariables = publicVariables = customClasses = variables = new HScriptVariables(this);
	}

	private function setDefualtVariables() {
		variables.set("null", null);
		variables.set("true", true);
		variables.set("false", false);
		#if !NO_FROM_CHAR_CODE_FIX
		if(!Preprocessor.isStringFromCharCodeFixed) {
			// DONT CALL THIS DIRECTLY, USE String.fromCharCode, the preprocessor will call it for you
			variables.set("__StringWorkaround__fromCharCode", function(a:Int) { // TODO: make hscript only add this if its used
				return String.fromCharCode(a);
			});
		}
		#end
		variables.set("trace", Reflect.makeVarArgs(function(el) {
			var inf = posInfos();
			var v = el.shift();
			if (el.length > 0)
				inf.customParams = el;
			haxe.Log.trace(Std.string(v), inf);
		}));
	}

	public function posInfos():PosInfos {
		#if hscriptPos
		if (curExpr != null)
			return cast {fileName: curExpr.origin, lineNumber: curExpr.line};
		#end
		return cast {fileName: "hscript", lineNumber: 0};
	}

	function initOps() {
		var me = this;
		#if haxe3
		binops = new Map();
		#else
		binops = new Hash();
		#end
		binops.set("+", function(e1, e2) return me.expr(e1) + me.expr(e2));
		binops.set("-", function(e1, e2) return me.expr(e1) - me.expr(e2));
		binops.set("*", function(e1, e2) return me.expr(e1) * me.expr(e2));
		binops.set("/", function(e1, e2) return me.expr(e1) / me.expr(e2));
		binops.set("%", function(e1, e2) return me.expr(e1) % me.expr(e2));
		binops.set("&", function(e1, e2) return me.expr(e1) & me.expr(e2));
		binops.set("|", function(e1, e2) return me.expr(e1) | me.expr(e2));
		binops.set("^", function(e1, e2) return me.expr(e1) ^ me.expr(e2));
		binops.set("<<", function(e1, e2) return me.expr(e1) << me.expr(e2));
		binops.set(">>", function(e1, e2) return me.expr(e1) >> me.expr(e2));
		binops.set(">>>", function(e1, e2) return me.expr(e1) >>> me.expr(e2));
		binops.set("==", function(e1, e2) return me.expr(e1) == me.expr(e2));
		binops.set("!=", function(e1, e2) return me.expr(e1) != me.expr(e2));
		binops.set(">=", function(e1, e2) return me.expr(e1) >= me.expr(e2));
		binops.set("<=", function(e1, e2) return me.expr(e1) <= me.expr(e2));
		binops.set(">", function(e1, e2) return me.expr(e1) > me.expr(e2));
		binops.set("<", function(e1, e2) return me.expr(e1) < me.expr(e2));
		binops.set("||", function(e1, e2) return me.expr(e1) == true || me.expr(e2) == true);
		binops.set("&&", function(e1, e2) return me.expr(e1) == true && me.expr(e2) == true);
		binops.set("is", checkIsType);
		binops.set("=", assign);
		binops.set("??", function(e1, e2) {
			var expr1:Dynamic = me.expr(e1);
			return expr1 == null ? me.expr(e2) : expr1;
		});
		binops.set("...", function(e1, e2) return new
			#if (haxe_211 || haxe3)
			IntIterator
			#else
			IntIter
			#end(me.expr(e1), me.expr(e2)));
		assignOp("+=", function(v1:Dynamic, v2:Dynamic) return v1 + v2);
		assignOp("-=", function(v1:Float, v2:Float) return v1 - v2);
		assignOp("*=", function(v1:Float, v2:Float) return v1 * v2);
		assignOp("/=", function(v1:Float, v2:Float) return v1 / v2);
		assignOp("%=", function(v1:Float, v2:Float) return v1 % v2);
		assignOp("&=", function(v1, v2) return v1 & v2);
		assignOp("|=", function(v1, v2) return v1 | v2);
		assignOp("^=", function(v1, v2) return v1 ^ v2);
		assignOp("<<=", function(v1, v2) return v1 << v2);
		assignOp(">>=", function(v1, v2) return v1 >> v2);
		assignOp(">>>=", function(v1, v2) return v1 >>> v2);
		assignOp("??"+"=", function(v1, v2) return v1 == null ? v2 : v1);
	}

	function checkIsType(e1,e2): Bool {
		var expr1:Dynamic = expr(e1);

		return switch(Tools.expr(e2)) {
			case EIdent("Class"):
				Std.isOfType(expr1, Class);
			case EIdent("Map") | EIdent("IMap"):
				Std.isOfType(expr1, IMap);
			default:
				var expr2:Dynamic = expr(e2);
				expr2 != null ? Std.isOfType(expr1, expr2) : false;
		}
	}

	public function setVar(name:String, v:Dynamic) {
		if (allowStaticVariables && staticVariables.exists(name))
			staticVariables.set(name, v);
		else if (allowPublicVariables && publicVariables.exists(name))
			publicVariables.set(name, v);
		else
			variables.set(name, v);
	}

	function assign(e1:Expr, e2:Expr):Dynamic {
		var v = expr(e2);
		switch (Tools.expr(e1)) {
			case EIdent(id):
				var l = locals.get(id);
				if (l == null) {
					if (!variables.exists(id) && !staticVariables.exists(id) && !publicVariables.exists(id) && _hasScriptObject) {
						if (_scriptObjectType == SObject) {
							UnsafeReflect.setField(scriptObject, id, v);
						} else {
							if (isBypassAccessor) {
								if (__instanceFields.contains(id)) {
									UnsafeReflect.setField(scriptObject, id, v);
									return v;
								}
							}

							if (__instanceFields.contains(id)) {
								UnsafeReflect.setProperty(scriptObject, id, v);
							} else if (__instanceFields.contains('set_$id')) { // setter
								UnsafeReflect.getProperty(scriptObject, 'set_$id')(v);
							} else {
								setVar(id, v);
							}
						}
					} else {
						setVar(id, v);
					}
				} else {
					l.r = v;
					if (l.depth == 0) {
						setVar(id, v);
					}
				}
				// TODO
			case EField(e, f, s):
				var obj = expr(e);
				if(s && obj == null) return null;
				v = set(obj, f, v);
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					setMapValue(arr, index, v);
				} else {
					arr[index] = v;
				}

			default:
				error(EInvalidOp("="));
		}
		return v;
	}

	function assignOp(op, fop:Dynamic->Dynamic->Dynamic) {
		var me = this;
		binops.set(op, function(e1, e2) return me.evalAssignOp(op, fop, e1, e2));
	}

	function evalAssignOp(op, fop, e1, e2):Dynamic {
		var v;
		switch (Tools.expr(e1)) {
			case EIdent(id):
				var l = locals.get(id);
				v = fop(expr(e1), expr(e2));
				if (l == null) {
					if(_hasScriptObject) {
						if(_scriptObjectType == SObject) {
							UnsafeReflect.setField(scriptObject, id, v);
						} else if (__instanceFields.contains(id)) {
							UnsafeReflect.setProperty(scriptObject, id, v);
						} else if (__instanceFields.contains('set_$id')) { // setter
							UnsafeReflect.getProperty(scriptObject, 'set_$id')(v);
						} else {
							setVar(id, v);
						}
					} else {
						setVar(id, v);
					}
				}
				else
					l.r = v;
			case EField(e, f, s):
				var obj = expr(e);
				if(s && obj == null) return null;
				v = fop(get(obj, f), expr(e2));
				v = set(obj, f, v);
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					var map = getMap(arr);

					v = fop(map.get(index), expr(e2));
					map.set(index, v);
				} else {
					v = fop(arr[index], expr(e2));
					arr[index] = v;
				}
			default:
				return error(EInvalidOp(op));
		}
		return v;
	}

	function increment(e:Expr, prefix:Bool, delta:Int):Dynamic {
		#if hscriptPos
		curExpr = e;
		var e = e.e;
		#end
		switch (e) {
			case EIdent(id):
				var l = locals.get(id);
				var v:Dynamic = (l == null) ? resolve(id) : l.r;
				if (prefix) {
					v += delta;
					if (l == null)
						setVar(id, v)
					else
						l.r = v;
				} else if (l == null)
					setVar(id, v + delta)
				else
					l.r = v + delta;
				return v;
			case EField(e, f, s):
				var obj = expr(e);
				if(s && obj == null) return null;
				var v:Dynamic = get(obj, f);
				if (prefix) {
					v += delta;
					set(obj, f, v);
				} else
					set(obj, f, v + delta);
				return v;
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					var map = getMap(arr);
					var v = map.get(index);
					if (prefix) {
						v += delta;
						map.set(index, v);
					} else {
						map.set(index, v + delta);
					}
					return v;
				} else {
					var v = arr[index];
					if (prefix) {
						v += delta;
						arr[index] = v;
					} else
						arr[index] = v + delta;
					return v;
				}
			default:
				return error(EInvalidOp((delta > 0) ? "++" : "--"));
		}
	}

	public function execute(expr:Expr):Dynamic {
		depth = 0;
		#if haxe3
		locals = new Map();
		#else
		locals = new Hash();
		#end
		declared = new Array();

		Preprocessor.getvars(expr, _variablesNames);
		_variables = cast new haxe.ds.Vector<Dynamic>(_variablesNames.length);
		_publicVariables = cast new haxe.ds.Vector<Dynamic>(_variablesNames.length);
		_staticVariables = cast new haxe.ds.Vector<Dynamic>(_variablesNames.length);
		_customClasses = cast new haxe.ds.Vector<Dynamic>(_variablesNames.length);
		_locals = cast new haxe.ds.Vector<Dynamic>(_variablesNames.length);

		setDefualtVariables();
		variables.loadDefaults();
		return exprReturn(expr);
	}

	function exprReturn(e):Dynamic {
		try {
			try {
				return expr(e);
			} catch (e:Stop) {
				switch (e) {
					case SBreak:
						throw "Invalid break";
					case SContinue:
						throw "Invalid continue";
					case SReturn:
						var v = returnValue;
						returnValue = null;
						return v;
				}
			} catch(e) {
				error(ECustom('${e.toString()}'));
				return null;
			}
		} catch(e:Error) {
			if (errorHandler != null)
				errorHandler(e);
			else
				throw e;
			return null;
		} catch(e) {
			trace(e);
		}
		return null;
	}

	public function duplicate<T>(h:#if haxe3 Map<String, T> #else Hash<T> #end) {
		#if haxe3
		var h2 = new Map();
		#else
		var h2 = new Hash();
		#end
		for (k in h.keys())
			h2.set(k, h.get(k));
		return h2;
	}

	function restore(old:Int) {
		while (declared.length > old) {
			var d = declared.pop();
			locals.set(d.n, d.old);
		}
	}

	public inline function error(e:#if hscriptPos Error.ErrorDef #else Error #end, rethrow = false):Dynamic {
		#if hscriptPos var e = new Error(e, curExpr.pmin, curExpr.pmax, curExpr.origin, curExpr.line); #end

		if (rethrow) {
			this.rethrow(e);
		} else {
			throw e;
		}
		return null;
	}

	inline function rethrow(e:Dynamic) {
		#if hl
		hl.Api.rethrow(e);
		#else
		throw e;
		#end
	}

	public function resolve(id:String, doException:Bool = true):Dynamic {
		if (id == null)
			return null;
		id = StringTools.trim(id);
		var l = locals.get(id);
		if (l != null)
			return l.r;

		for(map in [variables, publicVariables, staticVariables, customClasses])
			if (map.exists(id))
				return map.get(id);

		if (_hasScriptObject) {
			// search in object
			if (id == "this") {
				return scriptObject;
			} else if (_scriptObjectType == SObject && UnsafeReflect.hasField(scriptObject, id)) {
				return UnsafeReflect.field(scriptObject, id);
			} else {
				if (__instanceFields.contains(id)) {
					return UnsafeReflect.getProperty(scriptObject, id);
				} else if (__instanceFields.contains('get_$id')) { // getter
					return UnsafeReflect.getProperty(scriptObject, 'get_$id')();
				}
			}
		}
		if (doException)
			error(EUnknownVariable(id));
		//var v = variables.get(id);
		return null;
	}

	function getClass(c:String):haxe.ds.Either<Class<Any>, Enum<Any>> {
		if (importBlocklist.contains(c))
			return null;

		var en = Type.resolveEnum(c);
		if(en != null)
			return Right(en);

		var cl = Type.resolveClass(c);
		if (cl == null)
			cl = Type.resolveClass(c + '_HSC');
		if(cl != null)
			return Left(cl);
		return null;
	}

	public function expr(e:Expr):Dynamic {
		#if hscriptPos
		curExpr = e;
		var e = e.e;
		#end
		switch (e) {
			case EClass(name, fields, extend, interfaces):
				if (customClasses.exists(name))
					error(EAlreadyExistingClass(name));

				inline function importVar(thing:String):String {
					if (thing == null)
						return null;
					final variable:Class<Any> = variables.exists(thing) ? cast variables.get(thing) : null;
					return variable == null ? thing : Type.getClassName(variable);
				}
				customClasses.set(name, new CustomClassHandler(this, name, fields, importVar(extend), [for (i in interfaces) importVar(i)]));
			case EImport(c, mode):
				if (!importEnabled) return null;

				if(mode == IAll) {
					throw "TODO";
					return null;
				}

				var splitClassName:Array<String> = c.split(".");
				if (splitClassName.length <= 0) return null;

				var lastName:String = splitClassName[splitClassName.length-1];
				var varName:String = switch(mode) {
					case IAs(name): name;
					default: lastName;
				};

				// Class is already imported
				if (variables.exists(varName))
					return variables.get(varName);

				// Orginal class
				var importedClass = getClass(c);

				// Allow for flixel.ui.FlxBar.FlxBarFillDirection;
				if (importedClass == null) {
					var newClassName:Array<String> = splitClassName.copy();
					newClassName.splice(-2, 1); // Remove the last last item

					importedClass = getClass(newClassName.join("."));
				}

				// Allow for Std.isOfType;
				var isField:Bool = false;
				if (importedClass == null) {
					importedClass = getClass(c.substring(0, c.lastIndexOf(".")));
					isField = true;
				}

				// Import the .isOfType
				if (importedClass != null) {
					var classOrEnum:Dynamic = switch(importedClass) {
						case Left(e): e;
						case Right(e): Tools.getEnum(e);
					};
					if(isField) {
						var v:Dynamic   = UnsafeReflect.getProperty(classOrEnum, lastName);
						if(v == null) v = UnsafeReflect.field(classOrEnum, lastName);
						if(v == null) error(EInvalidAccess(lastName, c));

						variables.set(varName, v);
						return v;
					}

					variables.set(varName, classOrEnum);
					return classOrEnum;
				}

				if (importFailedCallback == null || !importFailedCallback(c.split("."))) // Incase of custom import
					error(EInvalidClass(c));
				return null;
			case EConst(c):
				switch (c) {
					case CInt(v): return v;
					case CFloat(f): return f;
					case CString(s): return s;
					#if !haxe3
					case CInt32(v): return v;
					#end
				}
			case EIdent(id):
				return resolve(id);
			case EVar(n, _, e, isPublic, isStatic):
				declared.push({n: n, old: locals.get(n), depth: depth});
				locals.set(n, {r: (e == null) ? null : expr(e), depth: depth});
				if (depth == 0) {
					if(isStatic == true) {
						if(!staticVariables.exists(n)) { // dont overwrite existing static variables
							staticVariables.set(n, locals[n].r);
						}
						return null;
					}
					(isPublic ? publicVariables : variables).set(n, locals[n].r);
				}
				return null;
			case EParent(e):
				return expr(e);
			case EBlock(exprs):
				var old = declared.length;
				var v = null;
				for (e in exprs)
					v = expr(e);
				restore(old);
				return v;
			case EField(e, f, s):
				var field = expr(e);
				if(s && field == null)
					return null;
				return get(field, f);
			case EBinop(op, e1, e2):
				var fop = binops.get(op);
				#if debug
				if (fop == null)
					error(EInvalidOp(op));
				#end
				return fop(e1, e2);
			case EUnop(op, prefix, e):
				switch (op) {
					case "!":
						return expr(e) != true;
					case "-":
						return -expr(e);
					case "++":
						return increment(e, prefix, 1);
					case "--":
						return increment(e, prefix, -1);
					case "~":
						#if (neko && !haxe3)
						return haxe.Int32.complement(expr(e));
						#else
						return ~expr(e);
						#end
					default:
						error(EInvalidOp(op));
				}
			case ECall(e, params):
				var args = new Array();
				for(i in 0...params.length)
					args.push(expr(params[i]));

				switch (Tools.expr(e)) {
					case EField(e, f, s):
						var obj = expr(e);
						if (obj == null) {
							if(s) return null;
							error(EInvalidAccess(f));
						}
						return fcall(obj, f, args);
					default:
						return call(null, expr(e), args);
				}
			case EIf(econd, e1, e2):
				return if (expr(econd) == true) expr(e1) else if (e2 == null) null else expr(e2);
			case EWhile(econd, e):
				whileLoop(econd, e);
				return null;
			case EDoWhile(econd, e):
				doWhileLoop(econd, e);
				return null;
			case EFor(v, it, e):
				forLoop(v, it, e);
				return null;
			case EForKeyValue(v, it, e, ithv):
				forLoopKeyValue(v, it, e, ithv);
				return null;
			case EBreak:
				throw SBreak;
			case EContinue:
				throw SContinue;
			case EReturn(e):
				returnValue = e == null ? null : expr(e);
				throw SReturn;
			case EFunction(params, fexpr, name, _, isPublic, isStatic, isOverride):
				var __capturedLocals = duplicate(locals);
				var capturedLocals:Map<String, DeclaredVar> = [];
				for(k=>e in __capturedLocals)
					if (e != null && e.depth > 0)
						capturedLocals.set(k, e);

				var me = this;
				var hasOpt = false, minParams = 0;
				for (p in params)
					if (p.opt)
						hasOpt = true;
					else
						minParams++;
				var f = function(args:Array<Dynamic>) {
					if (me.locals == null || me.variables == null) return null;

					if (((args == null) ? 0 : args.length) != params.length) {
						if (args.length < minParams) {
							var str = "Invalid number of parameters. Got " + args.length + ", required " + minParams;
							if (name != null)
								str += " for function '" + name + "'";
							error(ECustom(str));
						}
						// make sure mandatory args are forced
						var args2 = [];
						var extraParams = args.length - minParams;
						var pos = 0;
						for (p in params)
							if (p.opt) {
								if (extraParams > 0) {
									args2.push(args[pos++]);
									extraParams--;
								} else
									args2.push(null);
							} else
								args2.push(args[pos++]);
						args = args2;
					}
					var old = me.locals, depth = me.depth;
					me.depth++;
					me.locals = me.duplicate(capturedLocals);
					for (i in 0...params.length)
						me.locals.set(params[i].name, {r: args[i], depth: depth});
					var r = null;
					var oldDecl = declared.length;
					if (inTry)
						try {
							r = me.exprReturn(fexpr);
						} catch (e:Dynamic) {
							me.locals = old;
							me.depth = depth;
							#if neko
							neko.Lib.rethrow(e);
							#else
							throw e;
							#end
						}
					else
						r = me.exprReturn(fexpr);
					restore(oldDecl);
					me.locals = old;
					me.depth = depth;
					return r;
				};
				var f = Reflect.makeVarArgs(f);
				if (name != null) {
					if (depth == 0) {
						// global function
						((isStatic && allowStaticVariables) ? staticVariables : ((isPublic && allowPublicVariables) ? publicVariables : variables)).set(name, f);
					} else {
						// function-in-function is a local function
						declared.push({n: name, old: locals.get(name), depth: depth});
						var ref:DeclaredVar = {r: f, depth: depth};
						locals.set(name, ref);
						capturedLocals.set(name, ref); // allow self-recursion
					}
				}
				return f;
			case EMapDecl(type, _keys, _values):
				var keys:Array<Dynamic> = [];
				var values:Array<Dynamic> = [];
				if(type == UnknownMap) {
					var isKeyString:Bool = false;
					var isKeyInt:Bool = false;
					var isKeyObject:Bool = false;
					var isKeyEnum:Bool = false;
					for (i in 0..._keys.length) {
						var key:Dynamic = expr(_keys[i]);
						var value:Dynamic = expr(_values[i]);

						if(!isKeyString) isKeyString = (key is String);
						if(!isKeyInt) isKeyInt = (key is Int);
						if(!isKeyObject) isKeyObject = Reflect.isObject(key);
						if(!isKeyEnum) isKeyEnum = Reflect.isEnumValue(key);

						keys.push(key);
						values.push(value);
					}

					var t = b2i(isKeyString) + b2i(isKeyInt) + b2i(isKeyObject) + b2i(isKeyEnum);

					if(t != 1)
						error(EPreset(UNKNOWN_MAP_TYPE_RUNTIME));
					else if(isKeyInt) type = IntMap;
					else if(isKeyString) type = StringMap;
					else if(isKeyEnum) type = EnumMap;
					else if(isKeyObject) type = ObjectMap;
				} else {
					for(i in 0..._keys.length) {
						keys.push(expr(_keys[i]));
						values.push(expr(_values[i]));
					}
				}
				var map:IMap<Dynamic, Dynamic> = switch(type) {
					case IntMap: new haxe.ds.IntMap<Dynamic>();
					case StringMap: new haxe.ds.StringMap<Dynamic>();
					case EnumMap: new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
					case ObjectMap: new haxe.ds.ObjectMap<Dynamic, Dynamic>();
					default: null;
				}
				for (n in 0...keys.length) {
					map.set(keys[n], values[n]);
				}
				return map;
			case EArrayDecl(arr):
				return [for (j in 0...arr.length) expr(arr[j])];
			case EArray(e, index):
				var arr:Dynamic = expr(e);
				var index:Dynamic = expr(index);
				if (isMap(arr)) {
					return getMapValue(arr, index);
				} else {
					return arr[index];
				}
			case ENew(cl, params):
				var a = new Array();
				for (i in 0...params.length)
					a.push(expr(params[i]));
				return cnew(cl, a);
			case EThrow(e):
				throw expr(e);
			case ETry(e, n, _, ecatch):
				var old = declared.length;
				var oldTry = inTry;
				try {
					inTry = true;
					var v:Dynamic = expr(e);
					restore(old);
					inTry = oldTry;
					return v;
				} catch (err:Stop) {
					inTry = oldTry;
					throw err;
				} catch (err:Dynamic) {
					// restore vars
					restore(old);
					inTry = oldTry;
					// declare 'v'
					declared.push({n: n, old: locals.get(n), depth: depth});
					locals.set(n, {r: err, depth: depth});
					var v:Dynamic = expr(ecatch);
					restore(old);
					return v;
				}
			case EObject(fl):
				var o = {};
				for (f in fl)
					UnsafeReflect.setField(o, f.name, expr(f.e));
					//set(o, f.name, expr(f.e));
				return o;
			case ETernary(econd, e1, e2):
				return if (expr(econd) == true) expr(e1) else expr(e2);
			case ESwitch(e, cases, def):
				var val:Dynamic = expr(e);
				var match = false;
				for (c in cases) {
					for (v in c.values)
						if (expr(v) == val) {
							match = true;
							break;
						}
					if (match) {
						val = expr(c.expr);
						break;
					}
				}
				if (!match)
					val = def == null ? null : expr(def);
				return val;
			case EMeta(a, b, e):
				var oldAccessor = isBypassAccessor;
				if(a == ":bypassAccessor")
					isBypassAccessor = true;
				var val = expr(e);

				isBypassAccessor = oldAccessor;
				return val;
			case ECheckType(e, _):
				return expr(e);
		}
		return null;
	}

	function doWhileLoop(econd, e) {
		var old = declared.length;
		do {
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		} while (expr(econd) == true);
		restore(old);
	}

	function whileLoop(econd, e) {
		var old = declared.length;
		while (expr(econd) == true) {
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		}
		restore(old);
	}

	function makeIterator(v:Dynamic):Iterator<Dynamic> {
		#if ((flash && !flash9) || (php && !php7 && haxe_ver < '4.0.0'))
		if (v.iterator != null)
			v = v.iterator();
		#else
		if(v.hasNext == null || v.next == null) {
			try
				v = v.iterator()
			catch (e:Dynamic) {};
		}
		#end
		if (v.hasNext == null || v.next == null)
			error(EInvalidIterator(v));
		return v;
	}

	function makeKeyValueIterator(v:Dynamic):Iterator<Dynamic> {
		#if ((flash && !flash9) || (php && !php7 && haxe_ver < '4.0.0'))
		if (v.keyValueIterator != null)
			v = v.keyValueIterator();

		if (v.iterator != null)
			v = v.iterator();

		if (v.hasNext == null || v.next == null)
			error(EInvalidIterator(v));
		#else
		try
			v = v.keyValueIterator()
		catch (e:Dynamic) {};

		if (v.hasNext == null || v.next == null)
			v = makeIterator(v);
		#end
		return v;
	}

	function forLoop(n, it, e) {
		var old = declared.length;
		declared.push({n: n, old: locals.get(n), depth: depth});
		var it = makeIterator(expr(it));
		var _hasNext = it.hasNext;
		var _next = it.next;
		while (_hasNext()) {
			var next = _next();
			locals.set(n, {r: next, depth: depth});
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		}
		restore(old);
	}

	function forLoopKeyValue(n, it, e, ithv) {
		var old = declared.length;
		declared.push({n: ithv, old: locals.get(ithv), depth: depth});
		declared.push({n: n, old: locals.get(n), depth: depth});
		var it = makeKeyValueIterator(expr(it));
		var _hasNext = it.hasNext;
		var _next = it.next;
		while (_hasNext()) {
			var next = _next();
			locals.set(ithv, {r: next.key, depth: depth});
			locals.set(n, {r: next.value, depth: depth});
			try {
				expr(e);
			} catch (err:Stop) {
				switch (err) {
					case SContinue:
					case SBreak:
						break;
					case SReturn:
						throw err;
				}
			}
		}
		restore(old);
	}

	inline function isMap(o:Dynamic):Bool {
		return (o is IMap);
	}

	inline function getMap(map:Dynamic):IMap<Dynamic, Dynamic> {
		return cast(map, IMap<Dynamic, Dynamic>);
	}

	inline function getMapValue(map:Dynamic, key:Dynamic):Dynamic {
		return cast(map, IMap<Dynamic, Dynamic>).get(key);
	}

	inline function setMapValue(map:Dynamic, key:Dynamic, value:Dynamic):Void {
		cast(map, IMap<Dynamic, Dynamic>).set(key, value);
	}

	public static var getRedirects:Map<String, Dynamic->String->Dynamic> = [];
	public static var setRedirects:Map<String, Dynamic->String->Dynamic->Dynamic> = [];

	private static var _getRedirect:Dynamic->String->Dynamic;
	private static var _setRedirect:Dynamic->String->Dynamic->Dynamic;

	public var useRedirects:Bool = true;

	static function getClassType(o:Dynamic, ?cls:Class<Any>):Null<String> {
		return switch (Type.typeof(o)) {
			case TNull: "Null";
			case TInt: "Int";
			case TFloat: "Float";
			case TBool: "Bool";
			case _:
				if (cls == null)
					cls = Type.getClass(o);
				cls != null ? Type.getClassName(cls) : null;
		};
	}

	function get(o:Dynamic, f:String):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));

		var cls = Type.getClass(o);
		var cl:Null<String> = getClassType(o, cls);
		if (useRedirects && cl != null && getRedirects.exists(cl) && (_getRedirect = getRedirects[cl]) != null) {
			return _getRedirect(o, f);
		} else if (o is IHScriptCustomBehaviour) {
			var obj = cast(o, IHScriptCustomBehaviour);
			return obj.hget(f);
		}

		var v = null;
		if(isBypassAccessor) {
			if ((v = UnsafeReflect.field(o, f)) == null)
				v = Reflect.field(cls, f);
		}

		if(v == null) {
			if ((v = UnsafeReflect.getProperty(o, f)) == null)
				v = Reflect.getProperty(cls, f);
		}
		return v;
	}

	function set(o:Dynamic, f:String, v:Dynamic):Dynamic {
		if (o == null)
			error(EInvalidAccess(f));

		var cl:Null<String> = getClassType(o);
		if (useRedirects && cl != null && setRedirects.exists(cl) && (_setRedirect = setRedirects[cl]) != null)
			return _setRedirect(o, f, v);
		else if (o is IHScriptCustomBehaviour) {
			var obj = cast(o, IHScriptCustomBehaviour);
			return obj.hset(f, v);
		}
		// Can use unsafe reflect here, since we checked for null above
		if(isBypassAccessor) {
			UnsafeReflect.setField(o, f, v);
		} else {
			UnsafeReflect.setProperty(o, f, v);
		}
		return v;
	}

	function fcall(o:Dynamic, f:String, args:Array<Dynamic>):Dynamic {
		if(o == CustomClassHandler.staticHandler && _hasScriptObject) {
			return UnsafeReflect.callMethodUnsafe(scriptObject, UnsafeReflect.field(scriptObject, "_HX_SUPER__" + f), args);
		}
		return call(o, get(o, f), args);
	}

	function call(o:Dynamic, f:Dynamic, args:Array<Dynamic>):Dynamic {
		if(f == CustomClassHandler.staticHandler) {
			return null;
		}
		return UnsafeReflect.callMethodSafe(o, f, args);
	}

	function cnew(cl:String, args:Array<Dynamic>):Dynamic {
		var c:Dynamic = resolve(cl);
		if (c == null)
			c = Type.resolveClass(cl);
		return (c is IHScriptCustomConstructor) ? cast(c, IHScriptCustomConstructor).hnew(args) : Type.createInstance(c, args);
	}

	static inline function b2i(b:Bool) return b ? 1 : 0;
}

class HScriptVariables {
	public var defaults:Map<String, Dynamic> = [];
	public var usedefaults:Bool = true;

	public function loadDefaults() {
		usedefaults = false;
		for (key => value in defaults)
			set(key, value);
		defaults.clear();
	}

	public var parent:Interp;
	public function new(parent:Interp)
		this.parent = parent;

	public inline function set(key:String, value:Dynamic) {
		if (usedefaults) defaults.set(key, value);
		if (parent._variablesNames.contains(key))
			parent._variables[parent._variablesNames.indexOf(key)] = value;
	}

	public inline function get(key:String):Dynamic {
		if (parent._variablesNames.contains(key))
			return parent._variables[parent._variablesNames.indexOf(key)];
		return null;
	}

	public inline function exists(key:String):Bool {
		var indx:Int = parent._variablesNames.indexOf(key);
		return indx != -1 && (key == "null" ? true : parent._variables[indx] != null);
	}
		
	public inline function remove(key:String)
		parent._variables[parent._variablesNames.indexOf(key)] = null;

	public inline function clear():Void {
		parent._variablesNames.resize(0);
		parent._variables.resize(0);
	}

	public inline function copy():Map<String, Dynamic> {
		var map:Map<String, Dynamic> = [
			for (i in 0...parent._variables.length)
				parent._variablesNames[i] => parent._variables[i]
		];
		return map;
	}

	public inline function iterator():ArrayIterator<Dynamic>
		return parent._variables.iterator();

	public inline function keys():ArrayIterator<String>
		return parent._variablesNames.iterator();

	public inline function keyValueIterator() : HScriptVariables {
		_current = 0;
		return this;
	}

	@:noCompletion public var _current:Int = 0;
	public inline function hasNext():Bool {
		return _current < parent._variablesNames.length;
	}

	public inline function next():{key:String, value:Dynamic} {
		_current++;
		return {value: parent._variables[_current], key: parent._variablesNames[_current]};
	}
}