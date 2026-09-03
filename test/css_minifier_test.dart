import 'package:test/test.dart';
import 'package:web_minify/web_minify.dart';

void main() {
  group('CssMinifier', () {
    test('collapses indentation and drops the last semicolon', () {
      expect(minifyCss('body {\n  color: red;\n  margin: 0;\n}\n'), 'body{color:red;margin:0}');
    });

    test('removes comments but keeps bang comments', () {
      expect(minifyCss('/* note */ a{color:red}'), 'a{color:red}');
      expect(minifyCss('/*! keep */a{color:red}'), '/*! keep */a{color:red}');
    });

    test('keeps a comment from gluing two tokens together', () {
      expect(minifyCss('a/**/b{color:red}'), 'a b{color:red}');
    });

    test('keeps descendant selectors apart', () {
      expect(minifyCss('.card  .title { color: red }'), '.card .title{color:red}');
    });

    test('tightens combinators outside declarations', () {
      expect(minifyCss('.a > .b + .c ~ .d { color: red }'), '.a>.b+.c~.d{color:red}');
    });

    test('keeps calc arithmetic spaced', () {
      expect(minifyCss('.a { width: calc(100% - 10px); }'), '.a{width:calc(100% - 10px)}');
    });

    test('tightens media features but keeps the prelude readable', () {
      expect(
        minifyCss('@media screen and (min-width: 700px) {\n  .a { color: red }\n}'),
        '@media screen and (min-width:700px){.a{color:red}}',
      );
    });

    test('keeps selectors inside an at-rule block from losing their spaces', () {
      expect(minifyCss('@media print {\n  .a .b { color: red }\n}'), '@media print{.a .b{color:red}}');
    });

    test('shortens six digit hex colours that repeat their pairs', () {
      expect(minifyCss('a{color:#ffffff;border-color:#22a9cb}'), 'a{color:#fff;border-color:#22a9cb}');
    });

    test('leaves id selectors alone', () {
      expect(minifyCss('#aabbcc{color:red}'), '#aabbcc{color:red}');
    });

    test('copies string values verbatim', () {
      expect(minifyCss('a::after{content:"  spaced  "}'), 'a::after{content:"  spaced  "}');
    });

    test('copies url values verbatim', () {
      expect(minifyCss('a{background:url(  img/a b.png  ) no-repeat}'), 'a{background:url(img/a b.png) no-repeat}');
    });

    test('tightens the bang of an important declaration', () {
      expect(minifyCss('a{color:red !important}'), 'a{color:red!important}');
    });

    test('returns an empty string for a blank stylesheet', () {
      expect(minifyCss('   \n\t '), '');
    });
  });
}
