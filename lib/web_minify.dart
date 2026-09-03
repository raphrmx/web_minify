/// HTML, CSS and JavaScript minifiers written in pure Dart, with no external
/// dependencies.
///
/// Each minifier scans its input one code unit at a time rather than running
/// regular expressions over it, so string literals, `url()` values, template
/// literals, regular expressions and `<pre>` bodies are copied verbatim. Only
/// the bytes that carry no meaning are removed, which makes the output safe to
/// serve without a rendering diff.
///
/// [minify] is the one entry point that covers a whole file whatever it holds:
/// it works out the language and, for an HTML page, carries the inline
/// `<style>` and `<script>` bodies through the stylesheet and script minifiers
/// on the way. [minifyHtml], [minifyCss] and [minifyJs] name a language
/// outright, and [HtmlMinifier], [CssMinifier] and [JsMinifier] expose the
/// options.
///
/// ### Example:
/// ```dart
/// import 'package:web_minify/web_minify.dart';
///
/// final page = minify(File('assets/html/page.html').readAsStringSync());
/// ```
library;

import 'package:web_minify/src/css_minifier.dart';
import 'package:web_minify/src/html_minifier.dart';
import 'package:web_minify/src/js_minifier.dart';
import 'package:web_minify/src/language.dart';

export 'src/css_minifier.dart';
export 'src/html_minifier.dart';
export 'src/js_minifier.dart';
export 'src/language.dart';

/// Shared [HtmlMinifier] carrying the default options.
const HtmlMinifier htmlMinifier = HtmlMinifier();

/// Shared [CssMinifier] carrying the default options.
const CssMinifier cssMinifier = CssMinifier();

/// Shared [JsMinifier] carrying the default options.
const JsMinifier jsMinifier = JsMinifier();

/// Minifies [source] whatever language it is written in.
///
/// An HTML page goes through in one piece: the markup is minified, and every
/// inline `<style>` and `<script>` body is handed to the stylesheet and script
/// minifiers before being written back in place. A standalone stylesheet or
/// script is minified directly.
///
/// The language is taken from [language] when given, then from the extension
/// of [path], then from the content itself. See [detectMinifyLanguage] for the
/// order the content is read in.
///
/// [minifier] carries the options for all three languages: its
/// [HtmlMinifier.cssMinifier] and [HtmlMinifier.jsMinifier] are the ones used
/// for a standalone stylesheet or script, and for the inline bodies of a page.
///
/// ---
///
/// ### Parameters:
/// - [source]: the file content to minify.
/// - [path]: an optional file name or path, whose extension names the language.
/// - [language]: an explicit language, bypassing detection.
/// - [minifier]: the options to apply, defaulting to [htmlMinifier].
///
/// ### Returns:
/// The minified content.
///
/// ### Example:
/// ```dart
/// // One page holding markup, a <style> block and a <script> block.
/// final page = minify(File('assets/html/page.html').readAsStringSync());
///
/// // A standalone asset, named by its path.
/// final sheet = minify(source, path: 'assets/css/app.css');
/// ```
String minify(String source, {String? path, MinifyLanguage? language, HtmlMinifier minifier = htmlMinifier}) {
  final resolved = language ?? detectMinifyLanguage(source, path: path);
  return switch (resolved) {
    MinifyLanguage.html => minifier.minify(source),
    MinifyLanguage.css => minifier.cssMinifier.minify(source),
    MinifyLanguage.js => minifier.jsMinifier.minify(source),
  };
}

/// Minifies an HTML document or fragment, inline `<style>` and `<script>`
/// bodies included.
///
/// ---
///
/// ### Parameters:
/// - [html]: the markup source.
///
/// ### Returns:
/// The minified markup.
///
/// ### Example:
/// ```dart
/// minifyHtml('<div>\n  <p>Hello</p>\n</div>'); // <div><p>Hello</p></div>
/// ```
String minifyHtml(String html) => htmlMinifier.minify(html);

/// Minifies a stylesheet.
///
/// ---
///
/// ### Parameters:
/// - [css]: the stylesheet source.
///
/// ### Returns:
/// The minified stylesheet.
///
/// ### Example:
/// ```dart
/// minifyCss('body {\n  color: #ffffff;\n}'); // body{color:#fff}
/// ```
String minifyCss(String css) => cssMinifier.minify(css);

/// Minifies a script, keeping identifier names and automatic semicolon
/// insertion intact.
///
/// ---
///
/// ### Parameters:
/// - [js]: the script source.
///
/// ### Returns:
/// The minified script.
///
/// ### Example:
/// ```dart
/// minifyJs('const a = 1;\n// note\nconst b = a + 2;'); // const a=1;const b=a+2;
/// ```
String minifyJs(String js) => jsMinifier.minify(js);
