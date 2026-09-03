// The example writes its output to the console.
// ignore_for_file: avoid_print

import 'package:web_minify/web_minify.dart';

const String _page = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Invoice</title>
  <style>
    /* design tokens */
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
    // copy the reference to the clipboard
    const target = document.getElementById('reference');
    target.addEventListener('click', () => {
      navigator.clipboard.writeText(target.textContent);
    });
  </script>
</body>
</html>
''';

/// Minifies a whole page, then each language on its own.
void main() {
  // One call for the page: markup, inline <style> and inline <script>.
  final page = minify(_page);
  print(page);
  print('${_page.length} -> ${page.length} bytes');

  // Naming the language directly, when the source is a standalone asset.
  print(minifyCss('body {\n  color: #ffffff;\n}')); // body{color:#fff}
  print(minifyJs('const a = 1;\n// note\nf(a);')); // const a=1;f(a);

  // Or letting a path decide.
  print(minify('body { color: red }', path: 'assets/css/app.css'));

  // Options travel through `minify` on a single object.
  const minifier = HtmlMinifier(minifyInlineJs: false);
  print(minify('<script>\n  const a = 1;\n</script>', minifier: minifier));
}
