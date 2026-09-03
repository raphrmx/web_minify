/// Character-class helpers shared by the three minifiers.
///
/// The minifiers scan their input one code unit at a time instead of running
/// regular expressions over it, so that string literals, comments and embedded
/// languages are never rewritten by accident. These constants and predicates
/// keep that scanning readable.
library;

const int kTab = 0x09;
const int kNewline = 0x0A;
const int kVerticalTab = 0x0B;
const int kFormFeed = 0x0C;
const int kCarriageReturn = 0x0D;
const int kSpace = 0x20;
const int kExclamation = 0x21;
const int kDoubleQuote = 0x22;
const int kHash = 0x23;
const int kDollar = 0x24;
const int kPercent = 0x25;
const int kAmpersand = 0x26;
const int kSingleQuote = 0x27;
const int kOpenParen = 0x28;
const int kCloseParen = 0x29;
const int kStar = 0x2A;
const int kPlus = 0x2B;
const int kComma = 0x2C;
const int kMinus = 0x2D;
const int kDot = 0x2E;
const int kSlash = 0x2F;
const int kZero = 0x30;
const int kNine = 0x39;
const int kColon = 0x3A;
const int kSemicolon = 0x3B;
const int kLessThan = 0x3C;
const int kEquals = 0x3D;
const int kGreaterThan = 0x3E;
const int kQuestion = 0x3F;
const int kAt = 0x40;
const int kUpperA = 0x41;
const int kUpperF = 0x46;
const int kUpperZ = 0x5A;
const int kOpenBracket = 0x5B;
const int kBackslash = 0x5C;
const int kCloseBracket = 0x5D;
const int kCaret = 0x5E;
const int kUnderscore = 0x5F;
const int kBacktick = 0x60;
const int kLowerA = 0x61;
const int kLowerF = 0x66;
const int kLowerZ = 0x7A;
const int kOpenBrace = 0x7B;
const int kPipe = 0x7C;
const int kCloseBrace = 0x7D;
const int kTilde = 0x7E;

/// Whether [c] is a space, tab, newline, carriage return, form feed or
/// vertical tab.
///
/// ### Parameters:
/// - [c]: the code unit to test.
///
/// ### Returns:
/// `true` when [c] is whitespace.
///
/// ### Example:
/// ```dart
/// isWhitespace(' '.codeUnitAt(0)); // true
/// ```
bool isWhitespace(int c) =>
    c == kSpace || c == kTab || c == kNewline || c == kCarriageReturn || c == kFormFeed || c == kVerticalTab;

/// Whether [c] is an ASCII letter.
bool isLetter(int c) => (c >= kLowerA && c <= kLowerZ) || (c >= kUpperA && c <= kUpperZ);

/// Whether [c] is an ASCII digit.
bool isDigit(int c) => c >= kZero && c <= kNine;

/// Whether [c] is a hexadecimal digit, in either case.
bool isHexDigit(int c) => isDigit(c) || (c >= kLowerA && c <= kLowerF) || (c >= kUpperA && c <= kUpperF);

/// Whether [c] can appear inside a JavaScript identifier, a CSS identifier or
/// a number.
///
/// Non-ASCII code units are treated as identifier characters, which is what
/// keeps accented identifiers and unicode escapes from being glued to a
/// neighbouring token.
///
/// ### Parameters:
/// - [c]: the code unit to test.
///
/// ### Returns:
/// `true` when [c] is a word character.
bool isWordChar(int c) => isLetter(c) || isDigit(c) || c == kUnderscore || c == kDollar || c > 0x7F;
