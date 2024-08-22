package hscript;

import hscript.Expr;
import hscript.Error;
import hscript.Tools;
import hscript.Parser;

@:access(hscript.Parser)
class Postprocessor {
	static inline function expr(e:Expr) return Tools.expr(e);

	static function mk(e:ExprDef, s:Expr):Expr {
		#if hscriptPos
		return new Expr(e, s.pmin, s.pmax, s.origin, s.line);
		#else
		return e;
		#end
	}

	#if !HSCRIPT_NO_INT_VARS
	public static function processvars(e:Expr, ?vars:Array<String>) {
		if(vars == null) vars = [];
		for(v in getvars(e)) vars.push(v);
        e = _processvars(e, vars);

		return mk(EInfo(new InfoClass(vars), e), e);
	}

    private static function _processvars(e:Expr, vars:Array<String>):Expr {
		if(e == null) return null;
		var ge = e;
		var doExtra = true;
        var e = switch (expr(e)) {
            case EIdent(v) if (v is String):
                mk(EIdent(vars.indexOf(v)), e);
            case EVar(n, t, _e, p, s) if (n is String):
                mk(EVar(vars.indexOf(n), t, _e, p, s), e);
            case EImport(c, IAs(n)) if (n is String):
                mk(EVar(vars.indexOf(n), null, mk(EImport(c, IAsReturn), e), false, false), e);
            case EFunction(args, _e, n, r, p, s, o) if (n is String):
				var _args:Array<Argument> = [
                    for (arg in args)
                        new Argument(vars.indexOf(arg.name), arg.t, arg.opt, arg.value)
                ];
                mk(EFunction(_args, _e, vars.indexOf(n), r, p, s, o), e);
			case EFunction(args, _e, null, r, p, s, o):
				var _args:Array<Argument> = [
					for (arg in args)
						new Argument(vars.indexOf(arg.name), arg.t, arg.opt, arg.value)
				];
				mk(EFunction(_args, _e, null, r, p, s, o), e);
            case ENew(cl, p) if (cl is String):
				var p = [for(arg in p) arg];
                mk(ENew(vars.indexOf(cl), p), e);
            case EClass(n, fls, extnd, i) if (n is String):
				var fls:Array<Expr> = [for(f in fls) f];
                mk(EClass(vars.indexOf(n), fls, extnd, i), e);
            case ETry(_e, v, t, ec) if (v is String):
                mk(ETry(_e, vars.indexOf(v), t, ec), e);
            case EFor(v, it, _e) if (v is String):
                mk(EFor(vars.indexOf(v), it, _e), e);
            case EForKeyValue(v, it, _e, ithv) if (v is String && ithv is String):
                mk(EForKeyValue(vars.indexOf(v), it, _e, vars.indexOf(ithv)), e);
            default: {
				doExtra = false;
				e;
			}
        };

		e = Tools.map(e, function(e) {
			return _processvars(e, vars);
		});

		return e;
    }

	public static function getvars(se:Expr, ?vars:Array<String>):Array<String> {
        inline function pushVar(v:VarN) {
			if(v is String) {
				var v:String = cast v;
				if (!vars.contains(v))
					vars.push(v);
			}
		};

		if(vars == null) vars = [];
		Tools.iterExprRecursive(se, (e) -> {
			switch (expr(e)) {
				case EVar(n, t, e, _,_): pushVar(n);
				case EIdent(v): pushVar(v);
				case EFunction(args,e,name,_,_,_,_):
					pushVar(name);
					for (a in args) {
						pushVar(a.name);
					}
				case EFor(v,it,e): pushVar(v);
				case EForKeyValue(v,it,e,ithv): pushVar(ithv); pushVar(v);
				case ETry(e, v, _, ec): pushVar(v);
				case ENew(cl, params): pushVar(cl);
				case EClass(name, fls,_,_): pushVar(name);
				default:
			}
		});
		return vars;
	}
	#end
}