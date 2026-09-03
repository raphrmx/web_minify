import 'package:test/test.dart';
import 'package:web_minify/web_minify.dart';

void main() {
  group('HtmlMinifier', () {
    test('removes whitespace between block elements', () {
      expect(minifyHtml('<div>\n  <p>Hello</p>\n</div>'), '<div><p>Hello</p></div>');
    });

    test('keeps the space between inline elements', () {
      expect(minifyHtml('<span>a</span>\n<span>b</span>'), '<span>a</span> <span>b</span>');
    });

    test('collapses whitespace runs inside text', () {
      expect(minifyHtml('<p>one   two\n\tthree</p>'), '<p>one two three</p>');
    });

    test('keeps a doctype from gaining a leading space', () {
      expect(minifyHtml('<!DOCTYPE html>\n<html>\n</html>'), '<!DOCTYPE html><html></html>');
    });

    test('removes comments but keeps conditional ones', () {
      expect(minifyHtml('<div>\n<!-- note -->\n<p>a</p></div>'), '<div><p>a</p></div>');
      expect(minifyHtml('<!--[if IE]><p>a</p><![endif]-->'), '<!--[if IE]><p>a</p><![endif]-->');
    });

    test('copies a pre body byte for byte', () {
      const source = '<div>\n<pre>  a\n    b  </pre>\n</div>';
      expect(minifyHtml(source), '<div><pre>  a\n    b  </pre></div>');
    });

    test('copies a textarea body byte for byte', () {
      expect(minifyHtml('<textarea>\n  a\n</textarea>'), '<textarea>\n  a\n</textarea>');
    });

    test('normalises whitespace inside a tag', () {
      expect(minifyHtml('<a\n   href = "/x"\n   class="b c" >x</a>'), '<a href="/x" class="b c">x</a>');
    });

    test('keeps a self closing tag closed', () {
      expect(minifyHtml('<br />'), '<br/>');
    });

    test('minifies an inline stylesheet', () {
      expect(minifyHtml('<style>\n  body {\n    color: #ffffff;\n  }\n</style>'), '<style>body{color:#fff}</style>');
    });

    test('minifies an inline script', () {
      expect(minifyHtml('<script>\n  const a = 1;\n  // note\n  f(a);\n</script>'), '<script>const a=1;f(a);</script>');
    });

    test('leaves a non javascript script body alone', () {
      const source = '<script type="application/json">\n  {"a": 1}\n</script>';
      expect(minifyHtml(source), '<script type="application/json">\n  {"a": 1}\n</script>');
    });

    test('leaves placeholders untouched', () {
      expect(
        minifyHtml('<html lang="{{lang}}">\n<title>{{pageTitle}}</title>\n</html>'),
        '<html lang="{{lang}}"><title>{{pageTitle}}</title></html>',
      );
    });

    test('treats an unknown element as inline', () {
      expect(
        minifyHtml('<my-widget>a</my-widget>\n<my-widget>b</my-widget>'),
        '<my-widget>a</my-widget> <my-widget>b</my-widget>',
      );
    });

    test('keeps a stray angle bracket in text', () {
      expect(minifyHtml('<p>a &lt; b < c</p>'), '<p>a &lt; b < c</p>');
    });
  });
}
