package tests;

class FinalCase extends TestCase {
	override function setup() {
		super.setup();
	}

	override function getNewInterp() {
		Util.defaultImport = false;
		var interp = super.getNewInterp();
		Util.defaultImport = true;
		//interp.variables.set("Std", Std);
		//interp.variables.set("String", String);
		//interp.variables.set("Bool", Bool);
		//interp.variables.set("Float", Float);
		//interp.variables.set("Array", Array);
		//interp.variables.set("Int", Int);
		//interp.variables.set("IntIterator", IntIterator);
		return interp;
	}

	override function run() {
        headerCode = "var i = 5; var x = 10;";

        var i = 5; var x = 10;

		assertDisplay("(i - x) * 30 + 90", ((i-x) * 30) + 90);
		assertDisplay("i - x * 30 + 90", i-x * 30 + 90);

		/*
		// Test operator precedence
		assertDisplay("i / x * 30 + 90", i / x * 30 + 90);
		assertDisplay("i / (x * 30) + 90", i / (x * 30) + 90);

		assertDisplay("x * 30 / i + 90", x * 30 / i + 90);
		//assertEq("(x * 30) / i + 90", x * 30 / i + 90);

		// (_) -> {a = false;}
		// Shouldnt be converted to  (_) -> return {a = false;}

		Util.parse("openCodesList(false, codesOpened ? false : true, previousOpen != open ? true : false);");
		Util.parse("openCodesList(false, 'HELLO' ? false : false, 'WORLD' ? true : true);");
		Util.parse('FlxTween.tween(newSprite, {"scale.x": 1, "scale.y": 1, alpha: 1, angle: 0}, 0.3, {ease: FlxEase.qaudInOut});');
		Util.parse('
		bloomShader.dim = dim = .8 + (.3 * FlxMath.fastSin(__totalTime));
		bloomShader.size = size = 18 + (8 * FlxMath.fastSin(__totalTime));
		');
		*/

		Util.parse('sprite.setPosition(codesList.x + (sprite.ID % 2 == 1 ? 240 : 67),codesList.y + (15 * sprite.ID) + (sprite.ID%2 == 1 ? 35 : 54));');

		headerCode = "import tests.FinalCase.TestEnum;";

		assertEq("TestEnum.A", TestEnum.A);
		assertEq("TestEnum.B", TestEnum.B);
		assertEq("TestEnum.C(1, 2)", TestEnum.C(1, 2));
		assertEq("TestEnum.D(1, 2, 3)", TestEnum.D(1, 2, 3));

		Util.parse('test ? 0xFF343434 : 0xFF92A2FF');
		Util.parse('test ? 1 : 0.75;');

		Util.runKnownBug("Function then array causes error, unless the function ends with ;", function() {
			headerCode = "";
			function isEven(i:Int):Bool { return i % 2 == 0; }
			assertEq("function isEven(i:Int):Bool { return i % 2 == 0; }[for(i in 0...10) if(i % 2 == 0) i => isEven(i) else i => isEven(i)]", [for(i in 0...10) if(i % 2 == 0) i => isEven(i) else i => isEven(i)]);
		});

		assertEq("[for(i in 0...10) i]", [for(i in 0...10) i]);
		assertEq("[for(i in 0...10) i => null]", [for(i in 0...10) i => null]);
		assertEq("[for(i in 0...10) if(i % 2 == 0) i => 'even' else i => 'odd']", [for(i in 0...10) if(i % 2 == 0) i => 'even' else i => 'odd']);
		assertEq("[for(i in 0...10) if(i % 2 == 0) 'even' else 'odd']", [for(i in 0...10) if(i % 2 == 0) 'even' else 'odd']);
		assertEq("[for(i in 0...10) for(j in 0...10) i * j]", [for(i in 0...10) for(j in 0...10) i * j]);

		headerCode = "function isEven(i:Int):Bool { return i % 2 == 0; };";
		function isEven(i:Int):Bool { return i % 2 == 0; }

		assertEq("[for(i in 0...10) if(i % 2 == 0) i => isEven(i) else i => isEven(i)]", [for(i in 0...10) if(i % 2 == 0) i => isEven(i) else i => isEven(i)]);
		assertEq("[for(i in 0...10) if(i % 2 == 0) isEven(i) else isEven(i)]", [for(i in 0...10) if(i % 2 == 0) isEven(i) else isEven(i)]);
		headerCode = "function area(a:Int, b:Int):Int { return a * b; };";
		function area(a:Int, b:Int):Int { return a * b; }

		assertEq("[for(i in 0...10) for(j in 0...10) area(i, j)]", [for(i in 0...10) for(j in 0...10) area(i, j)]);


		headerCode = "";

		assertEq("[0=>'hello', 1=>'world']", [0=>'hello', 1=>'world']);
		assertEq("[0=>'hello', 1=>'world'][1]", [0=>'hello', 1=>'world'][1]);
		assertEq("[0=>'hello', 5=>'world'][1]", [0=>'hello', 5=>'world'][1]);

		assertEq("
		import tests.FinalCase;

		FinalCase.test1();
		", FinalCase.test1());

		assertEq("
		import tests.FinalCase as FC;

		FC.test1();
		", FinalCase.test1());

		assertEq("
		import tests.FinalCase as FC;
		import tests.FinalCase.test;

		FC.test1() + test();
		", FinalCase.test1() + test());

		assertEq("
		//import Std.isOfType;

		Std.isOfType('', String);
		", Std.isOfType('', String));

		assertEq("
		import Std.isOfType;

		isOfType('', String);
		", Std.isOfType('', String));

		assertEq("
		import Math.round as F;
		F(2.9);", Math.round(2.9));

		assertEq("
		import Math.round;
		round(1.9);", Math.round(1.9));

		// Test EOF with preprocessor
	}

	static function test1() {
		return "hello";
	}

	static function test() {
		return "world";
	}

	function assertDisplay(script:String, expected:Dynamic) {
		var _script = script;
		script = '"${script}";\n' + script;
		assertEq(script, expected, _script);
	}

	override function teardown() {
		super.teardown();
	}
}

enum TestEnum {
	A;
	B;
	C(a:Int, b:Int);
	D(a:Int, b:Int, c:Int);
}