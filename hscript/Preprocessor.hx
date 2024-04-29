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
}