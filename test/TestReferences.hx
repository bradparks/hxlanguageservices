package ;
import haxe.PosInfos;
import haxe.languageservices.util.MemoryVfs;
import haxe.languageservices.HaxeLanguageServices;
import haxe.unit.TestCase;

using StringTools;

class TestReferences extends HLSTestCase {
    private function assertReferences(program:String, assert:String, ?p:PosInfos) {
        var index = program.indexOf('###');
        program = program.replace('###', '');
        var hls = new HaxeLanguageServices(new MemoryVfs().set('live.hx', program));
        hls.updateHaxeFile('live.hx');
        assertEqualsString(assert, hls.getReferencesAt('live.hx', index), p);
    }

    public function testMethodReferences() {
        assertReferences(
            'class Test { function a() { } function b() { this.a(); ###a(); } }',
            'a:[22:23:Declaration,50:51:Read,55:56:Read]'
        );
    }

    public function testFunctionArgumentReferences() {
        assertReferences(
            'class Test { var m = 10; function a(###m) { m; this.m; return m + 1; } }',
            'm:[36:37:Declaration,41:42:Read,59:60:Read]'
        );
    }

    public function testSqStringReferences() {
        assertReferences(
            "class Test { var m = 10; function a(###m) { return '$m'; } }",
            'm:[36:37:Declaration,50:51:Read]'
        );
    }
}
