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

enum Const {
	CInt( v : Int );
	CFloat( f : Float );
	CString( s : String );
	#if !haxe3
	CInt32( v : haxe.Int32 );
	#end
}

enum MapType {
	IntMap;
	StringMap;
	EnumMap;
	ObjectMap;
	UnknownMap;
}

typedef Error = hscript.Error.Error_;

#if hscriptPos
class Expr {
	public var e : ExprDef;
	public var pmin : Int;
	public var pmax : Int;
	public var origin : String;
	public var line : Int;
	public function new(e, pmin, pmax, origin, line) {
		this.e = e;
		this.pmin = pmin;
		this.pmax = pmax;
		this.origin = origin;
		this.line = line;
	}
}
enum ExprDef
#else
typedef ExprDef = Expr;
enum Expr
#end
{
	EConst( c : Const );
	EIdent( v : String , ?vid : Int);
	EVar( n : String, ?t : CType, ?e : Expr, ?isPublic : Bool, ?isStatic : Bool , ?vid : Int);
	EParent( e : Expr, ?noOptimize : Bool );
	EBlock( e : Array<Expr> );
	EField( e : Expr, f : String , ?safe : Bool );
	EBinop( op : String, e1 : Expr, e2 : Expr );
	EUnop( op : String, prefix : Bool, e : Expr );
	ECall( e : Expr, params : Array<Expr> );
	EIf( cond : Expr, e1 : Expr, ?e2 : Expr );
	EWhile( cond : Expr, e : Expr );
	EFor( v : String, it : Expr, e : Expr);
	EForKeyValue( v : String, it : Expr, e : Expr, ithv: String);
	EBreak;
	EContinue;
	EFunction( args : Array<Argument>, e : Expr, ?name : String, ?ret : CType, ?isPublic : Bool, ?isStatic : Bool, ?isOverride : Bool , ?fid : Int);
	EReturn( ?e : Expr );
	EArray( e : Expr, index : Expr );
	EMapDecl( type: MapType, keys: Array<Expr>, values: Array<Expr> );
	EArrayDecl( e : Array<Expr> );
	ENew( cl : String, params : Array<Expr> , ?cid : Int);
	EThrow( e : Expr );
	ETry( e : Expr, v : String, t : Null<CType>, ecatch : Expr );
	EObject( fl : Array<ObjectField> );
	ETernary( cond : Expr, e1 : Expr, e2 : Expr );
	ESwitch( e : Expr, cases : Array<SwitchCase>, ?defaultExpr : Expr );
	EDoWhile( cond : Expr, e : Expr);
	EMeta( name : String, args : Array<Expr>, e : Expr );
	ECheckType( e : Expr, t : CType );

	EImport( c : String, mode: KImportMode );
	EClass( name:String, fields:Array<Expr>, ?extend:String, interfaces:Array<String> , ?cid : Int );
}

enum KImportMode {
	INormal;
	IAs( name : String );
	IAll;
}

class ObjectField {
	public var name:String;
	public var e:Expr;

	public function new(name, e) {
		this.name = name;
		this.e = e;
	}
}

class SwitchCase {
	public var values : Array<Expr>;
	public var expr : Expr;

	public function new(values, expr) {
		this.values = values;
		this.expr = expr;
	}
}


//typedef Argument = { name : String, ?t : CType, ?opt : Bool, ?value : Expr };
class Argument {
	public var name : String;
	public var t : Null<CType>;
	public var opt : Bool;
	public var value : Null<Expr>;
	public function new(name, ?t, ?opt, ?value) {
		this.name = name;
		this.t = t;
		this.opt = opt;
		this.value = value;
	}
}

typedef Metadata = Array<{ name : String, params : Array<Expr> }>;

enum CType {
	CTPath( path : Array<String>, ?params : Array<CType> );
	CTFun( args : Array<CType>, ret : CType );
	CTAnon( fields : Array<{ name : String, t : CType, ?meta : Metadata }> );
	CTParent( t : CType );
	CTOpt( t : CType );
	CTNamed( n : String, t : CType );
}

enum ModuleDecl {
	DPackage( path : Array<String> );
	DImport( path : Array<String>, ?everything : Bool );
	DClass( c : ClassDecl );
	DTypedef( c : TypeDecl );
}

typedef ModuleType = {
	var name : String;
	var params : {}; // TODO : not yet parsed
	var meta : Metadata;
	var isPrivate : Bool;
}

typedef ClassDecl = {> ModuleType,
	var extend : Null<CType>;
	var implement : Array<CType>;
	var fields : Array<FieldDecl>;
	var isExtern : Bool;
}

typedef TypeDecl = {> ModuleType,
	var t : CType;
}

typedef FieldDecl = {
	var name : String;
	var meta : Metadata;
	var kind : FieldKind;
	var access : Array<FieldAccess>;
}

enum FieldAccess {
	APublic;
	APrivate;
	AInline;
	AOverride;
	AStatic;
	AMacro;
}

enum FieldKind {
	KFunction( f : FunctionDecl );
	KVar( v : VarDecl );
}

typedef FunctionDecl = {
	var args : Array<Argument>;
	var expr : Expr;
	var ret : Null<CType>;
}

typedef VarDecl = {
	var get : Null<String>;
	var set : Null<String>;
	var expr : Null<Expr>;
	var type : Null<CType>;
}
