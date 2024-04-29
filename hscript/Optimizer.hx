package hscript;

import hscript.Expr;
import hscript.Tools;
import hscript.Parser;

@:access(hscript.Parser)
class Optimizer {
	static inline function expr(e:Expr) return Tools.expr(e);

	public static function optimize(s:Expr):Expr {
		if(s == null)
			return null;

		var e = Tools.expr(s);

		// TODO: Convert EBinOp(+, a, EUnop(-, b)) to EBinOp(-, a, b) aka (a - b)
		// TODO: Make it so if EFor & EForKeyValue iterator variable isnt used its replaced with a $, which the code handles as doesnt exist
		// TODO: Make it so <PURE_VAR|CONST> == ?; gets removed, IF it isnt stored
		// TODO: Optimize ?. and ??
		// TODO: Optimize Std.string(CONSTANT) to "CONSTANT"
		// TODO: Remove Std.string if its the right side of a binop of a string
		// TODO: Add EForComprehension, EWhileComprehension, EDoWhileComprehension for better optimization
		// TODO: Optimize EFor(v, it, EBlock([e1])) to EFor(v, it, e1)
		// TODO: Optimize EIf(cond, e1, e2) to EBlock([cond, e1]) if e1 == e2, if cond is constant or side effect free then convert to EParent(e1)

		switch(e) {
			// Parse all expressions and recreate the AST
			case EBlock(exprs):
				var exprs = exprs.map((v) -> optimize(v)).filter((v) -> v != null).filter((v) -> {
					if(Tools.expr(v).match(EBlock([]))) return false; // Remove empty blocks
					return true;
				});

				var newExprs = [];
				for(e in exprs) {
					switch(Tools.expr(e)) {
						case EBlock(iex):
							var declares = Lambda.exists(iex, ie -> hasDecl(ie));
							if(!declares) {
								for(ex in iex)
									newExprs.push(ex);
							} else {
								newExprs.push(e);
							}
						case EReturn(_): // remove stuff that are after a return
							newExprs.push(e);
							break;
						default:
							newExprs.push(e);
					}
				}

				return mk(EBlock(newExprs), s);

			case EIf(econd, e1, e2):
				var econd = optimize(econd);
				var e1 = optimize(e1);
				var e2 = optimize(e2);
				if(isBool(econd)) {
					var econd = getBool(econd);
					if(econd == true) {
						if(e1 == null)
							return mk(EBlock([]), s);
						return mk(EBlock([e1]), s);
					} else {
						if(e2 == null)
							return mk(EBlock([]), s);
						return mk(EBlock([e2]), s);
					}
				}
				if(e2 != null && isBool(e1) && isBool(e2)) {
					var c1 = getBool(e1);
					var c2 = getBool(e2);

					if(c1 == false && c2 == true) { // (VAR ? false : true)
						return optimize(mk(EUnop(OpNot, true, econd), s));
					}
					if(c1 == true && c2 == false) { // (VAR ? true : false)
						return optimize(mk(Tools.expr(econd), s));
					}
					if(isConstant(econd)) { // Side effect free
						if(c1 == true && c2 == true) { // (CONST ? true : true)
							return mk(convertConstant(true), s);
						}
						if(c1 == false && c2 == false) { // (CONST ? false : false)
							return mk(convertConstant(false), s);
						}
						// TODO: Check if local variables are used in the condition
						// Since they cant have side effects, they can be optimized
					}
				}
				return mk(EIf(econd, e1, e2), s);

			case ETernary(econd, e1, e2):
				var econd = optimize(econd);
				var e1 = optimize(e1);
				var e2 = optimize(e2);
				if(isConstant(econd)) {
					var econd = getConstant(econd);
					if(econd == true) {
						if(e1 == null)
							return mk(EBlock([]), s);
						return mk(EParent(e1), s);
					} else {
						if(e2 == null)
							return mk(EBlock([]), s);
						return mk(EParent(e2), s);
					}
				}
				if(isBool(e1) && isBool(e2)) {
					var c1 = getBool(e1);
					var c2 = getBool(e2);

					if(c1 == false && c2 == true) { // (VAR ? false : true)
						return optimize(mk(EUnop(OpNot, true, econd), s));
					}
					if(c1 == true && c2 == false) { // (VAR ? true : false)
						return optimize(mk(Tools.expr(econd), s));
					}
					if(isConstant(econd)) { // Side effect free
						if(c1 == true && c2 == true) { // (CONST ? true : true)
							return mk(convertConstant(true), s);
						}
						if(c1 == false && c2 == false) { // (CONST ? false : false)
							return mk(convertConstant(false), s);
						}
						// TODO: Check if local variables are used in the condition
						// Since they cant have side effects, they can be optimized
					}
				}
				return mk(ETernary(econd, e1, e2), s);
			case EWhile(econd, e):
				var econd = optimize(econd);
				var e = optimize(e);
				return mk(EWhile(econd, e), s);
			case EDoWhile(econd, e):
				var econd = optimize(econd);
				var e = optimize(e);
				return mk(EDoWhile(econd, e), s);
			case EFor(v, it, e):
				var it = optimize(it);
				var e = optimize(e);
				return mk(EFor(v, it, e), s);
			case EForKeyValue(v, it, e, ithv):
				var it = optimize(it);
				var e = optimize(e);
				return mk(EForKeyValue(v, it, e, ithv), s);
			case EBreak:
				return mk(EBreak, s);
			case EContinue:
				return mk(EContinue, s);
			case EReturn(e):
				var e = optimize(e);
				return mk(EReturn(e), s);

			case ETry(e, v, t, ecatch):
				var e = optimize(e);
				var ecatch = optimize(ecatch);
				return mk(ETry(e, v, t, ecatch), s);

			case EThrow(e):
				var e = optimize(e);
				return mk(EThrow(e), s);

			case EVar(n, t, e, isPublic, isStatic):
				e = optimize(e);
				return mk(EVar(n, t, e, isPublic, isStatic), s);

			case ECall(e, params):
				e = optimize(e);
				params = params.map((v) -> optimize(v));

				function p(i:Int, t:ConstType, opt:Bool = false):Dynamic {
					var p = params[i];
					if(t != getConstType(p))
						if(opt)
							return null;
						else
							throw Parser.getBaseError(EInvalidType(getTypeName(p)));
					return switch(t) {
						case CTInt: getInt(p);
						case CTFloat: getFloat(p);
						case CTBool: getBool(p);
						case CTString: getStringConstant(p);
						case CTNull: null;
					}
				}

				switch(Tools.expr(e)) {
					case EField(expr(_) => EConst(CString(str)), field):
						switch(field) {
							case "toString":
								if(params.length != 0) throw Parser.getBaseError(ECustom("String.toString() takes no arguments"));
								return mk(convertConstant(str.toString()), s);

							case "toUpperCase":
								if(params.length != 0) throw Parser.getBaseError(ECustom("String.toUpperCase() takes no arguments"));
								return mk(convertConstant(str.toUpperCase()), s);

							case "toLowerCase":
								if(params.length != 0) throw Parser.getBaseError(ECustom("String.toLowerCase() takes no arguments"));
								return mk(convertConstant(str.toLowerCase()), s);

							case "charAt":
								var index = p(0, CTInt);
								return mk(convertConstant(str.charAt(index)), s);

							case "charCodeAt":
								var index = p(0, CTInt);
								return mk(convertConstant(str.charCodeAt(index)), s);

							case "indexOf":
								var value = p(0, CTString);
								var startIndex = p(1, CTInt, true);
								return mk(convertConstant(str.indexOf(value, startIndex)), s);

							case "lastIndexOf":
								var value = p(0, CTString);
								var startIndex = p(1, CTInt, true);
								return mk(convertConstant(str.lastIndexOf(value, startIndex)), s);

							case "split":
								var delimiter = p(0, CTString);
								var strArr = str == "" ? [] : str.split(delimiter); // fix platform dependent behavior
								return mk(EArrayDecl([for(st in strArr) mk(EConst(CString(st)), s)]), s);

							case "substr":
								var pos = p(0, CTInt);
								var len = p(1, CTInt, true);
								return mk(convertConstant(str.substr(pos, len)), s);

							case "substring":
								var startIndex = p(0, CTInt);
								var endIndex = p(1, CTInt, true);
								return mk(convertConstant(str.substring(startIndex, endIndex)), s);
						}
						default:
				}
				switch(Tools.expr(e)) {

					default:
				}
				return mk(ECall(e, params), s);

			case EField(e, f, safe):
				e = optimize(e);
				switch(Tools.expr(e)) {
					case EConst(CString(str)) if(f == "length"):
						return mk(convertConstant(str.length), s);
					default:
				}
				return mk(EField(e, f, safe), s);

			case EIdent(_) | EConst(_):
				return s;

			case EParent(e, noOptimize):
				e = optimize(e);
				return mk(noOptimize ? EParent(e) : Tools.expr(e), s);

			case ECheckType(e, t):
				e = optimize(e);
				return mk(ECheckType(e, t), s);

			case EMeta(name, args, e):
				e = optimize(e);
				return mk(EMeta(name, args, e), s);

			case ENew(cl, args):
				args = args.map((v) -> optimize(v));
				return mk(ENew(cl, args), s);

			case EObject(fl):
				fl.map((v) -> {
					v.e = optimize(v.e);
				});
				return mk(EObject(fl), s);

			case EImport(c, n):
				return mk(EImport(c, n), s);

			case EClass(name, fields, extend, interfaces): // Possible code not working
				fields = fields.map((v) -> optimize(v));
				return mk(EClass(name, fields, extend, interfaces), s);

			case EFunction(args, e, name, ret, isPublic, isStatic, isOverride):
				args.map((v) -> {
					v.name = v.name;
					v.value = optimize(v.value);
				});
				e = optimize(e);
				return mk(EFunction(args, e, name, ret, isPublic, isStatic, isOverride), s);

			case ESwitch(e, cases, def):
				e = optimize(e);
				cases.map((v) -> {
					var values = v.values.map((v) -> optimize(v));
					v.expr = optimize(v.expr);
				});
				def = optimize(def);

				if(isConstant(e)) {
					var econd = getConstant(e);

					for(c in cases) {
						for(v in c.values) {
							if(isConstant(v)) {
								var value = getConstant(v);
								if(value == econd)
									return mk(Tools.expr(c.expr), s);
							}
						}
					}

					// Maybe convert this to a Lambda.foreach?
					var isAllCasesConstant = true;
					for(c in cases) {
						for(v in c.values) {
							if(!isConstant(v)) {
								isAllCasesConstant = false;
								break;
							}
						}
					}
					if(isAllCasesConstant) {
						#if debug
						//trace("Didnt find any cases that match");
						#end
						if(def != null)
							return mk(Tools.expr(def), s);
						else
							return mk(EBlock([]), s);
					}
				}

				return mk(ESwitch(e, cases, def), s);

			case EMapDecl(type, keys, values):
				keys = keys.map((v) -> optimize(v));
				values = values.map((v) -> optimize(v));
				return mk(EMapDecl(type, keys, values), s);

			case EArrayDecl(arr):
				arr = arr.map((v) -> optimize(v));
				return mk(EArrayDecl(arr), s);

			case EArray(e, index):
				e = optimize(e);
				index = optimize(index);
				if(isConstant(index)) {
					if(Tools.expr(e).match(EArrayDecl(_))) {
						var arr = switch(Tools.expr(e)) {
							case EArrayDecl(arr): arr;
							default: null;
						};

						var constant = Lambda.exists(arr, isConstant);
						var index = getInt(index);
						if(constant && index != null) {
							return mk(Tools.expr(arr[index]), s);
						}
					}
					if(Tools.expr(e).match(EMapDecl(_))) {
						var map = switch(Tools.expr(e)) {
							case EMapDecl(type, keys, vals): [for(i in 0...keys.length) [keys[i], vals[i]]];
							default: null;
						};

						var constant = Lambda.exists(map, (v) -> isConstant(v[0]) && isConstant(v[1]));
						if(constant) {
							var idx = Lambda.findIndex(map, (v) -> Type.enumEq(Tools.expr(v[0]), Tools.expr(index)));
							if(idx == -1)
								return mk(EIdent("null"), s);
							return mk(Tools.expr(map[idx][1]), s);
						}
					}
				}
				return mk(EArray(e, index), s);

			case EBinop(op, e1, e2):
				e1 = optimize(e1);
				e2 = optimize(e2);

				if(isConstant(e1) && isConstant(e2)) {
					var optimized:Dynamic = optimizeOp(op, getConstant(e1), getConstant(e2));
					if(optimized != null)
						return mk(convertConstant(optimized), s);
				}

				// Possible bugs here
				if(isNumber(e1) && !isConstant(e2)) {
					var c1 = getNumber(e1);
					if(compareNumber(c1, 0) && op == OpAdd)
						return mk(Tools.expr(e2), s);
					if(compareNumber(c1, 1) && op == OpMult)
						return mk(Tools.expr(e2), s);
					//if(compareNumber(c1, 0) && op == "*")
					//	return mk(convertConstant(0), s);
				}

				if(!isConstant(e1) && isNumber(e2)) {
					var c2 = getNumber(e2);
					if(op == OpAdd && compareNumber(c2, 0))
						return mk(Tools.expr(e1), s);
					if(op == OpDiv && compareNumber(c2, 1))
						return mk(Tools.expr(e1), s);
					if(op == OpMult && compareNumber(c2, 1))
						return mk(Tools.expr(e1), s);
					//if(op == "*" && compareNumber(c2, 0))
					//	return mk(convertConstant(0), s);
				}

				return mk(EBinop(op, e1, e2), s);

			case EUnop(op, prefix, e):
				e = optimize(e);

				if(isConstant(e) && prefix) {
					var constant:Dynamic = getConstant(e);
					switch(op) {
						case OpNeg: return mk(convertConstant(-constant), s);
						case OpNot: return mk(convertConstant(!constant), s);
						case OpNegBits:
							var complement = #if (neko && !haxe3) haxe.Int32.complement(constant) #else ~constant #end;
							return mk(convertConstant(complement), s);
						default:
					}
				}

				return mk(EUnop(op, prefix, e), s);
			default:
				Sys.println("Unknown expr: " + e);
		}

		return s;
	}

	static function compareNumber(a:Dynamic, b:Dynamic):Bool {
		return switch(Type.typeof(a)) {
			case TInt:
				var a:Int = cast a;
				switch(Type.typeof(b)) {
					case TInt: a == cast(b, Int);
					case TFloat: a == cast(b, Float);
					default: false;
				}
			case TFloat:
				var a:Float = cast a;
				switch(Type.typeof(b)) {
					case TInt: a == cast(b, Int);
					case TFloat: a == cast(b, Float);
					default: false;
				}
			default: false;
		}
	}

	static function hasDecl(e:Expr):Bool {
		return switch(Tools.expr(e)) {
			case EVar(_): true;// has a declaration
			case EFunction(_): true;// has a declaration
			default: false;
		}
	}

	static function getTypeName(e:Expr):String {
		if(e == null)
			return null;
		return switch(Tools.expr(e)) {
			case EConst(CInt(_)): "Int";
			case EConst(CFloat(_)): "Float";
			case EConst(CString(_)): "String";
			case EIdent("true") | EIdent("false"): "Bool";
			case EIdent("null"): "Null";
			case EIdent(_): "Dynamic";
			case EParent(e): getTypeName(e);
			default: Std.string(Tools.expr(e));
		}
	}

	static function getConstType(e:Expr):ConstType {
		if(e == null)
			return null;
		return switch(Tools.expr(e)) {
			case EConst(CInt(_)): CTInt;
			case EConst(CFloat(_)): CTFloat;
			case EConst(CString(_)): CTString;
			case EIdent("true") | EIdent("false"): CTBool;
			case EIdent("null"): CTNull;
			case EParent(e): getConstType(e);
			default: throw "Unknown type " + Tools.expr(e);
		}
	}

	static function isConstant(e:Expr):Bool {
		return switch(Tools.expr(e)) {
			case EIdent("true") | EIdent("false") | EIdent("null"): true;
			case EConst(_): true;
			case EParent(e): isConstant(e);
			default: false;
		}
	}

	static function isBool(e:Expr):Bool {
		return switch(Tools.expr(e)) {
			case EIdent("true") | EIdent("false"): true;
			case EParent(e): isBool(e);
			default: false;
		}
	}

	static function isNumber(e:Expr):Bool {
		return switch(Tools.expr(e)) {
			case EConst(CInt(_)): true;
			case EConst(CFloat(_)): true;
			case EParent(e): isNumber(e);
			default: false;
		}
	}

	static function getNumber(e:Expr):Dynamic {
		return switch(Tools.expr(e)) {
			case EConst(CInt(value)): value;
			case EConst(CFloat(value)): value;
			case EParent(e): getNumber(e);
			default: throw "Unknown type " + Tools.expr(e);
		}
	}

	static function getBool(e:Expr):Bool {
		return switch(Tools.expr(e)) {
			case EIdent("true"): true;
			case EIdent("false"): false;
			case EParent(e): getBool(e);
			default: throw "Unknown type " + Tools.expr(e);
		}
	}

	static function getInt(e:Expr):Null<Int> {
		if(e == null)
			return null;
		return switch(Tools.expr(e)) {
			case EConst(CInt(value)): value;
			case EParent(e): getInt(e);
			default: null;
		}
	}

	static function getFloat(e:Expr):Null<Float> {
		if(e == null)
			return null;
		return switch(Tools.expr(e)) {
			case EConst(CFloat(value)): value;
			case EParent(e): getFloat(e);
			default: null;
		}
	}

	static function isString(e:Expr):Bool {
		return switch(Tools.expr(e)) {
			case EConst(CString(_)): true;
			case EParent(e): isString(e);
			default: false;
		}
	}

	static function getStringConstant(e:Expr):String {
		return switch(Tools.expr(e)) {
			case EConst(CString(value)): value;
			case EParent(e): getStringConstant(e);
			default: null;
		}
	}

	static function getConstant(e:Expr):Dynamic {
		return switch(Tools.expr(e)) {
			case EParent(e): getConstant(e);
			case EIdent("true"): true;
			case EIdent("false"): false;
			case EIdent("null"): null;
			case EConst(CInt(value)): value;
			case EConst(CFloat(value)): value;
			case EConst(CString(value)): value;
			default: throw "Unknown constant " + Tools.expr(e);
		}
	}

	static function convertConstant(value:Dynamic):ExprDef {
		return switch(Type.typeof(value)) {
			case TInt: EConst(CInt(value));
			case TFloat: EConst(CFloat(value));
			case TBool: EIdent(value == true ? "true" : "false");
			//case TString: EConst(CString(value));
			case TNull: EIdent("null");
			case TClass(String): EConst(CString(value));
			default: throw "Unknown type " + Type.typeof(value);
		}
	}

	static function mk(e:ExprDef, s:Expr):Expr {
		#if hscriptPos
		return new Expr(e, s.pmin, s.pmax, s.origin, s.line);
		#else
		return e;
		#end
	}

	static function optimizeOp(op:Binop, f1:Dynamic, f2:Dynamic):Dynamic {
		//trace("Optimizing " + f1 + " " + op + " " + f2);
		return switch(op) {
			case OpAdd: f1 + f2;
			case OpSub: f1 - f2;
			case OpMult: f1 * f2;
			case OpDiv: f1 / f2;
			case OpMod: f1 % f2;
			case OpAnd: f1 & f2;
			case OpOr: f1 | f2;
			case OpXor: f1 ^ f2;
			case OpShl: f1 << f2;
			case OpShr: f1 >> f2;
			case OpUShr: f1 >>> f2;
			case OpEq: f1 == f2;
			case OpNotEq: f1 != f2;
			case OpGte: f1 >= f2;
			case OpLte: f1 <= f2;
			case OpGt: f1 > f2;
			case OpLt: f1 < f2;
			case OpBoolOr: f1 == true || f2 == true;
			case OpBoolAnd: f1 == true && f2 == true;
			case OpNullCoal: f1 == null ? f2 : f1;
			default: null;
		}
	}
}

enum ConstType {
	CTInt;
	CTFloat;
	CTBool;
	CTString;
	CTNull;
}