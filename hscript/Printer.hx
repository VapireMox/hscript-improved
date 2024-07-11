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
package hscript;
import hscript.Expr;

class Printer {

	var buf : StringBuf;
	var tabs : String;

	public function new() {
	}

	public function exprToString( e : Expr ) {
		buf = new StringBuf();
		tabs = "";
		expr(e);
		return buf.toString();
	}

	public static function convertExprToString( e : Expr ) {
		var printer = new Printer();
		return printer.exprToString(e);
	}

	public function typeToString( t : CType ) {
		buf = new StringBuf();
		tabs = "";
		type(t);
		return buf.toString();
	}

	public static function convertTypeToString( t : CType ) {
		var printer = new Printer();
		return printer.typeToString(t);
	}

	inline function add<T>(s:T) buf.add(s);

	function type( t : CType ) {
		switch( t ) {
		case CTOpt(t):
			add('?');
			type(t);
		case CTPath(path, params):
			add(path.join("."));
			if( params != null ) {
				add("<");
				var first = true;
				for( p in params ) {
					if( first ) first = false else add(", ");
					type(p);
				}
				add(">");
			}
		case CTNamed(name, t):
			add(name);
			add(':');
			type(t);
		case CTFun(args, ret) if (Lambda.exists(args, function (a) return a.match(CTNamed(_, _)))):
			add('(');
			var first = true;
			for (i=>a in args) {
				switch a {
					case CTNamed(_, _): type(a);
					default: type(CTNamed('_', a));
				}
				if( i != args.length - 1 ) add(", ");
			}
			add(')->');
			type(ret);
		case CTFun(args, ret):
			if( args.length == 0 )
				add("Void -> ");
			else {
				for( a in args ) {
					type(a);
					add(" -> ");
				}
			}
			type(ret);
		case CTAnon(fields):
			add("{");
			var first = true;
			for( f in fields ) {
				if( first ) { first = false; add(" "); } else add(", ");
				add(f.name + " : ");
				type(f.t);
			}
			add(first ? "}" : " }");
		case CTParent(t):
			add("(");
			type(t);
			add(")");
		}
	}

	function addType( t : CType ) {
		if( t != null ) {
			add(" : ");
			type(t);
		}
	}

	function block(e : Expr, addSpaceIfBlock : Bool = true) {
		var isBlock = Tools.expr(e).match(EBlock(_));
		if(isBlock) {
			if(addSpaceIfBlock) add(" ");
		} else {
			add("\n");
			tabs += "\t";
			add(tabs);
		}
		expr(e);

		if(!isBlock) {
			//add("\n");
			tabs = tabs.substr(1);
			//add(tabs);
		}

		return isBlock;
	}

	function isJson(s:String) {
		var len = s.length;
		var i = 0;
		while (i < len) {
			switch (StringTools.fastCodeAt(s, i++)) {
				// [a-zA-Z0-9_]+
				case "a".code | "b".code | "c".code | "d".code | "e".code | "f".code | "g".code | "h".code | "i".code | "j".code | "k".code | "l".code | "m".code
					| "n".code | "o".code | "p".code | "q".code | "r".code | "s".code | "t".code | "u".code | "v".code | "w".code | "x".code | "y".code | "z".code
					| "A".code | "B".code | "C".code | "D".code | "E".code | "F".code | "G".code | "H".code | "I".code | "J".code | "K".code | "L".code | "M".code
					| "N".code | "O".code | "P".code | "Q".code | "R".code | "S".code | "T".code | "U".code | "V".code | "W".code | "X".code | "Y".code | "Z".code
					| "0".code | "1".code | "2".code | "3".code | "4".code | "5".code | "6".code | "7".code | "8".code | "9".code | "_".code:
				case _:
					return true;
			}

		}
		return false;
	}

	static inline function isPrintable( c : Int ) {
		return c >= 32 && c <= 126;
	}

	static inline function hex( c : Int, ?len : Int = 2 ) {
		return StringTools.hex(c, len).toLowerCase();
	}

	public static function getEscapedString( s : String ) {
		var buf = new StringBuf();
		#if target.unicode
		var s = new UnicodeString(s);
		#end
		for( i in 0...s.length ) {
			#if target.unicode
			var c:Null<Int> = s.charCodeAt(i);
			#else
			var c:Null<Int> = StringTools.unsafeCodeAt(s, i);
			#end
			switch( c ) {
				case '"'.code: buf.add('\\"');
				case '\\'.code: buf.add('\\\\');
				case '\n'.code: buf.add('\\n');
				case '\r'.code: buf.add('\\r');
				case '\t'.code: buf.add('\\t');
				default:
					if(c == null) continue;
					if(isPrintable(c))
						buf.addChar(c);
					else {
						if(c > 0xFF) {
							buf.add("\\u{");
							buf.add(hex(c, null));
							buf.add("}");
						} else {
							buf.add("\\x");
							buf.add(hex((c & 0xFF)));
						}
					}
			}
		}
		return buf.toString();
	}

	function getVar(v:VarN) {
		if( v == null ) {
			return ("??NULL??");
		}

		if(v is Int) {
			return ("$" + v);
		} else {
			return (v);
		}
	}

	public static function getBinaryOp(op:Binop) {
		return switch(op) {
			case OpAdd: "+";
			case OpSub: "-";
			case OpMult: "*";
			case OpDiv: "/";
			case OpMod: "%";
			case OpAnd: "&";
			case OpOr: "|";
			case OpXor: "^";
			case OpShl: "<<";
			case OpShr: ">>";
			case OpUShr: ">>>";
			case OpEq: "==";
			case OpNotEq: "!=";
			case OpGt: ">";
			case OpGte: ">=";
			case OpLt: "<";
			case OpLte: "<=";
			case OpBoolAnd: "&&";
			case OpBoolOr: "||";
			case OpIs: "is";
			case OpNullCoal: "??";
			case OpAssign: "=";
			case OpArrow: "=>";
			case OpInterval: "...";
			case OpAssignOp(op): getBinaryOp(op) + "=";
		}
	}

	public static function getUnaryOp(op:Unop) {
		return switch(op) {
			case OpIncrement: "++";
			case OpDecrement: "--";
			case OpNot: "!";
			case OpNeg: "-";
			case OpNegBits: "~";
			case OpSpread: "...";
		}
	}

	function expr( e : Expr ) {
		if( e == null ) {
			add("??NULL??");
			return;
		}

		// TODO: make else if print correctly

		switch( Tools.expr(e) ) {
		case EImport(c, mode):
			add("import " + c);
			switch(mode) {
				case IAs(name): add(' as $name');
				case IAll: add('.*');
				default:
			}
		case EClass(name, fields, extend, interfaces):
			add('class ${getVar(name)}');
			if (extend != null)
				add(' extends $extend');
			for(_interface in interfaces) {
				add(' implements $_interface');
			}
			add(' {\n');
			tabs += "\t";
			// TODO: Print fields
			//for(field in fields) {
			//	expr(field);
			//}

			tabs = tabs.substr(1);
			add("}");
		case EConst(c):
			switch( c ) {
			case CInt(i): add(i);
			case CFloat(f): add(f);
			case CString(s):
				add('"');
				add(getEscapedString(s));
				add('"');
			}
		case EIdent(v):
			add(getVar(v));
		case EVar(n, t, e): // TODO: static, public, override
			add("var " + getVar(n));
			if( t != null )
				addType(t);
			else
				switch( Tools.expr(e) ) {
					case EMapDecl(type, _, _):
						add(" : Map<");
						switch( type ) {
							case ObjectMap: add("Dynamic");
							case StringMap: add("String");
							case EnumMap: add("EnumValue");
							case IntMap: add("Int");
							case UnknownMap: add("?");
							case Null: add("Null");
						}
						add(", Dynamic>");
					default:
				}
			if( e != null ) {
				add(" = ");
				expr(e);
			}
		case EParent(e):
			add("("); expr(e); add(")");
		case EBlock(el):
			if( el.length == 0 ) {
				add("{}");
			} else {
				tabs += "\t";
				add("{\n");
				for( e in el ) {
					add(tabs);
					expr(e);
					add(";\n");
				}
				tabs = tabs.substr(1);
				add(tabs);
				add("}");
			}
		case EField(e, f, s):
			expr(e);
			add((s == true ? "?." : ".") + f);
		case EBinop(op, e1, e2):
			/*var op1 = switch(Tools.expr(e1)) {
				case EBinop(op, _, _): op;
				case EConst(_): "_";
				case EIdent(_): "_";
				default: null;
			}
			var op2 = switch(Tools.expr(e2)) {
				case EBinop(op, _, _): op;
				case EConst(_): "_";
				case EIdent(_): "_";
				default: null;
			}
			var paran = Tools.checkOpPrecedence(op, op1, op2);*/
			var paran = 2;

			var op = getBinaryOp(op);

			if(paran == 0 || paran == 2) {
				add("(");
				expr(e1);
				add(")");
			} else {
				expr(e1);
			}
			if(op == "...")
				add(op);
			else
				add(" " + op + " ");
			if(paran == 1 || paran == 2) {
				add("(");
				expr(e2);
				add(")");
			} else {
				expr(e2);
			}
		case EUnop(op, pre, e):
			var op = getUnaryOp(op);

			if( pre ) {
				add(op);
				expr(e);
			} else {
				expr(e);
				add(op);
			}
		case ECall(e, args):
			if( e == null )
				expr(e);
			else switch( Tools.expr(e) ) {
				case EField(_), EIdent(_), EConst(_):
					expr(e);
				default:
					add("(");
					expr(e);
					add(")");
			}
			add("(");
			var first = true;
			for( a in args ) {
				if( first ) first = false else add(", ");
				expr(a);
			}
			add(")");
		case EIf(cond,e1,e2):
			add("if( ");
			expr(cond);
			add(" )");
			var wasBlock = block(e1, true);

			if( e2 != null ) {
				if(!wasBlock) add("\n" + tabs);
				add(" else ");
				block(e2);
			}
		case EWhile(cond,e):
			add("while( ");
			expr(cond);
			add(" )");
			block(e, true);
		case EDoWhile(cond,e):
			add("do");
			block(e, true);
			add(" while ( ");
			expr(cond);
			add(" )");
		case EFor(v, it, e):
			add("for( "+getVar(v)+" in ");
			expr(it);
			add(" )");
			block(e, true);
		case EForKeyValue(v, it, e, ithv):
			add("for( "+getVar(ithv)+" => "+getVar(v)+" in ");
			expr(it);
			add(" )");
			block(e, true);
		case EBreak:
			add("break");
		case EContinue:
			add("continue");
		case EFunction(params, e, name, ret): // TODO: static, public, override
			add("function");
			if( name != null )
				add(" " + getVar(name));
			add("(");
			var first = true;
			for( a in params ) {
				if( first ) first = false else add(", ");
				if( a.opt ) add("?");
				add(getVar(a.name));
				addType(a.t);
			}
			add(")");
			addType(ret);
			add(" ");
			expr(e);
		case EReturn(e):
			add("return");
			if( e != null ) {
				add(" ");
				expr(e);
			}
		case EArray(e,index):
			expr(e);
			add("[");
			expr(index);
			add("]");
		case EMapDecl(type, keys, values):
			add("[");
			var first = true;
			for( i in 0...keys.length ) {
				if( first ) first = false else add(", ");
				expr(keys[i]);
				add(" => ");
				expr(values[i]);
			}
			add("]");
		case EArrayDecl(el):
			add("[");
			var first = true;
			for( e in el ) {
				if( first ) first = false else add(", ");
				expr(e);
			}
			add("]");
		case ENew(cl, args):
			add("new " + getVar(cl) + "(");
			var first = true;
			for( e in args ) {
				if( first ) first = false else add(", ");
				expr(e);
			}
			add(")");
		case EThrow(e):
			add("throw ");
			expr(e);
		case ETry(e, v, t, ecatch):
			add("try");
			var wasBlock = block(e);
			if( !wasBlock ) {
				add("\n" + tabs);
			} else add(" ");
			add("catch( " + v);
			addType(t);
			add(" )");
			block(ecatch);
		case EObject(fl):
			if( fl.length == 0 ) {
				add("{}");
			} else {
				tabs += "\t";
				add("{\n");
				for( i=>f in fl ) {
					add(tabs);
					var name = isJson(f.name) ? "\"" + f.name + "\"" : f.name;
					add(name+" : ");
					expr(f.e);
					if( i != fl.length - 1 ) add(",");
					add("\n");
				}
				tabs = tabs.substr(1);
				add(tabs);
				add("}");
			}
		case ETernary(c,e1,e2):
			expr(c);
			add(" ? ");
			expr(e1);
			add(" : ");
			expr(e2);
		case ESwitch(e, cases, def):
			add("switch( ");
			expr(e);
			add(" ) {\n");
			tabs += "\t";
			for( c in cases ) {
				add(tabs);
				add("case ");
				var first = true;
				for( v in c.values ) {
					if( first ) first = false else add(", ");
					expr(v);
				}
				add(":");
				block(c.expr, true);
				add(";\n");
			}
			if( def != null ) {
				add(tabs);
				add("default: ");
				block(def, true);
				add(";\n");
			}
			tabs = tabs.substr(1);
			add(tabs);
			add("}");
		case EMeta(name, args, e):
			add("@");
			add(name);
			if( args != null && args.length > 0 ) {
				add("(");
				var first = true;
				for( a in args ) {
					if( first ) first = false else add(", ");
					expr(e);
				}
				add(")");
			}
			add(" ");
			expr(e);
		case ECheckType(e, t):
			add("(");
			expr(e);
			add(" : ");
			addType(t);
			add(")");
		case EInfo(_, e):
			expr(e);
		}
	}

	public inline static function toString( e : Expr ) {
		return new Printer().exprToString(e);
	}

	public inline static function compareErrors( e1 : Error, e2 : Error ) {
		return Type.enumEq(Tools.cleanError(e1), Tools.cleanError(e2));
	}

	public inline static function getPrintableError( e : Error ) {
		return Tools.cleanError(switch( Tools.cleanError(e) ) {
			case EPreset(msg): Parser.getBaseError(ECustom(msg.toString()));
			default: e;
		});
	}

	public static function errorToString( e : Error ) {
		var message = switch( Tools.cleanError(e) ) {
			case EInvalidChar(c): "Invalid character: '"+(StringTools.isEof(c) ? "EOF (End Of File)" : String.fromCharCode(c))+"' ("+c+")";
			case EUnexpected(s): "Unexpected token: \""+s+"\"";
			case EUnterminatedString: "Unterminated string";
			case EUnterminatedComment: "Unterminated comment";
			case EUnterminatedRegex: "Unterminated regular expression";
			case EInvalidPreprocessor(str): "Invalid preprocessor (" + str + ")";
			case EUnknownVariable(v): "Unknown variable: "+v;
			case EInvalidIterator(v): "Invalid iterator: "+v;
			case EInvalidType(t): "Invalid type: "+t;
			case EInvalidOp(op): "Invalid operator: "+op;
			case EInvalidAccess(f, on) if (on != null): "Invalid access to field " + f + " on " + on;
			case EInvalidAccess(f): "Invalid access to field " + f;
			case ECustom(msg): msg;
			case EPreset(msg): msg.toString();
			case EInvalidClass(cla): "Invalid class: " + cla + " was not found.";
			case EAlreadyExistingClass(cla): 'Custom Class named $cla already exists.';
			case EInvalidEscape(s): "Invalid escape sequence: " + s;
		};
		#if hscriptPos
		return e.origin + ":" + e.line + ": " + message;
		#else
		return message;
		#end
	}


}
