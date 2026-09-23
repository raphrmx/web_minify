import 'package:test/test.dart';
import 'package:web_minify/web_minify.dart';

const String _page = '''
<!DOCTYPE html>
<html lang="{{lang}}">
<head>
  <title>{{pageTitle}}</title>
  <style>
    /* tokens */
    :root {
      --primary: #22a9cb;
    }
    body {
      color: #ffffff;
      margin: 0;
    }
  </style>
</head>
<body>
  <p>Hello <b>world</b></p>
  <script>
    // copy helper
    const target = document.getElementById('bearer');
    target.addEventListener('click', () => {
      navigator.clipboard.writeText(target.textContent);
    });
  </script>
</body>
</html>
''';

const String _expectedScript =
    "<script>const target=document.getElementById('bearer');target.addEventListener('click',()=>{navigator.clipboard.writeText(target.textContent);});</script>";

/// A page whose inline script carries regex literals with escaped slashes (the
/// PaperSock path-trimming pattern) alongside a real division, plus loose CSS.
const String _regexPage = r'''
<!DOCTYPE html>
<html>
<head><style>  .a { color : red ; }  </style></head>
<body>
  <script>
    (function () {
      var base = location.pathname.replace(/\/(claim|email)$/, '');
      var path = location.pathname.replace(/\/+$/, '');
      var n = a / b / c;
    })();
  </script>
</body>
</html>''';

void main() {
  group('minify', () {
    test('handles a whole page, inline style and script included', () {
      final result = minify(_page);

      expect(result, startsWith('<!DOCTYPE html><html lang="{{lang}}">'));
      expect(result, contains('<style>:root{--primary:#22a9cb}body{color:#fff;margin:0}</style>'));
      expect(result, contains(_expectedScript));
      expect(result, contains('<p>Hello <b>world</b></p>'));
      expect(result, isNot(contains('/* tokens */')));
      expect(result, isNot(contains('// copy helper')));
    });

    test('preserves regex literals with escaped slashes in inline scripts', () {
      // The PaperSock e-receipt pages trim a path with a `replace(/\/.../, '')`
      // regex. The minifier must copy the regex verbatim: dropping the leading
      // backslash would turn `//...` into a line comment and silently break the
      // script. It must also read `a / b / c` as division, not a regex.
      final result = minify(_regexPage);

      expect(result, contains(r"location.pathname.replace(/\/(claim|email)$/,'')"));
      expect(result, contains(r"location.pathname.replace(/\/+$/,'')"));
      expect(result, contains('var n=a/b/c'));
      expect(result, contains('.a{color:red}')); // CSS is still minified
    });

    test('matches minifyHtml on a page', () {
      expect(minify(_page), minifyHtml(_page));
    });

    test('minifies a standalone stylesheet', () {
      expect(minify('body {\n  color: red;\n}'), 'body{color:red}');
    });

    test('minifies a standalone script', () {
      expect(minify('const a = 1;\nconst b = a + 2;'), 'const a=1;const b=a+2;');
    });

    test('trusts the extension of a path over the content', () {
      expect(minify('body {\n  color: red;\n}', path: 'a/b/page.html'), 'body { color: red; }');
      expect(minify('const a = 1;', path: 'a/b/app.js'), 'const a=1;');
    });

    test('honours an explicit language', () {
      expect(minify('body {\n  color: red;\n}', language: MinifyLanguage.css), 'body{color:red}');
    });

    test('carries options through to the inline minifiers', () {
      const minifier = HtmlMinifier(minifyInlineJs: false);
      final result = minify('<script>\n  const a = 1;\n</script>', minifier: minifier);
      expect(result, '<script>\n  const a = 1;\n</script>');
    });
  });

  group('detectMinifyLanguage', () {
    test('reads the extension first', () {
      expect(detectMinifyLanguage('anything', path: 'assets/html/page.html'), MinifyLanguage.html);
      expect(detectMinifyLanguage('anything', path: 'assets/css/app.css'), MinifyLanguage.css);
      expect(detectMinifyLanguage('anything', path: 'assets/js/app.mjs'), MinifyLanguage.js);
    });

    test('recognises markup by its closing tags, doctype or comments', () {
      expect(detectMinifyLanguage('<p>a</p>'), MinifyLanguage.html);
      expect(detectMinifyLanguage('<!DOCTYPE html><html>'), MinifyLanguage.html);
      expect(detectMinifyLanguage('<!-- note --><br/>'), MinifyLanguage.html);
    });

    test('recognises a stylesheet by its rules', () {
      expect(detectMinifyLanguage('.a { color: red }'), MinifyLanguage.css);
      expect(detectMinifyLanguage('@media print { .a { color: red } }'), MinifyLanguage.css);
    });

    test('does not read a JavaScript object literal as a stylesheet', () {
      expect(detectMinifyLanguage('const a = { b: 1 };'), MinifyLanguage.js);
    });

    test('falls back to html for a text fragment', () {
      expect(detectMinifyLanguage('{{itemName}}'), MinifyLanguage.html);
    });
  });
}
