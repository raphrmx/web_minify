<a alt="ComApps Logo" href="https://comapps.be" target="_blank" rel="noreferrer"><img src="https://www.comapps.be/wp-content/uploads/2026/09/CompleteLogoHorizontalMini.png" style="margin: 15px"></a>

# Web Minify (HTML, CSS, JS)

HTML, CSS and JavaScript minifiers written in pure Dart. One call minifies a whole page, inline
`<style>` and `<script>` blocks included. No external dependencies, no build step, no Node toolchain.

[![Pub Version](https://img.shields.io/pub/v/web_minify?color=blue)](https://pub.dev/packages/web_minify)
![Maintainer](https://img.shields.io/badge/Maintainer-Raphael-purple)
[![License](https://img.shields.io/badge/Licence-MIT-blue)](/LICENSE)
![Maintenance](https://img.shields.io/badge/Maintained-yes-success)
![Null Safety](https://img.shields.io/badge/Null_Safety-passing-success)
![Platforms](https://img.shields.io/badge/Platforms-Android,_iOS,_macOS,_Windows,_Linux,_Web-22375C.svg)

## Install

```sh
dart pub add web_minify      # Dart
flutter pub add web_minify   # Flutter
```

Requires Dart 3.0 or later. No runtime dependencies, so it runs everywhere Dart does, WASM included.

## Usage

```dart
import 'package:web_minify/web_minify.dart';

// One call for a whole file, whatever it holds.
final page = minify(File('assets/html/page.html').readAsStringSync());
```

Given a page, `minify` minifies the markup and rewrites every inline block in place:

```html
<style>                              <!-- becomes -->    <style>:root{--primary:#22a9cb}</style>
  /* tokens */
  :root { --primary: #22a9cb; }
</style>

<script>                             <!-- becomes -->    <script>const a=1;f(a);</script>
  // copy helper
  const a = 1;
  f(a);
</script>
```

The language comes from the content, or from `path` when the extension names it, or from an explicit
`language`. Naming it directly works too:

```dart
final sheet = minify(source, path: 'assets/css/app.css');
final script = minify(source, language: MinifyLanguage.js);
final css = minifyCss('body {\n  color: #ffffff;\n}');      // body{color:#fff}
final js = minifyJs('const a = 1;\n// note\nf(a);');        // const a=1;f(a);
```

### What each minifier does

| Function | Removes |
| --- | --- |
| `minifyHtml` | Comments, indentation, whitespace between block elements, redundant whitespace inside tags. Hands `<style>` and `<script>` bodies to the two below. |
| `minifyCss` | Comments, whitespace around structural characters, the trailing `;` of a block. Shortens `#aabbcc` to `#abc`. |
| `minifyJs` | Comments, indentation, and line breaks only where a statement cannot end. Identifiers keep their names, so the output stays debuggable. |

Every minifier scans its input one code unit at a time instead of running regular expressions over
it. String literals, `url()` values, template literals, regular expressions, `<pre>` and `<textarea>`
bodies are copied byte for byte.

### Options

Options live on `HtmlMinifier`, which also carries the stylesheet and script minifiers used for the
inline blocks:

```dart
const minifier = HtmlMinifier(
  trimInterTagWhitespace: false, // keep one space between every pair of elements
  minifyInlineJs: false,         // leave <script> bodies alone
);
final page = minify(source, minifier: minifier);
```

### Serving a template

Minify the template **before** substituting its placeholders, and cache the result. The values
injected afterwards then reach the response untouched, and the file is read and minified once per
process rather than once per request.

```dart
final Map<String, String> _templateCache = {};

String loadHtmlTemplate(String path) =>
    _templateCache[path] ??= minify(File(path).readAsStringSync(), path: path);
```

### Command line

```sh
dart run web_minify assets/html/page.html --out build/assets/html
dart run web_minify assets/html/*.html --in-place
dart run web_minify --type css < input.css > output.css
```

## What it does not do

- No identifier mangling, no dead code elimination, no constant folding. This is a whitespace and
  comment minifier: the output is byte-smaller, never semantically rewritten.
- Expressions inside a JavaScript template literal are copied verbatim, indentation included.
- An element outside the block-level list is treated as inline, so the whitespace next to a custom
  element is kept rather than guessed away.

## Measured on a real template set

49 hand-indented HTML pages served by a Dart backend, `<style>` and `<script>` blocks inline:

| | raw | gzip |
| --- | --- | --- |
| before | 251 744 | 79 462 |
| after | 191 428 (-24%) | 71 201 (-10%) |

The largest page goes from 32 583 to 18 496 bytes raw, and from 6 900 to 4 963 gzipped. Every page
was checked to render with the same tag sequence, the same attributes and the same visible text as
its source.

## Dependencies

None.

## Tests

```sh
dart test
```

## License

MIT — see [LICENSE](LICENSE).
