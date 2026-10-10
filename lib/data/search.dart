import '../models/node.dart';

/// A leaf that matched the query, plus the tag to show next to it (if a tag matched).
class LeafMatch {
  const LeafMatch(this.leaf, this.tag);

  final Leaf leaf;
  final String? tag;
}

/// Matches leaves by label, approach name, alias and tags.
///
/// Case-insensitive substring matching; every word of the query must appear in
/// at least one of those fields.
abstract final class SearchMatcher {
  static List<String> words(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  static LeafMatch? match(Leaf leaf, List<String> words) {
    if (words.isEmpty) return null;
    final fields = [
      leaf.label,
      leaf.name,
      ?leaf.alias,
      ...leaf.tags,
    ].map((f) => f.toLowerCase()).toList();
    for (final w in words) {
      if (!fields.any((f) => f.contains(w))) return null;
    }
    return LeafMatch(leaf, _bestTag(leaf.tags, words));
  }

  /// Matches in the order of [leaves].
  static List<LeafMatch> search(Iterable<Leaf> leaves, List<String> words) {
    if (words.isEmpty) return const [];
    return [for (final leaf in leaves) ?match(leaf, words)];
  }

  /// The tag that covers the most query words; the first one wins ties.
  static String? _bestTag(List<String> tags, List<String> words) {
    String? best;
    var bestHits = 0;
    for (final tag in tags) {
      final t = tag.toLowerCase();
      final hits = words.where(t.contains).length;
      if (hits > bestHits) {
        best = tag;
        bestHits = hits;
      }
    }
    return best;
  }
}
