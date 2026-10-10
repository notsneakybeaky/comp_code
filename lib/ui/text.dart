import 'dart:math' as math;

import '../data/complexity.dart' show superscript;
import '../models/node.dart';

final _power = RegExp(r'\^(\d+|n)(?![\w(.])');

/// Shows simple powers in prose as superscripts: `10^9` → `10⁹`, `2^n` → `2ⁿ`.
/// Anything more complex, like `2^(n/2)`, is left as written.
String prettyText(String text) => text.replaceAllMapped(
      _power,
      (m) => m[1] == 'n' ? 'ⁿ' : superscript(int.parse(m[1]!)),
    );

/// A folder's prefix padded to the widest prefix among its siblings (I, II, III).
String alignedPrefix(Folder folder) {
  final siblings = folder.parent?.children.whereType<Folder>() ?? [folder];
  final width = siblings.map((f) => f.prefix?.length ?? 0).fold(0, math.max);
  return (folder.prefix ?? '').padRight(width);
}
