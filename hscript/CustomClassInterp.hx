package hscript;

@:allow(hscript.CustomClassHandler)
class CustomClassInterp extends Interp {
	private var onlyParseStatic:Bool = false;

	private var customClassHandler:CustomClassHandler = null;

	override function resolve(id:String, doException:Bool = true):Dynamic {
		if (id == null)
			return null;
		id = StringTools.trim(id);

		var l = locals.get(id);
		if (l != null && l.depth > 0)
			return l.r;

		if (scriptObject != null) {
			// search in object
			if (id == "this") {
				return scriptObject;
			} else if ((Type.typeof(scriptObject) == TObject) && Reflect.hasField(scriptObject, id)) {
				return Reflect.field(scriptObject, id);
			}else if(scriptObject is IHScriptCustomBehaviour) {
				if(variables.exists(id)) return cast(scriptObject, IHScriptCustomBehaviour).hget(id);
			} else {
				if (__instanceFields.contains(id)) {
					return Reflect.getProperty(scriptObject, id);
				} else if (__instanceFields.contains('get_$id')) { // getter
					return Reflect.getProperty(scriptObject, 'get_$id')();
				}
			}
		}

		if(customClassHandler != null) {
			if(staticVariables.exists(id)) return customClassHandler.hget(id);
		}

		if (l != null)
			return l.r;

		for(map in [variables, customClasses])
			if (map.exists(id))
				return map[id];

		final cl:Class<Dynamic> = Type.resolveClass(id);
		if(cl != null) {
			return Type.resolveClass(id);
		}

		if (doException)
			error(EUnknownVariable(id));
		return null;
	}

	override function setVar(name:String, v:Dynamic) {
		if (allowStaticVariables && staticVariables.exists(name)) {
			if(customClassHandler != null) {
				customClassHandler.hset(name, v);
				return;
			}
		}

		if(scriptObject != null) {
			if(scriptObject is IHScriptCustomBehaviour) {
				cast(scriptObject, IHScriptCustomBehaviour).hset(name, v);
				return;
			}
		}

		variables.set(name, v);
	}

	override function expr(e:Expr) {
		#if hscriptPos
		curExpr = e;
		var e = e.e;
		#end

		if(onlyParseStatic) {
			switch(e) {
				case EVar(n, _, e, isPublic, isStatic):
					declared.push({n: n, old: locals.get(n), depth: depth});
					if(depth == 0) {
						if(isStatic == true) {
							locals.set(n, {r: (e == null) ? null : expr(e), depth: depth});
							if(!staticVariables.exists(n)) {
								staticVariables.set(n, locals[n].r);
							}
							return null;
						}
					}
				default:
			}
		}

		return super.expr(e);
	}
}