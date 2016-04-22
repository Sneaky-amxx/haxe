using StringTools;

class HaxeInvocationException {

	public var message:String;
	public var fieldName:String;
	public var arguments:Array<String>;
	public var source:String;

	public function new(message:String, fieldName:String, arguments:Array<String>, source:String) {
		this.message = message;
		this.fieldName = fieldName;
		this.arguments = arguments;
		this.source = source;
	}
}

class DisplayTestContext {
	var source:File;
	var markers:Map<Int,Int>;
	var fieldName:String;

	public function new(path:String, fieldName:String, source:String, markers:Map<Int,Int>) {
		this.fieldName = fieldName;
		this.source = new File(path, source);
		this.markers = markers;
	}

	public function pos(id:Int):Int {
		var r = markers[id];
		if (r == null) throw "No such marker: " + id;
		return r;
	}

	public function range(pos1:Int, pos2:Int) {
		return normalizePath(source.formatPosition(pos(pos1), pos(pos2)));
	}

	public function field(pos:Int):String {
		return callHaxe('$pos');
	}

	public function toplevel(pos:Int):String {
		return callHaxe('$pos');
	}

	public function type(pos:Int):String {
		return extractType(callHaxe('$pos@type'));
	}

	public function positions(pos:Int):Array<String> {
		return extractPositions(callHaxe('$pos@position'));
	}

	public function position(pos:Int):String {
		return positions(pos)[0];
	}

	public function usage(pos:Int):Array<String> {
		return extractPositions(callHaxe('$pos@usage'));
	}

	function callHaxe(displayPart:String):String {
		var args = [
			"-cp", "src",
			"-D", "display-stdin",
			"--display",
			source.path + "@" + displayPart,
		];
		var stdin = source.content;
		var proc = new sys.io.Process("haxe", args);
		proc.stdin.writeString(stdin);
		proc.stdin.close();
		var stdout = proc.stdout.readAll();
		var stderr = proc.stderr.readAll();
		var exit = proc.exitCode();
		var success = exit == 0;
		var s = stderr.toString();
		if (!success || s == "") {
			throw new HaxeInvocationException(s, fieldName, args, stdin);
		}
		return s;
	}

	static function extractType(result:String) {
		var xml = Xml.parse(result);
		xml = xml.firstElement();
		if (xml.nodeName != "type") {
			return null;
		}
		return StringTools.trim(xml.firstChild().nodeValue);
	}

	static function extractPositions(result:String) {
		var xml = Xml.parse(result);
		xml = xml.firstElement();
		if (xml.nodeName != "list") {
			return null;
		}
		var ret = [];
		for (xml in xml.elementsNamed("pos")) {
			ret.push(normalizePath(xml.firstChild().nodeValue.trim()));
		}
		return ret;
	}

	static function normalizePath(p:String):String {
		if (!haxe.io.Path.isAbsolute(p)) {
			p = Sys.getCwd() + p;
		}
		if (Sys.systemName() == "Windows") {
			// on windows, haxe returns lowercase paths with backslashes
			p = p.replace("/", "\\");
			p = p.toLowerCase();
		}
		return p;
	}
}