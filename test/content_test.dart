import 'package:approach_tree/data/complexity.dart';
import 'package:approach_tree/data/search.dart';
import 'package:approach_tree/data/topic_parser.dart';
import 'package:approach_tree/models/node.dart';
import 'package:approach_tree/ui/tree_pane.dart' show searchExamples;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final root = loadFromDisk();
  final leaves = root.leaves.toList();
  final byId = {for (final l in leaves) l.id: l};

  test('has the three parts of the book plus the toolkit', () {
    expect(root.children.map((c) => c.id), ['basic', 'graphs', 'advanced', 'toolkit']);
  });

  test('has chapters 1–30 in order', () {
    final chapters = [
      for (final part in root.children.whereType<Folder>())
        ...part.children.whereType<Folder>(),
    ];
    expect(chapters.map((c) => c.prefix), [for (var i = 1; i <= 30; i++) i.toString().padLeft(2, '0')]);
    for (final c in chapters) {
      expect(c.section, 'CPH ch. ${int.parse(c.prefix!)}', reason: c.id);
      expect(c.children, isNotEmpty, reason: '${c.id} has no leaves');
    }
  });

  test('every leaf cites a section inside its own chapter', () {
    for (final leaf in leaves) {
      final chapter = leaf.parent!;
      if (chapter.prefix == null) continue; // toolkit
      final n = int.parse(chapter.prefix!);
      expect(leaf.section, anyOf(startsWith('CPH §$n.'), 'CPH ch. $n'), reason: leaf.id);
    }
  });

  test('every leaf has the core fields', () {
    for (final leaf in leaves) {
      expect(leaf.lead, isNotEmpty, reason: leaf.id);
      expect(leaf.when, isNotEmpty, reason: leaf.id);
      expect(leaf.tags, isNotEmpty, reason: leaf.id);
      expect(leaf.traps, isNotEmpty, reason: leaf.id);
      for (final tag in leaf.tags) {
        expect(tag, matches(RegExp(r'^[a-z0-9+\-]+$')), reason: '${leaf.id}: tag "$tag"');
      }
    }
  });

  test('every time parses, and vars match its variables', () {
    for (final leaf in leaves) {
      if (leaf.time == null) {
        expect(leaf.vars, isEmpty, reason: leaf.id);
        continue;
      }
      expect(leaf.time, startsWith('O('), reason: leaf.id);
      final c = Complexity.tryParse(leaf.time);
      expect(c, isNotNull, reason: '${leaf.id}: "${leaf.time}" does not parse');
      expect(leaf.vars.keys.toSet(), c!.variables.toSet(), reason: '${leaf.id}: vars vs ${leaf.time}');
      expect(c.steps(leaf.vars).isNaN, isFalse, reason: leaf.id);
    }
  });

  test('every space is written as O(...)', () {
    for (final leaf in leaves) {
      if (leaf.space != null) expect(leaf.space, startsWith('O('), reason: leaf.id);
    }
  });

  test('every instead link points at another leaf', () {
    for (final leaf in leaves) {
      for (final i in leaf.instead) {
        expect(byId.containsKey(i.target), isTrue, reason: '${leaf.id} → ${i.target}');
        expect(i.target, isNot(leaf.id), reason: '${leaf.id} links to itself');
      }
    }
  });

  test('sketches use spaces, not tabs', () {
    for (final leaf in leaves) {
      expect(leaf.sketch ?? '', isNot(contains('\t')), reason: leaf.id);
    }
  });

  test('the pipeline exists for the p key', () {
    expect(byId['pipeline']?.steps.length, 6);
    expect(byId['input-size']?.table, isNotEmpty);
  });

  test('every example search finds something', () {
    for (final example in searchExamples) {
      final found = SearchMatcher.search(leaves, SearchMatcher.words(example));
      expect(found, isNotEmpty, reason: example);
    }
    final leaderboard = SearchMatcher.search(leaves, ['leaderboard']).map((m) => m.leaf.id);
    expect(leaderboard, ['heap', 'sorted-set']);
    final stuck = SearchMatcher.search(leaves, ['stuck']).map((m) => m.leaf.id);
    expect(stuck, contains('pipeline'));
  });

  test('labels in the mockup map to the same approaches', () {
    const mockup = {
      'find by key, fast': 'hash map',
      'search sorted data': 'binary search',
      'prefix / autocomplete': 'trie',
      'top-k from a stream': 'heap',
      'live ranking with updates': 'sorted set',
      'tasks that depend on others': 'topological sort',
      'best contiguous chunk': 'sliding window',
      'many range-sum queries': 'prefix sums',
      'fewest steps, unweighted': 'BFS',
      'cheapest path, weighted': 'Dijkstra',
      'same group?': 'union-find',
      'overlapping subproblems': 'dynamic programming',
      'explore every option': 'backtracking',
      'best pick each step': 'greedy',
    };
    final byLabel = {for (final l in leaves) l.label: l.name};
    mockup.forEach((label, name) => expect(byLabel[label], name, reason: label));
  });

  test('duplicate ids are rejected', () {
    const file = '''
part: {id: p, title: p}
leaves:
  - {id: a, label: a, name: a, lead: a}
  - {id: a, label: b, name: b, lead: b}
''';
    expect(() => TopicParser.buildTree({'x.yaml': file}), throwsA(isA<ContentError>()));
  });

  test('missing required fields are reported with the file name', () {
    const file = '''
part: {id: p, title: p}
leaves:
  - {id: a, label: a, lead: a}
''';
    expect(
      () => TopicParser.buildTree({'broken.yaml': file}),
      throwsA(isA<ContentError>()
          .having((e) => e.file, 'file', 'broken.yaml')
          .having((e) => e.message, 'message', contains('name'))),
    );
  });

  test('files naming the same part are merged in order', () {
    const a = '''
part: {id: p, title: p}
chapters:
  - {id: c1, title: one, leaves: [{id: x, label: x, name: x, lead: x}]}
''';
    const b = '''
part: {id: p, title: p}
chapters:
  - {id: c2, title: two, leaves: [{id: y, label: y, name: y, lead: y}]}
''';
    final tree = TopicParser.buildTree({'a.yaml': a, 'b.yaml': b});
    expect(tree.children.length, 1);
    expect((tree.children.single as Folder).children.map((c) => c.id), ['c1', 'c2']);
  });
}
