import 'package:web_minify/src/characters.dart';
import 'package:web_minify/src/css_minifier.dart';
import 'package:web_minify/src/js_minifier.dart';

/// Elements that start a new line box, and between which whitespace carries no
/// meaning. Any element outside this set is treated as inline, so the space
/// separating it from its neighbour survives.
const Set<String> _blockTags = {
  'address',
  'article',
  'aside',
  'base',
  'blockquote',
  'body',
  'caption',
  'col',
  'colgroup',
  'dd',
  'details',
  'dialog',
  'div',
  'dl',
  'dt',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'head',
  'header',
  'hgroup',
  'hr',
  'html',
  'legend',
  'li',
  'link',
  'main',
  'menu',
  'meta',
  'nav',
  'noscript',
  'ol',
  'optgroup',
  'option',
  'p',
  'pre',
  'script',
  'section',
  'source',
  'style',
  'summary',
  'table',
  'tbody',
  'td',
  'tfoot',
  'th',
  'thead',
  'title',
  'tr',
  'track',
  'ul',
};

/// Elements whose text content is raw and must reach the browser byte for
/// byte.
const Set<String> _verbatimTags = {'pre', 'textarea'};

/// `type` values under which a `<script>` body holds JavaScript.
const Set<String> _javascriptTypes = {
  '',
  'application/ecmascript',
  'application/javascript',
  'module',
  'text/ecmascript',
  'text/javascript',
};

/// `type` values under which a `<style>` body holds CSS.
const Set<String> _cssTypes = {'', 'text/css'};

/// Stands in for a doctype or any other `<!...>` declaration when tracking the
/// previous token, since those act as block-level boundaries for whitespace.
const String _declarationBoundary = '!';

/// Minifies an HTML document or fragment: comments go, indentation goes, and
/// the inline `<style>` and `<script>` bodies are handed to [CssMinifier] and
/// [JsMinifier].
///
/// Whitespace is only dropped where HTML gives it no meaning. Between two
/// block-level elements it disappears; anywhere an inline element sits on
/// either side, the single space that separates two words survives. `<pre>`
/// and `<textarea>` bodies are copied byte for byte.
///
/// Minifying a template before its placeholders are substituted is the
/// intended use: the values injected afterwards then reach the response
/// untouched.
///
/// ---
///
/// ### Parameters:
/// - [removeComments]: drop `<!-- ... -->` blocks.
/// - [preserveConditionalComments]: keep `<!--[if ...]>` blocks even when
///   [removeComments] is set, since browsers read them as markup.
/// - [collapseWhitespace]: reduce every whitespace run in text to one space.
/// - [trimInterTagWhitespace]: remove whitespace-only text between two
///   block-level elements.
/// - [minifyInlineCss]: run [cssMinifier] over `<style>` bodies.
/// - [minifyInlineJs]: run [jsMinifier] over `<script>` bodies.
/// - [cssMinifier]: the stylesheet minifier used for inline styles.
/// - [jsMinifier]: the script minifier used for inline scripts.
///
/// ### Example:
/// ```dart
/// const HtmlMinifier().minify('<div>\n  <p>Hello</p>\n</div>');
/// // <div><p>Hello</p></div>
/// ```
class HtmlMinifier {
  const HtmlMinifier({
    this.removeComments = true,
    this.preserveConditionalComments = true,
    this.collapseWhitespace = true,
    this.trimInterTagWhitespace = true,
    this.minifyInlineCss = true,
    this.minifyInlineJs = true,
    this.cssMinifier = const CssMinifier(),
    this.jsMinifier = const JsMinifier(),
  });

  /// Whether `<!-- ... -->` blocks are dropped.
  final bool removeComments;

  /// Whether `<!--[if ...]>` blocks survive [removeComments], since browsers
  /// read them as markup rather than as a comment.
  final bool preserveConditionalComments;

  /// Whether every whitespace run in text collapses to a single space.
  final bool collapseWhitespace;

  /// Whether whitespace-only text between two block-level elements is removed
  /// outright rather than collapsed to a space.
  final bool trimInterTagWhitespace;

  /// Whether `<style>` bodies go through [cssMinifier].
  final bool minifyInlineCss;

  /// Whether `<script>` bodies go through [jsMinifier].
  final bool minifyInlineJs;

  /// The stylesheet minifier applied to inline `<style>` bodies.
  final CssMinifier cssMinifier;

  /// The script minifier applied to inline `<script>` bodies.
  final JsMinifier jsMinifier;

  /// Minifies [html].
  ///
  /// ---
  ///
  /// ### Parameters:
  /// - [html]: the document or fragment source.
  ///
  /// ### Returns:
  /// The minified markup.
  String minify(String html) => _HtmlScanner(this, html).run();
}

/// Single-pass scanner backing [HtmlMinifier.minify].
class _HtmlScanner {
  _HtmlScanner(this._options, this._source) : _lowerSource = _source.toLowerCase();

  final HtmlMinifier _options;
  final String _source;

  /// Lowercase mirror of [_source], so that closing tags can be located
  /// case-insensitively without lowering the document on every lookup.
  final String _lowerSource;

  final StringBuffer _out = StringBuffer();

  int _i = 0;

  /// Name of the element whose tag was written last, or `null` when the last
  /// thing written was text or a preserved comment.
  String? _previousTag;

  /// Set while a whitespace-only text run waits to be resolved. Holding it
  /// back is what lets a removed comment vanish without leaving the two gaps
  /// that surrounded it behind.
  bool _pendingGap = false;

  String run() {
    while (_i < _source.length) {
      if (_startsWith('<!--')) {
        _readComment();
      } else if (_startsWith('<!')) {
        _readDeclaration();
      } else if (_peekTagName(_i) != null) {
        _readTag();
      } else {
        _readText();
      }
    }
    _flushGap(null);
    return _out.toString();
  }

  int _at(int index) => index >= 0 && index < _source.length ? _source.codeUnitAt(index) : -1;

  bool _startsWith(String prefix, [int? from]) => _source.startsWith(prefix, from ?? _i);

  void _readComment() {
    final end = _source.indexOf('-->', _i + 4);
    final stop = end < 0 ? _source.length : end + 3;
    final isConditional = _startsWith('<!--[if', _i);

    if (!_options.removeComments || (isConditional && _options.preserveConditionalComments)) {
      _flushGap(null);
      _out.write(_source.substring(_i, stop));
      _previousTag = null;
    }
    _i = stop;
  }

  /// Copies a doctype or any other `<!...>` declaration unchanged, with its
  /// internal whitespace collapsed.
  void _readDeclaration() {
    final end = _source.indexOf('>', _i);
    final stop = end < 0 ? _source.length : end + 1;
    _flushGap(_declarationBoundary);
    _out.write(_collapse(_source.substring(_i, stop)));
    _previousTag = _declarationBoundary;
    _i = stop;
  }

  void _readTag() {
    final closing = _at(_i + 1) == kSlash;
    final name = _peekTagName(_i)!;

    _i += closing ? 2 : 1;
    _i += name.length;

    final tag = StringBuffer()
      ..write(closing ? '</' : '<')
      ..write(name);
    final selfClosing = _writeAttributes(tag);
    final tagText = tag.toString();

    _flushGap(name);
    _out.write(tagText);
    _previousTag = name;

    if (closing || selfClosing) return;

    if (_verbatimTags.contains(name)) {
      _out.write(_readRawBody(name));
    } else if (name == 'style') {
      _out.write(_minifiedStyleBody(tagText));
    } else if (name == 'script') {
      _out.write(_minifiedScriptBody(tagText));
    }
  }

  /// Copies the attribute list into [tag], normalising the whitespace between
  /// attributes and around `=` while leaving every value untouched.
  ///
  /// ---
  ///
  /// ### Returns:
  /// `true` when the tag closed with `/>`.
  bool _writeAttributes(StringBuffer tag) {
    // Set when the whitespace that separates a VALUELESS attribute (`required`)
    // from the next one was consumed while peeking for `=`: it still has to be
    // written, otherwise `required placeholder` collapses to `requiredplaceholder`.
    var pendingSpace = false;
    while (_i < _source.length) {
      final hadSpace = _skipWhitespace();
      final c = _at(_i);

      if (c == kGreaterThan) {
        tag.write('>');
        _i++;
        return false;
      }
      if (c == kSlash && _at(_i + 1) == kGreaterThan) {
        tag.write('/>');
        _i += 2;
        return true;
      }
      if (c < 0) return false;

      if (hadSpace || pendingSpace) tag.write(' ');
      pendingSpace = false;
      tag.write(_readAttributeName());
      final spaceAfterName = _skipWhitespace();
      if (_at(_i) != kEquals) {
        // Valueless attribute: keep the separator we just skipped for the next
        // attribute (the `>` / `/>` cases above end the tag with no trailing
        // space, so this only matters when another attribute follows).
        pendingSpace = spaceAfterName;
        continue;
      }

      tag.write('=');
      _i++;
      _skipWhitespace();
      tag.write(_readAttributeValue());
    }
    return false;
  }

  String _readAttributeName() {
    final start = _i;
    while (_i < _source.length) {
      final c = _at(_i);
      if (isWhitespace(c) || c == kEquals || c == kGreaterThan) break;
      if (c == kSlash && _at(_i + 1) == kGreaterThan) break;
      _i++;
    }
    // A lone `/` inside the attribute list belongs to the tag, not to a name.
    if (_i == start) _i++;
    return _source.substring(start, _i);
  }

  String _readAttributeValue() {
    final quote = _at(_i);
    final start = _i;

    if (quote == kDoubleQuote || quote == kSingleQuote) {
      _i++;
      while (_i < _source.length && _at(_i) != quote) {
        _i++;
      }
      if (_i < _source.length) _i++;
      return _source.substring(start, _i);
    }

    while (_i < _source.length) {
      final c = _at(_i);
      if (isWhitespace(c) || c == kGreaterThan) break;
      _i++;
    }
    return _source.substring(start, _i);
  }

  /// Reads the raw body of [name] plus its closing tag, leaving both unchanged.
  String _readRawBody(String name) {
    final end = _indexOfClosingTag(name);
    final body = _source.substring(_i, end);
    _i = end;
    return body + _readClosingTag(name);
  }

  String _minifiedStyleBody(String tagText) {
    final end = _indexOfClosingTag('style');
    final body = _source.substring(_i, end);
    _i = end;

    final type = _attributeValue(tagText, 'type')?.toLowerCase() ?? '';
    final minify = _options.minifyInlineCss && _cssTypes.contains(type);
    return (minify ? _options.cssMinifier.minify(body) : body) + _readClosingTag('style');
  }

  String _minifiedScriptBody(String tagText) {
    final end = _indexOfClosingTag('script');
    final body = _source.substring(_i, end);
    _i = end;

    final type = _attributeValue(tagText, 'type')?.toLowerCase() ?? '';
    final minify = _options.minifyInlineJs && _javascriptTypes.contains(type);
    return (minify ? _options.jsMinifier.minify(body) : body) + _readClosingTag('script');
  }

  /// Index of the `</name` that closes the element, or the end of the source
  /// when the document is truncated.
  int _indexOfClosingTag(String name) {
    final index = _lowerSource.indexOf('</$name', _i);
    return index < 0 ? _source.length : index;
  }

  /// Consumes the `</name ... >` sitting at the cursor and returns it
  /// normalised.
  String _readClosingTag(String name) {
    if (!_startsWith('</')) return '';
    final end = _source.indexOf('>', _i);
    _i = end < 0 ? _source.length : end + 1;
    _previousTag = name;
    return '</$name>';
  }

  void _readText() {
    final start = _i;
    _i++;
    while (_i < _source.length) {
      if (_at(_i) == kLessThan && (_startsWith('<!') || _peekTagName(_i) != null)) break;
      _i++;
    }

    final text = _source.substring(start, _i);
    if (!_options.collapseWhitespace) {
      _flushGap(null);
      _out.write(text);
      _previousTag = null;
      return;
    }
    if (text.trim().isEmpty) {
      // A whitespace-only run keeps `_previousTag`: the decision that resolves
      // it needs the element sitting before the gap, not the gap itself.
      _pendingGap = true;
      return;
    }
    _flushGap(null);
    _out.write(_collapse(text));
    _previousTag = null;
  }

  /// Resolves a held-back whitespace run now that the token following it is
  /// known: it collapses to a single space, or to nothing when block-level
  /// markup stands on both sides.
  ///
  /// ---
  ///
  /// ### Parameters:
  /// - [next]: name of the element about to be written, [_declarationBoundary]
  ///   for a doctype, or `null` for text, a preserved comment or end of input.
  void _flushGap(String? next) {
    if (!_pendingGap) return;
    _pendingGap = false;

    if (!_options.trimInterTagWhitespace) {
      if (_out.isNotEmpty) _out.write(' ');
      return;
    }

    final previous = _previousTag;
    final previousIsBlock =
        previous == null ? _out.isEmpty : previous == _declarationBoundary || _blockTags.contains(previous);
    final nextIsBlock = next == null ? _i >= _source.length : _isBlockBoundary(next);

    if (!(previousIsBlock && nextIsBlock)) _out.write(' ');
  }

  bool _isBlockBoundary(String name) => name == _declarationBoundary || _blockTags.contains(name);

  /// Lowercase name of the tag starting at [index], or `null` when [index]
  /// does not open one.
  String? _peekTagName(int index) {
    if (_at(index) != kLessThan) return null;
    var cursor = index + 1;
    if (_at(cursor) == kSlash) cursor++;
    if (!isLetter(_at(cursor))) return null;

    final start = cursor;
    while (cursor < _source.length) {
      final c = _at(cursor);
      if (!isLetter(c) && !isDigit(c) && c != kMinus && c != kColon) break;
      cursor++;
    }
    return _source.substring(start, cursor).toLowerCase();
  }

  /// Reads the value of [attribute] out of an already normalised [tagText].
  String? _attributeValue(String tagText, String attribute) {
    final match = RegExp(
      '\\s$attribute\\s*=\\s*("([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
      caseSensitive: false,
    ).firstMatch(tagText);
    if (match == null) return null;
    return match.group(2) ?? match.group(3) ?? match.group(4);
  }

  /// Consumes a whitespace run and reports whether one was there.
  bool _skipWhitespace() {
    final start = _i;
    while (_i < _source.length && isWhitespace(_at(_i))) {
      _i++;
    }
    return _i > start;
  }

  String _collapse(String text) => text.replaceAll(RegExp(r'\s+'), ' ');
}
