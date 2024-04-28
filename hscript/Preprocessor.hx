package hscript;

import hscript.Expr;
import hscript.Error;
import hscript.Tools;
import hscript.Parser;

@:access(hscript.Parser)
class Preprocessor {
	static inline function expr(e:Expr) return Tools.expr(e);

	private static var importStackName:Array<String> = [];
	private static var importStackMode:Array<KImportMode> = [];
	private static function addImport(e:String, mode:KImportMode = INormal) {
		for(i in importStackName) if(i == e) return;
		importStackName.push(e);
		importStackMode.push(mode);
	}

	private static function popImport(e:Expr) {
		return mk(EImport(importStackName.pop(), importStackMode.pop()), e);
	}

	/**
	 * Preprocesses the expression, like 'a'.code => 97
	 * Also for transforming any abstracts into their implementations (TODO)
	 * Also for transforming any static extensions into their real form (TODO)
	 * Also to automatically add imports for stuff that is not imported
	**/
	public static function process(e:Expr, top:Bool = true):Expr {
		importStackName = [];
		importStackMode = [];
		var e = _process(e, top);

		// Automatically add imports for stuff
		switch(expr(e)) {
			case EBlock(exprs):
				while(importStackName.length > 0) {
					exprs.unshift(popImport(e));
				}
				return mk(EBlock(exprs), e);
			default:
				if(importStackName.length > 0) {
					var exprs = [];
					while(importStackName.length > 0) {
						exprs.unshift(popImport(e));
					}
					exprs.push(e);
					return mk(EBlock(exprs), e);
				}
		}
		return e;
	}

	private static function _process(e:Expr, top:Bool = true):Expr {
		if(e == null)
			return null;

		// If stuff looks wrong, add this back
		//e = Tools.map(e, function(e) {
		//	return _process(e, false);
		//});

		//trace(expr(e));

		switch(expr(e)) {
			case EField(expr(_) => EConst(CString(s)), "code", _): // Transform string.code into charCode
				if(s.length != 1) {
					throw Parser.getBaseError(EPreset(INVALID_CHAR_CODE_MULTI));
				}
				return mk(EConst(CInt(s.charCodeAt(0))), e);
			case ECall(expr(_) => EField(expr(_) => EIdent("String"), "fromCharCode", _), [e]): // Seperate this later?
				switch(expr(e)) { // should this be Optimizer?
					case EConst(CInt(i)):
						return mk(EConst(CString(String.fromCharCode(i))), e);
					default:
				}
				if(!Preprocessor.isStringFromCharCodeFixed) {
					// __StringWorkaround__fromCharCode(i);
					#if !NO_FROM_CHAR_CODE_FIX
					return mk(ECall(mk(EIdent("__StringWorkaround__fromCharCode"), e), [e]), e);
					#else
					throw Parser.getBaseError(EPreset(FROM_CHAR_CODE_NON_INT));
					#end
				}

			// Automatically add imports for stuff
			case ENew("String", _): addImport("String");
			case EIdent("String"): addImport("String");
			case ENew("StringBuf", _): addImport("StringBuf");
			case EIdent("StringBuf"): addImport("StringBuf");
			case EIdent("Bool"): addImport("Bool");
			case EIdent("Float"): addImport("Float");
			case EIdent("Int"): addImport("Int");
			case ENew("IntIterator", _): addImport("IntIterator");
			case EIdent("IntIterator"): addImport("IntIterator");
			case EIdent("Array"): addImport("Array");

			case EIdent("Sys"): addImport("Sys");
			case EIdent("Std"): addImport("Std");
			case EIdent("Type"): addImport("Type");
			case EIdent("Reflect"): addImport("Reflect");
			case EIdent("StringTools"): addImport("StringTools");
			case EIdent("Math"): addImport("Math");
			case ENew("Date", _): addImport("Date");
			case EIdent("Date"): addImport("Date");
			case EIdent("DateTools"): addImport("DateTools");
			case EIdent("Lambda"): addImport("Lambda");
			case ENew("Xml", _): addImport("Xml");
			case EIdent("Xml"): addImport("Xml");
			//case EIdent("List"): addImport("haxe.ds.List");

			case ENew("EReg", _): addImport("EReg");
			case EIdent("EReg"): addImport("EReg");
			//case EField(expr(_) => EIdent("EReg"), "escape", _):
			//	addImport("EReg");
			default:
		}

		e = Tools.map(e, function(e) {
			return _process(e, false);
		});

		return e;
	}

	static function mk(e:ExprDef, s:Expr):Expr {
		#if hscriptPos
		return new Expr(e, s.pmin, s.pmax, s.origin, s.line);
		#else
		return e;
		#end
	}

	public static var isStringFromCharCodeFixed(get, null):Null<Bool> = null;
	static function get_isStringFromCharCodeFixed():Null<Bool> {
		if(isStringFromCharCodeFixed == null) {
			try {
				Reflect.callMethod(null, Reflect.field(String, "fromCharCode"), [65]);
				isStringFromCharCodeFixed = true;
			} catch(e:Dynamic) {
				isStringFromCharCodeFixed = false;
			}
		}
		return isStringFromCharCodeFixed;
	}

	public static function processvars(e:Expr, vars:Array<String>) {
		getvars(e, vars);
		e = Tools.map(e, function(e) {
			return switch (expr(e)) {
				case EIdent(v, _):
					return mk(EIdent(v, vars.indexOf(v)), e);
				case EVar(n, t, e, p, s, _):
					return mk(EVar(n, t, e, p, s, vars.indexOf(n)), e);
				case EFunction(args, e, n, r, p, s, o, _):
					return mk(EFunction(args, e, n, r, p, s, o, vars.indexOf(n)), e);
				case ENew(cl, p, _):
					return mk(ENew(cl, p, vars.indexOf(cl)), e);
				case EClass(n, fls, extnd, i, _):
					return mk(EClass(n, fls, extnd, i, vars.indexOf(n)), e);
				default: e;
			};
		});

		return e;
	}

	public static function getvars(e:Expr, vars:Array<String>) {
		// TODO: Use a Tools function to make this cleaner (im too lazy rn) -lunar
		switch (expr(e)) {
			case EIdent(v):
				if (!vars.contains(v))
					vars.push(v);
			case EBlock(e):
				for (expr in e)
					getvars(expr, vars);
			case EFunction(_,e,name,_,_,_,_):
				getvars(e, vars);
				if (!vars.contains(name))
					vars.push(name);
			case ESwitch(e,cases,de):
				for (c in cases)
					getvars(c.expr, vars);
				getvars(de, vars);
			case EObject(fls):
				for (fl in fls) getvars(fl.e, vars);
			case EVar(n, t, e, _,_): 
				if (!vars.contains(n))
					vars.push(n);
				getvars(e, vars);
			case EIf(c,e1,e2): 
				getvars(c, vars);
				getvars(e1, vars);
				getvars(e2, vars);
			case EBinop(_,e1,e2):
				getvars(e1, vars);
				getvars(e2, vars);
			case EUnop(_,_,e): getvars(e, vars);
			case EWhile(c,e):
				getvars(c, vars);
				getvars(e, vars);
			case EDoWhile(e1,e2): 
				getvars(e1, vars);
				getvars(e2, vars);
			case EFor(_,it,e):
				getvars(it, vars);
				getvars(e, vars);
			case EForKeyValue(_,it,e,_): 
				getvars(it, vars);
				getvars(e, vars);
			case EReturn(e): getvars(e, vars);
			case ETry(e, _, _, ec): 
				getvars(e, vars);
				getvars(ec, vars);
			case ECall(e, params): 
				getvars(e, vars);
				for (e in params) getvars(e, vars);
			case EParent(e, _): getvars(e, vars);
			case EArray(e, indx):
				getvars(e, vars);
				getvars(indx, vars);
			case EMapDecl(_, keys, values):
				for (k in keys) getvars(k, vars);
				for (v in values) getvars(v, vars);
			case EArrayDecl(list):
				for (e in list) getvars(e, vars);
			case ENew(cl, params):
				if (!vars.contains(cl))
					vars.push(cl);
				for (e in params) getvars(e, vars);
			case EThrow(e):
				getvars(e, vars);
			case ETernary(e, e1, e2):
				getvars(e1, vars);
				getvars(e2, vars);
				getvars(e, vars);
			case EMeta(_, args, e):
				for (a in args) getvars(a, vars);
				getvars(e, vars);
			case ECheckType(e, _):
				getvars(e, vars);
			case EField(e, _, _):
				getvars(e, vars);
			case EClass(name, fls,_,_):
				if (!vars.contains(name))
					vars.push(name);
				for (fl in fls) getvars(fl, vars);
			default:
		}
	}
}