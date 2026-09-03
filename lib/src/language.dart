/// A language this package can minify.
enum MinifyLanguage {
  /// A full HTML page or a fragment, inline `<style>` and `<script>` bodies
  /// included.
  html,

  /// A standalone stylesheet.
  css,

  /// A standalone script.
  js,
}

/// File extensions that name each language.
const Map<String, MinifyLanguage> _extensions = {
  'html': MinifyLanguage.html,
  'htm': MinifyLanguage.html,
  'xhtml': MinifyLanguage.html,
  'css': MinifyLanguage.css,
  'js': MinifyLanguage.js,
  'mjs': MinifyLanguage.js,
  'cjs': MinifyLanguage.js,
};

/// A closing tag, a doctype or a comment: markup that neither CSS nor
/// JavaScript produces outside a string.
final RegExp _markupSignal = RegExp(r'</[a-zA-Z]|<!--|<!doctype\b', caseSensitive: false);

/// A selector or at-rule followed by a declaration. The selector may not hold
/// `=`, which is what keeps a JavaScript object literal out.
final RegExp _stylesheetSignal = RegExp(
  r'^\s*(@(charset|import|media|font-face|supports|keyframes|namespace|page)\b|[^{}<>;=]+\{[^{}]*:)',
  caseSensitive: false,
);

/// Statement forms that only JavaScript has.
final RegExp _scriptSignal = RegExp(
  r'(^|[^\w$])(function|const|let|var|return|class|import|export|async|await|=>)([^\w$]|$)',
);

/// Works out which language [source] is written in.
///
/// [path] wins when its extension names a language, since a file name is the
/// only unambiguous signal. Otherwise the content decides, in this order:
/// markup (a closing tag, a comment or a doctype), then a stylesheet rule,
/// then a JavaScript statement. Anything else falls back to
/// [MinifyLanguage.html], which is the safe answer for a template fragment
/// that holds nothing but text and placeholders.
///
/// ---
///
/// ### Parameters:
/// - [source]: the content to classify.
/// - [path]: an optional file name or path whose extension is trusted first.
///
/// ### Returns:
/// The detected [MinifyLanguage].
///
/// ### Example:
/// ```dart
/// detectMinifyLanguage('body{color:red}');            // MinifyLanguage.css
/// detectMinifyLanguage('x', path: 'a/b/script.js');   // MinifyLanguage.js
/// ```
MinifyLanguage detectMinifyLanguage(String source, {String? path}) {
  final fromPath = _languageFromPath(path);
  if (fromPath != null) return fromPath;

  if (_markupSignal.hasMatch(source)) return MinifyLanguage.html;
  if (_stylesheetSignal.hasMatch(source)) return MinifyLanguage.css;
  if (_scriptSignal.hasMatch(source)) return MinifyLanguage.js;
  return MinifyLanguage.html;
}

MinifyLanguage? _languageFromPath(String? path) {
  if (path == null) return null;
  final name = path.toLowerCase();
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return _extensions[name.substring(dot + 1)];
}
