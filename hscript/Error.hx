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

#if hscriptPos
class Error_ {
	public var e : ErrorDef;
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
	public function toString(): String {
		return Printer.errorToString(this);
	}
}
enum ErrorDef
#else
enum Error_
#end
{
	EInvalidChar( c : Int );
	EUnexpected( s : String );
	EUnterminatedString;
	EUnterminatedComment;
	EUnterminatedRegex;
	EInvalidPreprocessor( msg : String );
	EUnknownVariable( v : String );
	EInvalidIterator( v : String );
	EInvalidType( t : String );
	EInvalidOp( op : String );
	EInvalidAccess( f : String, ?on : String );
	ECustom( msg : String );
	EPreset( msg : ErrorMessage );
	EInvalidClass( className : String);
	EAlreadyExistingClass( className : String);
	EInvalidEscape( s : String );
}

enum abstract ErrorMessage(Expr.UInt8) from Expr.UInt8 to Expr.UInt8 {
    final INVALID_CHAR_CODE_MULTI;
    final FROM_CHAR_CODE_NON_INT;
    final EMPTY_INTERPOLATION;
    final UNKNOWN_MAP_TYPE;
    final UNKNOWN_MAP_TYPE_RUNTIME;
    final EXPECT_KEY_VALUE_SYNTAX;

    public function toString():String {
        return switch(cast this) {
            case INVALID_CHAR_CODE_MULTI: "'char'.code only works on single characters";
            case FROM_CHAR_CODE_NON_INT: "String.fromCharCode only works on integers";
            case EMPTY_INTERPOLATION: "Invalid interpolation: Expression cannot be empty";
            case UNKNOWN_MAP_TYPE: "Unknown Map Type";
            case UNKNOWN_MAP_TYPE_RUNTIME: "Unknown Map Type, while parsing at runtime";
            case EXPECT_KEY_VALUE_SYNTAX: "Expected a => b";
        }
    }
}