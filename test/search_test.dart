import 'package:approach_tree/data/search.dart';
import 'package:approach_tree/models/node.dart';
import 'package:flutter_test/flutter_test.dart';

Leaf leaf(String id, String label, String name, {String? alias, List<String> tags = const []}) =>
    Leaf(id: id, label: label, name: name, lead: '', alias: alias, tags: tags);

void main() {
  final heap = leaf('heap', 'top-k from a stream', 'heap',
      alias: 'priority queue', tags: ['leaderboard', 'top-k', 'stream']);
  final sortedSet = leaf('sorted-set', 'live ranking with updates', 'sorted set',
      alias: 'order-statistic tree', tags: ['leaderboard', 'ranking', 'rank']);
  final topo = leaf('topo', 'tasks that depend on others', 'topological sort',
      tags: ['depends-on', 'dag', 'build-order']);
  final dijkstra = leaf('dijkstra', 'cheapest path, weighted', 'Dijkstra', tags: ['shortest', 'heap']);
  final all = [heap, sortedSet, topo, dijkstra];

  List<String> ids(String query) =>
      SearchMatcher.search(all, SearchMatcher.words(query)).map((m) => m.leaf.id).toList();

  test('splits the query into lowercase words', () {
    expect(SearchMatcher.words('  Depends   ON '), ['depends', 'on']);
    expect(SearchMatcher.words(''), isEmpty);
  });

  test('an empty query matches nothing', () {
    expect(ids(''), isEmpty);
    expect(ids('   '), isEmpty);
    expect(SearchMatcher.match(heap, const []), isNull);
  });

  test('matches labels, names, aliases and tags', () {
    expect(ids('stream'), ['heap']);
    expect(ids('topological'), ['topo']);
    expect(ids('priority'), ['heap']);
    expect(ids('statistic'), ['sorted-set']);
    expect(ids('dag'), ['topo']);
  });

  test('is case-insensitive', () {
    expect(ids('DIJKSTRA'), ['dijkstra']);
    expect(ids('Leaderboard'), ['heap', 'sorted-set']);
  });

  test('matches substrings', () {
    expect(ids('rank'), ['sorted-set']);
    expect(ids('cheap'), ['dijkstra']);
  });

  test('requires every word, possibly from different fields', () {
    expect(ids('leaderboard stream'), ['heap']);
    expect(ids('leaderboard updates'), ['sorted-set']);
    expect(ids('heap path'), ['dijkstra']);
    expect(ids('leaderboard dag'), isEmpty);
  });

  test('keeps the order of the input', () {
    expect(ids('heap'), ['heap', 'dijkstra']);
  });

  test('reports the tag that matched, if any', () {
    final m = SearchMatcher.match(heap, ['leaderboard'])!;
    expect(m.tag, 'leaderboard');
    expect(SearchMatcher.match(heap, ['priority'])!.tag, isNull);
  });

  test('prefers the tag covering the most words', () {
    final m = SearchMatcher.match(topo, SearchMatcher.words('depends on'))!;
    expect(m.tag, 'depends-on');
    final t = leaf('t', 'x', 'y', tags: ['short', 'shortest-path']);
    expect(SearchMatcher.match(t, ['short', 'path'])!.tag, 'shortest-path');
    expect(SearchMatcher.match(t, ['short'])!.tag, 'short');
  });
}
