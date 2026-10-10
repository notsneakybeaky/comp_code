import 'dart:math' as math;

import 'package:approach_tree/data/complexity.dart';
import 'package:flutter_test/flutter_test.dart';

double steps(String time, Map<String, double> values) => Complexity.parse(time).steps(values);

void main() {
  group('parse', () {
    test('reads O(...) and lists variables in order', () {
      final c = Complexity.parse('O(n log k)');
      expect(c.expression, 'n log k');
      expect(c.variables, ['n', 'k']);
    });

    test('ignores a note after the O(...)', () {
      final c = Complexity.parse('O(n) average');
      expect(c.variables, ['n']);
      expect(c.steps({'n': 5}), 5);
    });

    test('accepts a bare expression', () {
      expect(Complexity.parse('n^2').steps({'n': 30}), 900);
    });

    test('constant complexity has no variables', () {
      final c = Complexity.parse('O(1) per operation');
      expect(c.variables, isEmpty);
      expect(c.steps({}), 1);
    });

    test('rejects malformed input', () {
      for (final bad in ['', 'O()', 'O(n log)', 'O(n +)', 'O(n', 'O(n \$ m)', 'O(sqrt)', 'O(log^ n)']) {
        expect(() => Complexity.parse(bad), throwsFormatException, reason: bad);
      }
      expect(Complexity.tryParse('O(n log)'), isNull);
      expect(Complexity.tryParse(null), isNull);
    });
  });

  group('evaluate', () {
    test('the mockup example: n log k', () {
      final s = steps('O(n log k)', {'n': 1e7, 'k': 10});
      expect(s, closeTo(1e7 * math.log(10) / math.ln2, 1));
      expect(formatSteps(s), '3.3 × 10⁷');
      expect(Verdict.of(s), Verdict.fits);
    });

    test('log is base 2 and never below 1', () {
      expect(steps('O(log n)', {'n': 1024}), closeTo(10, 1e-9));
      expect(steps('O(n log k)', {'n': 100, 'k': 1}), 100);
      expect(steps('O(log n)', {'n': 0}), 1);
    });

    test('implicit multiplication', () {
      expect(steps('O(n m)', {'n': 3, 'm': 4}), 12);
      expect(steps('O(n log n + q)', {'n': 8, 'q': 5}), 29);
      expect(steps('O((n + q) log n)', {'n': 8, 'q': 8}), 48);
      expect(steps('O(k^3 log n)', {'k': 2, 'n': 256}), 64);
    });

    test('explicit operators', () {
      expect(steps('O(n * m / 64)', {'n': 64, 'm': 10}), 10);
      expect(steps('O(n · m)', {'n': 2, 'm': 5}), 10);
      expect(steps('O(n × m)', {'n': 2, 'm': 5}), 10);
      expect(steps('O(n - m)', {'n': 7, 'm': 2}), 5);
    });

    test('powers are right associative and bind tighter than products', () {
      expect(steps('2^3^2', {}), 512);
      expect(steps('O(2^n * n)', {'n': 20}), 20 * 1048576);
      expect(steps('O(2^(n/2) * n)', {'n': 40}), 40 * 1048576);
      expect(steps('O(n^2 * k / 64)', {'n': 8, 'k': 64}), 64);
    });

    test('superscripts', () {
      expect(steps('O(n²)', {'n': 7}), 49);
      expect(steps('O(n³)', {'n': 3}), 27);
      expect(steps('O(log² n)', {'n': 16}), 16);
      expect(steps('O(log^2 n)', {'n': 16}), 16);
    });

    test('functions: sqrt, √, nested log', () {
      expect(steps('O(√n)', {'n': 1e12}), closeTo(1e6, 1e-6));
      expect(steps('O(sqrt n)', {'n': 81}), 9);
      expect(steps('O(n √n)', {'n': 100}), 1000);
      expect(steps('O((n + q) √n)', {'n': 100, 'q': 100}), 2000);
      expect(steps('O(sqrt(n + m))', {'n': 10, 'm': 6}), 4);
      expect(steps('O(n log log n)', {'n': 65536}), 65536 * 4);
    });

    test('factorial', () {
      expect(steps('O(n!)', {'n': 10}), 3628800);
      expect(steps('O(n! * n)', {'n': 3}), 18);
      expect(steps('O(n!)', {'n': 171}), double.infinity);
    });

    test('missing variables count as 1', () {
      expect(steps('O(n m)', {'n': 5}), 5);
    });
  });

  group('verdict', () {
    test('thresholds', () {
      expect(Verdict.of(1e8), Verdict.fits);
      expect(Verdict.of(1e8 + 1), Verdict.tight);
      expect(Verdict.of(1e9), Verdict.tight);
      expect(Verdict.of(1e9 + 1), Verdict.tooSlow);
      expect(Verdict.of(double.infinity), Verdict.tooSlow);
      expect(Verdict.of(double.nan), Verdict.tooSlow);
    });
  });

  group('number helpers', () {
    test('parseSize accepts common spellings', () {
      expect(parseSize('10,000,000'), 1e7);
      expect(parseSize('1e7'), 1e7);
      expect(parseSize('1e+18'), 1e18);
      expect(parseSize('10^7'), 1e7);
      expect(parseSize('2_000'), 2000);
      expect(parseSize(' 42 '), 42);
      expect(parseSize('0'), 0);
    });

    test('parseSize rejects junk', () {
      for (final bad in ['', 'abc', '-5', '1e', '10^', ',']) {
        expect(parseSize(bad), isNull, reason: bad);
      }
    });

    test('formatSize', () {
      expect(formatSize(10000000), '10,000,000');
      expect(formatSize(999), '999');
      expect(formatSize(1000), '1,000');
      expect(formatSize(0), '0');
      expect(formatSize(1e18), '1.0e18');
      expect(formatSize(2.5), '2.5');
    });

    test('formatSteps', () {
      expect(formatSteps(999), '999');
      expect(formatSteps(1000), '1.0 × 10³');
      expect(formatSteps(99999999), '1.0 × 10⁸');
      expect(formatSteps(1.5e12), '1.5 × 10¹²');
      expect(formatSteps(double.infinity), '> 10³⁰⁰');
    });

    test('prettyComplexity', () {
      expect(prettyComplexity('O(n^2)'), 'O(n²)');
      expect(prettyComplexity('O(n^3)'), 'O(n³)');
      expect(prettyComplexity('O(2^n * n)'), 'O(2ⁿ · n)');
      expect(prettyComplexity('O(2^(n/2) * n)'), 'O(2^(n/2) · n)');
      expect(prettyComplexity('O(n^2 * k / 64)'), 'O(n² · k / 64)');
      expect(prettyComplexity('O(log^2 n)'), 'O(log² n)');
    });
  });
}
