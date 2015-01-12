package haxe.languageservices.grammar;

import haxe.languageservices.node.Const;
import haxe.languageservices.node.ZNode;
import haxe.languageservices.node.Node;
import haxe.languageservices.grammar.Grammar;
import haxe.languageservices.grammar.Grammar.Term;
import haxe.languageservices.grammar.Grammar.Reader;

class HaxeGrammar extends Grammar<Node> {
    public var ints:Term;
    public var fqName:Term;
    public var packageDecl:Term;
    public var importDecl:Term;
    public var usingDecl:Term;
    public var expr:Term;
    public var program:Term;
    
    private function buildNode(name:String): Dynamic -> Dynamic {
        return function(v) return Type.createEnum(Node, name, v);
    }

    private function buildNode2(name:String): Dynamic -> Dynamic {
        return function(v) return Type.createEnum(Node, name, [v]);
    }
    
    override private function simplify(znode:ZNode):ZNode {
        switch (znode.node) {
            case NAccessList(node, accessors):
                switch (accessors.node) {
                    case Node.NList([]): return node;
                    default:
                }
            default:
        }
        return znode;
    }
    
    private function operator(v:Dynamic):Term {
        return term(v, buildNode2('NOp'));
    }

    public function new() {
        function rlist(v) return Node.NList(v);
        //function rlist2(v) return Node.NListDummy(v);


        var int = term(~/^\d+/, function(v) return Node.NConst(Const.CInt(Std.parseInt(v))));
        var identifier = TReg(~/^[a-zA-Z]\w*/, function(v) return Node.NId(v));
        fqName = list(identifier, '.', function(v) return Node.NIdList(v));
        ints = list(int, ',', function(v) return Node.NConstList(v));
        //packageDesc = TSeq([TLit('package'), fqName, TLit(';')], function(v) return Node.NPackage(v[0]));
        packageDecl = seq(['package', fqName, ';'], buildNode('NPackage'));
        importDecl = seq(['import', fqName, ';'], buildNode('NImport'));
        usingDecl = seq(['using', fqName, ';'], buildNode('NUsing'));
        expr = createRef();
        //expr.term
        var ifExpr = seq(['if', '(', expr, ')', expr, opt(seqi(['else', expr]))], buildNode('NIf'));
        var forExpr = seq(['for', '(', identifier, 'in', expr, ')', expr], buildNode('NFor'));
        var breakExpr = seq(['break', ';'], buildNode('NBreak'));
        var continueExpr = seq(['continue', ';'], buildNode('NContinue'));
        var returnExpr = seq(['return', opt(expr), ';'], buildNode('NReturn'));
        var blockExpr = seq(['{', list(expr, ';', rlist), '}'], buildNode2('NBlock'));
        var parenExpr = seqi(['(', expr, ')']);
        var constant = any([ int, identifier ]);
        var type = createRef();

        var optType = opt(seq([':', type], identity));

        var typeName = seq([identifier, optType], buildNode('NIdWithType'));
        var typeNameList = list(typeName, ',', rlist);
        
        setRef(type, any([
            identifier,
            seq([ '{', typeNameList, '}' ], rlist),
        ]));
        
        var varDecl = seq(['var', identifier, optType, opt(seqi(['=', expr])), optError(';', 'expected semicolon')], buildNode('NVar'));
        var objectItem = seq([identifier, ':', expr], buildNode('NObjectItem'));

        var arrayExpr = seq(['[', list(expr, ',', rlist), ']'], buildNode2('NArray'));
        var objectExpr = seq(['{', list(objectItem, ',', rlist), '}'], buildNode2('NObject'));
        var literal = any([ constant, arrayExpr, objectExpr ]);
        var unaryOp = any([operator('++'), operator('--'), operator('+'), operator('-')]);
        var binaryOp = any(['+', '-', '*', '/', '%', '==', '!=', '<', '>', '<=', '>=', '&&', '||']);
        var primaryExpr = createRef();
        
        var unaryExpr = seq([unaryOp, primaryExpr], buildNode("NUnary"));
        //var binaryExpr = seq([primaryExpr, binaryOp, expr], identity);
    
        var exprCommaList = list(expr, ',', rlist);
    
        var arrayAccess = seq(['[', expr, ']'], buildNode('NAccess'));
        var fieldAccess = seq(['.', identifier], buildNode('NAccess'));
        var callPart = seq(['(', exprCommaList, ')'], buildNode('NCall'));
        var binaryPart = seq([binaryOp, expr], buildNode('NBinOpPart'));

        setRef(primaryExpr, any([
            parenExpr,
            unaryExpr,
            seq(['new', identifier, callPart], buildNode('NNew')),
            seq(
                [constant, list2(any([fieldAccess, arrayAccess, callPart, binaryPart]), rlist)],
                buildNode('NAccessList')
            ),
        ]));

        setRef(expr, any([
            varDecl,
            ifExpr,
            forExpr,
            breakExpr,
            continueExpr,
            returnExpr,
            blockExpr,
            primaryExpr,
            literal,
        ]));
        
        var typeParamItem = type;
        var typeParamDecl = seq(['<', list(typeParamItem, ',', rlist), '>'], buildNode2('NTypeParams'));
        
        var memberModifier = any(['static', 'public', 'private']);
        var functionDecl = seq(['function', identifier, '(', ')', expr], buildNode('NFunction'));
        var memberDecl = seq([opt(list2(memberModifier, rlist)), any([varDecl, functionDecl])], buildNode('NMember'));
        
        var extendsDecl = seq(['extends', type], buildNode('NExtends'));
        var implementsDecl = seq(['implements', type], buildNode('NImplements'));
        
        var extendsImplementsList = list2(any([extendsDecl, implementsDecl]), rlist);
        
        var classDecl = seq(
            ['class', identifier, opt(typeParamDecl), opt(extendsImplementsList), '{', list2(memberDecl, rlist), '}'],
            buildNode('NClass')
        );
        var typedefDecl = seq(
            ['typedef', identifier, '=', type],
            buildNode('NTypedef')
        );

        var enumDecl = seq(
            ['enum', identifier, '{', '}'],
            buildNode('NEnum')
        );

        var typeDecl = any([classDecl, typedefDecl, enumDecl]);

        program = list2(any([packageDecl, importDecl, usingDecl, typeDecl]), buildNode2('NFile'));
    }

    private var spaces = ~/^\s+/;
    override private function skipNonGrammar(str:Reader) {
        str.matchEReg(spaces);
    }
}
