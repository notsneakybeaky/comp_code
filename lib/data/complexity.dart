import 'dart:math' as math;

/// A parsed time complexity such as `O(n log k)` that can estimate step counts.
///
/// Grammar, loosest binding first:
///   expr    := term (('+' | '-') term)*
///   term    := power (('*' | '·' | '×' | '/')? power)*   juxtaposition multiplies
///   power   := unary ('^' power)?                          right associative
///   unary   := func ('^' number)? unary | postfix          log, lg, ln, sqrt, √
///   postfix := primary '!'*
///   primary := number | variable | '(' expr ')'
///
/// `log` is base 2 and never drops below 1, so `n log k` stays sane for k ≤ 2.
/// Superscripts ² and ³ are read as ^2 and ^3.
class Complexity {
  Complexity._(this.expression, this._root, this.variables);

  /// The expression inside `O(...)`.
  final String expression;
  final _Expr _root;

  /// Variable names in order of first appearance.
  final List<String> variables;

  static const fitsLimit = 1e8;
  static const tightLimit = 1e9;

  /// Parses [text], which may be wrapped as `O(...)` and followed by a note
  /// such as "average". Throws [FormatException] if it can't be read.
  static Complexity parse(String text) {
    final inner = extractBigO(text);
    final parser = _Parser(_tokenize(inner));
    final root = parser.parse();
    return Complexity._(inner, root, parser.variables);
  }

  static Complexity? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      return parse(text);
    } on FormatException {
      return null;
    }
  }

  /// Estimated steps for the given variable values. Missing variables count as 1.
  double steps(Map<String, double> values) => _root.eval(values);

  /// Returns the text inside the first `O(...)`, or all of [text] if there is none.
  static String extractBigO(String text) {
    final start = text.indexOf('O(');
    if (start < 0) return text.trim();
    var depth = 0;
    for (var i = start + 1; i < text.length; i++) {
      final c = text[i];
      if (c == '(') depth++;
      if (c == ')') {
        depth--;
        if (depth == 0) return text.substring(start + 2, i).trim();
      }
    }
    throw FormatException('unbalanced parentheses', text);
  }
}

enum Verdict {
  fits('fits'),
  tight('tight'),
  tooSlow('too slow');

  const Verdict(this.label);
  final String label;

  static Verdict of(double steps) {
    if (steps.isNaN || steps > Complexity.tightLimit) return Verdict.tooSlow;
    if (steps > Complexity.fitsLimit) return Verdict.tight;
    return Verdict.fits;
  }
}

// ---------------------------------------------------------------------------
// Number helpers for the size inputs.

/// Reads a size the way people type it: `10,000,000`, `1e7`, `10^7`, `2_000`.
double? parseSize(String input) {
  final s = input.replaceAll(RegExp(r"[,_'\s]"), '');
  if (s.isEmpty) return null;
  final pow = RegExp(r'^(\d+(?:\.\d+)?)\^(\d+(?:\.\d+)?)$').firstMatch(s);
  final value = pow != null
      ? math.pow(double.parse(pow[1]!), double.parse(pow[2]!)).toDouble()
      : double.tryParse(s);
  if (value == null || value.isNaN || value < 0) return null;
  return value;
}

/// `10000000` → `10,000,000`. Very large or fractional values use `1.5e20` style.
String formatSize(double value) {
  if (value >= 1e15) return value.toStringAsExponential(1).replaceAll('+', '');
  if (value != value.roundToDouble()) {
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }
  final digits = value.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

const _superscripts = {
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', //
  '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻',
};

String superscript(int n) =>
    n.toString().split('').map((c) => _superscripts[c] ?? c).join();

/// `33219280.9` → `3.3 × 10⁷`; small counts stay plain.
String formatSteps(double steps) {
  if (steps.isNaN) return '?';
  if (steps.isInfinite || steps > 1e300) return '> 10³⁰⁰';
  if (steps < 1000) return steps.round().toString();
  var exp = (math.log(steps) / math.ln10).floor();
  var mantissa = steps / math.pow(10, exp);
  if (double.parse(mantissa.toStringAsFixed(1)) >= 10) {
    exp++;
    mantissa /= 10;
  }
  return '${mantissa.toStringAsFixed(1)} × 10${superscript(exp)}';
}

/// Makes a stored complexity easier to read: `n^2` → `n²`, `*` → `·`.
String prettyComplexity(String text) => text
    .replaceAll(RegExp(r'\^2(?![\w(.])'), '²')
    .replaceAll(RegExp(r'\^3(?![\w(.])'), '³')
    .replaceAll(RegExp(r'\^n(?![\w(.])'), 'ⁿ')
    .replaceAll(' * ', ' · ')
    .replaceAll('*', '·');

// ---------------------------------------------------------------------------
// Tokenizer and parser.

enum _T { number, name, op, end }

class _Token {
  const _Token(this.type, this.text, [this.value = 0]);
  final _T type;
  final String text;
  final double value;

  @override
  String toString() => text;
}

const _functions = {'log', 'lg', 'ln', 'sqrt', '√'};
const _multiply = {'*', '·', '×', '⋅', '/'};
final _letter = RegExp(r'[A-Za-z_α-ωΑ-Ω]');

List<_Token> _tokenize(String src) {
  final tokens = <_Token>[];
  var i = 0;
  bool isLetter(String c) => _letter.hasMatch(c);
  bool isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  while (i < src.length) {
    final c = src[i];
    if (c.trim().isEmpty) {
      i++;
    } else if (isDigit(c) || (c == '.' && i + 1 < src.length && isDigit(src[i + 1]))) {
      final start = i;
      while (i < src.length && (isDigit(src[i]) || src[i] == '.')) {
        i++;
      }
      final text = src.substring(start, i);
      final value = double.tryParse(text);
      if (value == null) throw FormatException('bad number "$text"', src, start);
      tokens.add(_Token(_T.number, text, value));
    } else if (isLetter(c)) {
      final start = i;
      while (i < src.length && isLetter(src[i])) {
        i++;
      }
      tokens.add(_Token(_T.name, src.substring(start, i)));
    } else if (c == '²' || c == '³') {
      tokens
        ..add(const _Token(_T.op, '^'))
        ..add(_Token(_T.number, c, c == '²' ? 2 : 3));
      i++;
    } else if (c == '√') {
      tokens.add(const _Token(_T.name, '√'));
      i++;
    } else if ('+-^!()'.contains(c) || _multiply.contains(c)) {
      tokens.add(_Token(_T.op, c));
      i++;
    } else {
      throw FormatException('unexpected "$c"', src, i);
    }
  }
  tokens.add(const _Token(_T.end, ''));
  return tokens;
}

class _Parser {
  _Parser(this.tokens);

  final List<_Token> tokens;
  final List<String> variables = [];
  var _i = 0;

  _Token get _peek => tokens[_i];
  _Token _next() => tokens[_i++];

  bool _isOp(String op) => _peek.type == _T.op && _peek.text == op;

  bool get _startsOperand =>
      _peek.type == _T.number || _peek.type == _T.name || _isOp('(');

  _Expr parse() {
    if (_peek.type == _T.end) throw const FormatException('empty complexity');
    final e = _expr();
    if (_peek.type != _T.end) {
      throw FormatException('unexpected "${_peek.text}"');
    }
    return e;
  }

  _Expr _expr() {
    var left = _term();
    while (_isOp('+') || _isOp('-')) {
      final op = _next().text;
      left = _Binary(op, left, _term());
    }
    return left;
  }

  _Expr _term() {
    var left = _power();
    while (true) {
      if (_peek.type == _T.op && _multiply.contains(_peek.text)) {
        final op = _next().text == '/' ? '/' : '*';
        left = _Binary(op, left, _power());
      } else if (_startsOperand) {
        left = _Binary('*', left, _power());
      } else {
        return left;
      }
    }
  }

  _Expr _power() {
    final base = _unary();
    if (_isOp('^')) {
      _next();
      return _Binary('^', base, _power());
    }
    return base;
  }

  _Expr _unary() {
    if (_peek.type == _T.name && _functions.contains(_peek.text)) {
      final name = _next().text;
      var exponent = 1.0;
      if (_isOp('^')) {
        _next();
        if (_peek.type != _T.number) {
          throw const FormatException('expected a number after log^');
        }
        exponent = _next().value;
      }
      if (!_startsOperand) throw FormatException('"$name" needs an argument');
      return _Function(name == 'sqrt' || name == '√' ? 'sqrt' : 'log',
          _unary(), exponent);
    }
    return _postfix();
  }

  _Expr _postfix() {
    var e = _primary();
    while (_isOp('!')) {
      _next();
      e = _Factorial(e);
    }
    return e;
  }

  _Expr _primary() {
    final t = _next();
    switch (t.type) {
      case _T.number:
        return _Number(t.value);
      case _T.name:
        if (_functions.contains(t.text)) {
          throw FormatException('"${t.text}" needs an argument');
        }
        if (!variables.contains(t.text)) variables.add(t.text);
        return _Variable(t.text);
      case _T.op when t.text == '(':
        final e = _expr();
        if (!_isOp(')')) throw const FormatException('missing ")"');
        _next();
        return e;
      default:
        throw FormatException(
            t.type == _T.end ? 'unexpected end' : 'unexpected "${t.text}"');
    }
  }
}

sealed class _Expr {
  double eval(Map<String, double> env);
}

class _Number extends _Expr {
  _Number(this.value);
  final double value;

  @override
  double eval(Map<String, double> env) => value;
}

class _Variable extends _Expr {
  _Variable(this.name);
  final String name;

  @override
  double eval(Map<String, double> env) => env[name] ?? 1;
}

class _Binary extends _Expr {
  _Binary(this.op, this.left, this.right);
  final String op;
  final _Expr left;
  final _Expr right;

  @override
  double eval(Map<String, double> env) {
    final a = left.eval(env);
    final b = right.eval(env);
    return switch (op) {
      '+' => a + b,
      '-' => a - b,
      '*' => a * b,
      '/' => a / b,
      _ => math.pow(a, b).toDouble(),
    };
  }
}

class _Function extends _Expr {
  _Function(this.name, this.argument, this.exponent);
  final String name;
  final _Expr argument;
  final double exponent;

  @override
  double eval(Map<String, double> env) {
    final x = argument.eval(env);
    final y = name == 'sqrt'
        ? math.sqrt(math.max(0, x))
        : math.max(1.0, math.log(x) / math.ln2);
    return exponent == 1 ? y : math.pow(y, exponent).toDouble();
  }
}

class _Factorial extends _Expr {
  _Factorial(this.argument);
  final _Expr argument;

  @override
  double eval(Map<String, double> env) {
    final n = argument.eval(env).round();
    if (n < 0) return double.nan;
    if (n > 170) return double.infinity;
    var f = 1.0;
    for (var i = 2; i <= n; i++) {
      f *= i;
    }
    return f;
  }
}
