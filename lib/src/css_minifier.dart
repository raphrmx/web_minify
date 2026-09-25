import 'package:web_minify/src/characters.dart';

/// Minifies CSS source by removing everything that only exists for
/// readability: comments, indentation, redundant whitespace around structural
/// characters and the trailing semicolon of a declaration block.
///
/// The source is scanned one code unit at a time, so string literals and
/// `url()` values are copied verbatim and never rewritten. Whitespace is only
/// dropped where CSS gives it no meaning, which keeps descendant selectors
/// (`.a .b`), `calc()` arithmetic and `@media` preludes intact.
///
/// ---
///
/// ### Parameters:
/// - [removeComments]: drop `/* ... */` blocks.
/// - [preserveBangComments]: keep `/*! ... */` blocks even when
///   [removeComments] is set, the usual convention for licence headers.
/// - [shortenHexColors]: rewrite `#aabbcc` as `#abc` inside declarations.
///
/// ### Example:
/// ```dart
/// const CssMinifier().minify('body {\n  color: #ffffff;\n}');
/// // body{color:#fff}
/// ```
class CssMinifier {
  /// Creates a minifier. Every option is on unless it is turned off here.
  const CssMinifier({this.removeComments = true, this.preserveBangComments = true, this.shortenHexColors = true});

  /// Whether `/* ... */` blocks are dropped.
  final bool removeComments;

  /// Whether `/*! ... */` blocks survive [removeComments], the usual
  /// convention for licence headers.
  final bool preserveBangComments;

  /// Whether `#aabbcc` is rewritten as `#abc` inside declarations.
  final bool shortenHexColors;

  /// Minifies [css].
  ///
  /// ---
  ///
  /// ### Parameters:
  /// - [css]: the stylesheet source.
  ///
  /// ### Returns:
  /// The minified stylesheet. A whitespace-only input returns an empty string.
  String minify(String css) => _CssScanner(this, css).run();
}

/// Single-pass scanner backing [CssMinifier.minify].
class _CssScanner {
  _CssScanner(this._options, this._source);

  final CssMinifier _options;
  final String _source;
  final StringBuffer _out = StringBuffer();

  /// Stack of open blocks. `true` marks a block opened by an at-rule prelude
  /// (`@media`, `@supports`), whose body holds selectors rather than
  /// declarations.
  final List<bool> _blocks = [];

  int _i = 0;
  int _last = -1;
  int _parenDepth = 0;
  bool _pendingSpace = false;
  bool _atPreludeStart = true;
  bool _preludeIsAtRule = false;

  bool get _inDeclarationBlock => _blocks.isNotEmpty && !_blocks.last;

  String run() {
    while (_i < _source.length) {
      final c = _source.codeUnitAt(_i);

      if (isWhitespace(c)) {
        _skipWhitespace();
      } else if (c == kSlash && _peek(1) == kStar) {
        _readComment();
      } else if (c == kDoubleQuote || c == kSingleQuote) {
        _copyString(c);
      } else if (c == kSemicolon) {
        _readSemicolon();
      } else if (c == kHash && _options.shortenHexColors && _tryShortenHex()) {
        continue;
      } else if (_matchesUrlCall()) {
        _copyUrlCall();
      } else {
        _emit(c);
        _i++;
      }
    }
    return _out.toString();
  }

  int _peek(int offset) {
    final index = _i + offset;
    return index < _source.length ? _source.codeUnitAt(index) : -1;
  }

  void _skipWhitespace() {
    while (_i < _source.length && isWhitespace(_source.codeUnitAt(_i))) {
      _i++;
    }
    if (_last >= 0) _pendingSpace = true;
  }

  void _readComment() {
    final end = _source.indexOf('*/', _i + 2);
    final stop = end < 0 ? _source.length : end + 2;
    final isBang = _peek(2) == kExclamation;

    if (!_options.removeComments || (isBang && _options.preserveBangComments)) {
      _flushSpace(kSlash);
      _out.write(_source.substring(_i, stop));
      _last = kSlash;
    } else if (_last >= 0) {
      // A comment separates two tokens the way a space does, so `a/**/b` must
      // not collapse into `ab`.
      _pendingSpace = true;
    }
    _i = stop;
  }

  void _copyString(int quote) {
    _flushSpace(quote);
    final start = _i;
    _i++;
    while (_i < _source.length) {
      final c = _source.codeUnitAt(_i);
      if (c == kBackslash) {
        _i += 2;
        continue;
      }
      _i++;
      if (c == quote) break;
    }
    _out.write(_source.substring(start, _i));
    _last = quote;
  }

  void _readSemicolon() {
    final next = _nextSignificant(_i + 1);
    final redundant = _last < 0 || _last == kOpenBrace || _last == kSemicolon || next == kCloseBrace;
    if (!redundant) _emit(kSemicolon);
    _i++;
  }

  /// Whether the scanner sits on a `url(` function call.
  bool _matchesUrlCall() {
    if (_i + 4 > _source.length) return false;
    if (_last >= 0 && isWordChar(_last)) return false;
    return _source.substring(_i, _i + 4).toLowerCase() == 'url(';
  }

  /// Copies `url(` and its unquoted payload verbatim: the value may hold
  /// characters that the whitespace rules would otherwise touch.
  void _copyUrlCall() {
    _flushSpace(_source.codeUnitAt(_i));
    _out.write(_source.substring(_i, _i + 4));
    _last = kOpenParen;
    _parenDepth++;
    _i += 4;

    while (_i < _source.length && isWhitespace(_source.codeUnitAt(_i))) {
      _i++;
    }
    if (_i >= _source.length) return;

    final c = _source.codeUnitAt(_i);
    if (c == kDoubleQuote || c == kSingleQuote) {
      _copyString(c);
      return;
    }
    final start = _i;
    while (_i < _source.length && _source.codeUnitAt(_i) != kCloseParen) {
      _i += _source.codeUnitAt(_i) == kBackslash ? 2 : 1;
    }
    final value = _source.substring(start, _i).trimRight();
    _out.write(value);
    if (value.isNotEmpty) _last = value.codeUnitAt(value.length - 1);
  }

  /// Rewrites `#aabbcc` as `#abc` when the six digits form three identical
  /// pairs. Restricted to declaration blocks, so id selectors that happen to
  /// look like colours are left alone.
  ///
  /// ---
  ///
  /// ### Returns:
  /// `true` when the shorthand was written and the cursor advanced.
  bool _tryShortenHex() {
    if (!_inDeclarationBlock) return false;

    final start = _i + 1;
    var end = start;
    while (end < _source.length && isHexDigit(_source.codeUnitAt(end))) {
      end++;
    }
    if (end - start != 6) return false;
    if (end < _source.length && isWordChar(_source.codeUnitAt(end))) return false;

    final hex = _source.substring(start, end);
    if (hex[0] != hex[1] || hex[2] != hex[3] || hex[4] != hex[5]) return false;

    _emit(kHash);
    _out.write('${hex[0]}${hex[2]}${hex[4]}');
    _last = hex.codeUnitAt(4);
    _i = end;
    return true;
  }

  /// Returns the next code unit that is neither whitespace nor part of a
  /// comment, or `-1` at end of input.
  int _nextSignificant(int from) {
    var index = from;
    while (index < _source.length) {
      final c = _source.codeUnitAt(index);
      if (isWhitespace(c)) {
        index++;
      } else if (c == kSlash && index + 1 < _source.length && _source.codeUnitAt(index + 1) == kStar) {
        final end = _source.indexOf('*/', index + 2);
        if (end < 0) return -1;
        index = end + 2;
      } else {
        return c;
      }
    }
    return -1;
  }

  void _flushSpace(int next) {
    if (!_pendingSpace) return;
    _pendingSpace = false;
    if (_last >= 0 && !_dropSpaceAfter(_last) && !_dropSpaceBefore(next)) {
      _out.writeCharCode(kSpace);
    }
  }

  void _emit(int c) {
    _flushSpace(c);

    if (c == kOpenBrace) {
      _blocks.add(_preludeIsAtRule);
    } else if (c == kCloseBrace && _blocks.isNotEmpty) {
      _blocks.removeLast();
    } else if (c == kOpenParen) {
      _parenDepth++;
    } else if (c == kCloseParen && _parenDepth > 0) {
      _parenDepth--;
    }

    if (c == kAt && _atPreludeStart) _preludeIsAtRule = true;
    if (c == kOpenBrace || c == kCloseBrace || c == kSemicolon) {
      _atPreludeStart = true;
      _preludeIsAtRule = false;
    } else {
      _atPreludeStart = false;
    }

    _out.writeCharCode(c);
    _last = c;
  }

  /// Whether the whitespace that follows [c] can go.
  ///
  /// The answer depends on where the scanner stands: a colon separates a
  /// property from its value inside a declaration but builds a pseudo-class in
  /// a selector, and `+` is a sibling combinator in a selector but an operator
  /// inside `calc()`.
  bool _dropSpaceAfter(int c) {
    switch (c) {
      case kOpenBrace:
      case kCloseBrace:
      case kSemicolon:
      case kComma:
      case kOpenParen:
        return true;
      // `:not(.a) .b` and `rgba(0,0,0,.1) solid` both need what follows `)`.
      case kCloseParen:
        return false;
      default:
        return _dropsSpaceOnBothSides(c);
    }
  }

  /// Whether the whitespace that precedes [c] can go.
  bool _dropSpaceBefore(int c) {
    switch (c) {
      case kOpenBrace:
      case kCloseBrace:
      case kSemicolon:
      case kComma:
      case kCloseParen:
        return true;
      // `@media screen and (min-width:700px)` turns `and(` into a function.
      case kOpenParen:
        return false;
      default:
        return _dropsSpaceOnBothSides(c);
    }
  }

  /// Characters that need no padding on either side, once the scanner knows
  /// whether it reads a selector, a declaration or a parenthesised value.
  bool _dropsSpaceOnBothSides(int c) {
    switch (c) {
      case kColon:
        return _inDeclarationBlock || _parenDepth > 0;
      case kExclamation:
        return _inDeclarationBlock;
      case kGreaterThan:
      case kTilde:
      case kPlus:
        return !_inDeclarationBlock && _parenDepth == 0;
      default:
        return false;
    }
  }
}
