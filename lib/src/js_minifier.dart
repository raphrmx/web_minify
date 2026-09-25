import 'package:web_minify/src/characters.dart';

/// Keywords after which a `/` opens a regular expression literal rather than a
/// division operator.
const Set<String> _regexPrecedingKeywords = {
  'await',
  'case',
  'delete',
  'do',
  'else',
  'in',
  'instanceof',
  'new',
  'of',
  'return',
  'throw',
  'typeof',
  'void',
  'yield',
};

/// Minifies JavaScript source by removing comments, indentation and the
/// whitespace that carries no meaning.
///
/// This is a whitespace and comment minifier, not a compressor: identifiers
/// keep their names and the code keeps its structure, so the output stays
/// readable in a browser debugger and stack traces still point at recognisable
/// symbols.
///
/// The scanner understands string literals, template literals, regular
/// expression literals and both comment forms, so none of their content is
/// ever rewritten. Line breaks are removed only where a statement cannot end,
/// which keeps automatic semicolon insertion behaving exactly as it does in
/// the source.
///
/// ---
///
/// ### Parameters:
/// - [removeComments]: drop `//` and `/* ... */` comments.
/// - [preserveBangComments]: keep `/*! ... */` blocks even when
///   [removeComments] is set, the usual convention for licence headers.
///
/// ### Example:
/// ```dart
/// const JsMinifier().minify('const a = 1;\n// note\nconst b = a + 2;');
/// // const a=1;const b=a+2;
/// ```
class JsMinifier {
  /// Creates a minifier. Every option is on unless it is turned off here.
  const JsMinifier({this.removeComments = true, this.preserveBangComments = true});

  /// Whether `//` and `/* ... */` comments are dropped.
  final bool removeComments;

  /// Whether `/*! ... */` blocks survive [removeComments], the usual
  /// convention for licence headers.
  final bool preserveBangComments;

  /// Minifies [js].
  ///
  /// ---
  ///
  /// ### Parameters:
  /// - [js]: the script source.
  ///
  /// ### Returns:
  /// The minified script. A whitespace-only input returns an empty string.
  String minify(String js) => _JsScanner(this, js).run();
}

/// Single-pass scanner backing [JsMinifier.minify].
class _JsScanner {
  _JsScanner(this._options, this._source);

  final JsMinifier _options;
  final String _source;
  final StringBuffer _out = StringBuffer();

  int _i = 0;
  int _last = -1;
  int _beforeLast = -1;
  String? _lastWord;
  bool _pendingSpace = false;
  bool _pendingNewline = false;
  bool _forcedNewline = false;

  String run() {
    while (_i < _source.length) {
      final c = _source.codeUnitAt(_i);

      if (isWhitespace(c)) {
        _skipWhitespace();
      } else if (c == kSlash && _peek(1) == kSlash) {
        _readLineComment();
      } else if (c == kSlash && _peek(1) == kStar) {
        _readBlockComment();
      } else if (c == kDoubleQuote || c == kSingleQuote) {
        _copyVerbatim(_scanString(_i, c), c);
      } else if (c == kBacktick) {
        _copyVerbatim(_scanTemplate(_i), kBacktick);
      } else if (c == kSlash && _regexAllowed()) {
        _copyVerbatim(_scanRegex(_i), kSlash);
      } else if (isWordChar(c)) {
        _copyWord();
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

  int _at(int index) => index < _source.length ? _source.codeUnitAt(index) : -1;

  void _skipWhitespace() {
    var sawNewline = false;
    while (_i < _source.length && isWhitespace(_source.codeUnitAt(_i))) {
      if (_source.codeUnitAt(_i) == kNewline) sawNewline = true;
      _i++;
    }
    if (_last < 0) return;
    if (sawNewline) {
      _pendingNewline = true;
    } else {
      _pendingSpace = true;
    }
  }

  void _readLineComment() {
    final start = _i;
    while (_i < _source.length && _source.codeUnitAt(_i) != kNewline) {
      _i++;
    }
    if (!_options.removeComments) {
      _flushPending(kSlash);
      _out.write(_source.substring(start, _i));
      _shiftLast(kSpace);
      _lastWord = null;
      // A preserved `//` comment swallows everything up to the line break, so
      // that break has to survive whatever the neighbouring tokens are.
      _forcedNewline = true;
      return;
    }
    if (_last >= 0) _pendingNewline = true;
  }

  void _readBlockComment() {
    final end = _source.indexOf('*/', _i + 2);
    final stop = end < 0 ? _source.length : end + 2;
    final body = _source.substring(_i, stop);
    final isBang = _peek(2) == kExclamation;

    if (!_options.removeComments || (isBang && _options.preserveBangComments)) {
      _flushPending(kSlash);
      _out.write(body);
      // A comment already separates the tokens around it, and it is not an
      // operator, so it must not be read as one when the next gap is weighed.
      _shiftLast(kSpace);
      _lastWord = null;
    } else if (_last >= 0) {
      // A comment separates two tokens the way whitespace does; a multi-line
      // one also stands in for the line break it spanned.
      if (body.contains('\n')) {
        _pendingNewline = true;
      } else {
        _pendingSpace = true;
      }
    }
    _i = stop;
  }

  /// Copies `_source[_i, end)` unchanged and records [last] as the trailing
  /// significant code unit.
  void _copyVerbatim(int end, int last) {
    _flushPending(_source.codeUnitAt(_i));
    _out.write(_source.substring(_i, end));
    _shiftLast(last);
    _lastWord = null;
    _i = end;
  }

  void _copyWord() {
    final start = _i;
    while (_i < _source.length && isWordChar(_source.codeUnitAt(_i))) {
      _i++;
    }
    final word = _source.substring(start, _i);
    _flushPending(word.codeUnitAt(0));
    _out.write(word);
    _shiftLast(word.codeUnitAt(word.length - 1));
    _lastWord = word;
  }

  void _emit(int c) {
    _flushPending(c);
    _out.writeCharCode(c);
    _shiftLast(c);
    _lastWord = null;
  }

  void _shiftLast(int c) {
    _beforeLast = _last;
    _last = c;
  }

  /// Writes the line break or space that the pending whitespace collapses to,
  /// if the two neighbouring tokens need one.
  void _flushPending(int next) {
    if (_forcedNewline) {
      _forcedNewline = false;
      _pendingNewline = false;
      _pendingSpace = false;
      _out.writeCharCode(kNewline);
      return;
    }
    if (_pendingNewline) {
      _pendingNewline = false;
      _pendingSpace = false;
      if (_newlineNeeded(next)) {
        _out.writeCharCode(kNewline);
      } else if (_spaceNeeded(next)) {
        _out.writeCharCode(kSpace);
      }
      return;
    }
    if (_pendingSpace) {
      _pendingSpace = false;
      if (_spaceNeeded(next)) _out.writeCharCode(kSpace);
    }
  }

  /// Whether a line break must survive between the last emitted code unit and
  /// [next].
  ///
  /// A break can go only where the statement cannot end there: after an
  /// operator or an opening delimiter, or before a closing one. Everywhere
  /// else the break is what automatic semicolon insertion relies on, so it
  /// stays.
  bool _newlineNeeded(int next) {
    if (_last < 0) return false;

    // `a++` and `a--` end a statement, unlike the `+` and `-` operators that
    // share their characters.
    final isIncrement = (_last == kPlus || _last == kMinus) && _beforeLast == _last;
    if (!isIncrement && _dropsNewlineAfter(_last)) return false;
    if (_dropsNewlineBefore(next)) return false;
    return true;
  }

  bool _dropsNewlineAfter(int c) {
    switch (c) {
      case kOpenBrace:
      case kSemicolon:
      case kComma:
      case kOpenParen:
      case kOpenBracket:
      case kEquals:
      case kPlus:
      case kMinus:
      case kStar:
      case kSlash:
      case kPercent:
      case kAmpersand:
      case kPipe:
      case kCaret:
      case kExclamation:
      case kTilde:
      case kQuestion:
      case kColon:
      case kLessThan:
      case kGreaterThan:
      case kDot:
        return true;
      default:
        return false;
    }
  }

  bool _dropsNewlineBefore(int c) {
    switch (c) {
      case kCloseParen:
      case kCloseBracket:
      case kCloseBrace:
      case kComma:
      case kSemicolon:
      case kDot:
      case kColon:
      case kEquals:
        return true;
      default:
        return false;
    }
  }

  /// Whether a single space must separate the last emitted code unit from
  /// [next] to keep them two distinct tokens.
  bool _spaceNeeded(int next) {
    if (_last < 0) return false;

    if (isWordChar(_last) && isWordChar(next)) return true;
    // `a + +b` and `a - -b` would otherwise turn into `a++b` and `a--b`.
    if (_last == next && (_last == kPlus || _last == kMinus)) return true;
    // Never let two operators fuse into a comment opener or an HTML comment.
    if (_last == kSlash && (next == kSlash || next == kStar)) return true;
    if (_last == kLessThan && next == kExclamation) return true;
    // `1 .toFixed()` reads the dot as a property access, `1.toFixed()` does not.
    if (isDigit(_last) && next == kDot) return true;
    return false;
  }

  /// Whether a `/` at the cursor opens a regular expression literal.
  ///
  /// Decided from the preceding token: an identifier, a literal or a closing
  /// `)` / `]` means division, anything else means a regular expression. The
  /// keyword list covers the cases where an identifier is still followed by a
  /// literal, such as `return /ab+c/`.
  bool _regexAllowed() {
    if (_last < 0) return true;
    final word = _lastWord;
    if (word != null) return _regexPrecedingKeywords.contains(word);
    return _last != kCloseParen && _last != kCloseBracket && !isWordChar(_last);
  }

  /// Returns the index just past the string literal that starts at [start].
  int _scanString(int start, int quote) {
    var index = start + 1;
    while (index < _source.length) {
      final c = _source.codeUnitAt(index);
      if (c == kBackslash) {
        index += 2;
        continue;
      }
      index++;
      if (c == quote) break;
    }
    return index;
  }

  /// Returns the index just past the template literal that starts at [start],
  /// following nested `${ ... }` substitutions and the literals inside them.
  int _scanTemplate(int start) {
    var index = start + 1;
    while (index < _source.length) {
      final c = _source.codeUnitAt(index);
      if (c == kBackslash) {
        index += 2;
        continue;
      }
      if (c == kBacktick) return index + 1;
      if (c == kDollar && _at(index + 1) == kOpenBrace) {
        index = _scanSubstitution(index + 2);
        continue;
      }
      index++;
    }
    return index;
  }

  /// Returns the index just past the `}` closing a `${` substitution that
  /// starts at [start].
  int _scanSubstitution(int start) {
    var index = start;
    var depth = 1;
    while (index < _source.length) {
      final c = _source.codeUnitAt(index);
      if (c == kDoubleQuote || c == kSingleQuote) {
        index = _scanString(index, c);
      } else if (c == kBacktick) {
        index = _scanTemplate(index);
      } else {
        if (c == kOpenBrace) {
          depth++;
        } else if (c == kCloseBrace) {
          depth--;
          if (depth == 0) return index + 1;
        }
        index++;
      }
    }
    return index;
  }

  /// Returns the index just past the regular expression literal that starts at
  /// [start], flags included.
  int _scanRegex(int start) {
    var index = start + 1;
    var inClass = false;
    while (index < _source.length) {
      final c = _source.codeUnitAt(index);
      if (c == kBackslash) {
        index += 2;
        continue;
      }
      if (c == kNewline) break;
      index++;
      if (c == kOpenBracket) {
        inClass = true;
      } else if (c == kCloseBracket) {
        inClass = false;
      } else if (c == kSlash && !inClass) {
        break;
      }
    }
    while (index < _source.length && isLetter(_source.codeUnitAt(index))) {
      index++;
    }
    return index;
  }
}
