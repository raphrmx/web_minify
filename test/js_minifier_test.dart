import 'package:test/test.dart';
import 'package:web_minify/web_minify.dart';

void main() {
  group('JsMinifier', () {
    test('drops indentation and line comments', () {
      expect(minifyJs('const a = 1;\n// note\nconst b = a + 2;'), 'const a=1;const b=a+2;');
    });

    test('keeps the line break that automatic semicolon insertion needs', () {
      expect(minifyJs('const a = 1\nconst b = 2\n'), 'const a=1\nconst b=2');
    });

    test('keeps the line break after an object literal', () {
      expect(minifyJs('const a = {}\nb();'), 'const a={}\nb();');
    });

    test('keeps the line break after an increment', () {
      expect(minifyJs('a++\nb();'), 'a++\nb();');
    });

    test('keeps the line break after return', () {
      expect(minifyJs('function f() {\n  return\n  1;\n}'), 'function f(){return\n1;}');
    });

    test('drops the line break inside an argument list', () {
      expect(minifyJs('f(\n  1,\n  2\n);'), 'f(1,2);');
    });

    test('copies string literals verbatim', () {
      expect(minifyJs("const u = 'http://a.b/c'; // trail"), "const u='http://a.b/c';");
    });

    test('copies template literals verbatim, substitutions included', () {
      const source = 'const t = `a\n  b \${ x + 1 } c`;';
      expect(minifyJs(source), 'const t=`a\n  b \${ x + 1 } c`;');
    });

    test('recognises a regular expression literal after an operator', () {
      expect(minifyJs('const r = /a\\/b[/]c/gi;'), 'const r=/a\\/b[/]c/gi;');
    });

    test('recognises a regular expression literal after return', () {
      expect(minifyJs('function f() { return /ab+c/.test(s); }'), 'function f(){return/ab+c/.test(s);}');
    });

    test('treats a slash after a closing parenthesis as division', () {
      expect(minifyJs('const c = (a + b) / 2;'), 'const c=(a+b)/2;');
    });

    test('keeps two operators from fusing into a new token', () {
      expect(minifyJs('const a = b + +c;'), 'const a=b+ +c;');
      expect(minifyJs('const a = b - -c;'), 'const a=b- -c;');
    });

    test('keeps keywords apart', () {
      expect(minifyJs('for (const key in map) {}'), 'for(const key in map){}');
    });

    test('removes block comments but keeps bang comments', () {
      expect(minifyJs('/* note */\nconst a = 1;'), 'const a=1;');
      expect(minifyJs('/*! keep */\nconst a = 1;'), '/*! keep */\nconst a=1;');
    });

    test('returns an empty string for a blank script', () {
      expect(minifyJs('  \n\t'), '');
    });
  });
}
