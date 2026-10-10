import 'package:yaml/yaml.dart';

import '../models/node.dart';
import 'complexity.dart';

/// A problem in a topic file, reported with the file name so it's easy to fix.
class ContentError implements Exception {
  ContentError(this.file, this.message);

  final String file;
  final String message;

  @override
  String toString() => '$file: $message';
}

/// Builds the approach tree from YAML topic files.
///
/// Each file names the top-level folder it belongs to under `part:`, then lists
/// `chapters:` (folders of leaves) and/or `leaves:`. Files that name the same
/// part are merged in file order, so a part can be split into chapter groups.
abstract final class TopicParser {
  /// [files] maps file name → YAML source, already in load order.
  static Folder buildTree(Map<String, String> files) {
    final root = Folder(id: 'root', title: 'approaches');
    final ids = <String>{root.id};
    final parts = <String, Folder>{};

    void claim(String file, String id) {
      if (!ids.add(id)) throw ContentError(file, 'duplicate id "$id"');
    }

    for (final MapEntry(key: file, value: source) in files.entries) {
      final Object? doc;
      try {
        doc = loadYaml(source);
      } on YamlException catch (e) {
        throw ContentError(file, e.toString());
      }
      if (doc == null) continue;
      final top = _Fields(file, doc, 'file');

      final partFields = top.object('part');
      final partId = partFields.string('id');
      final part = parts.putIfAbsent(partId, () {
        claim(file, partId);
        final folder = Folder(
          id: partId,
          title: partFields.string('title'),
          prefix: partFields.optional('prefix'),
          section: partFields.optional('section'),
        );
        root.add(folder);
        return folder;
      });

      for (final c in top.objects('chapters')) {
        final id = c.string('id');
        claim(file, id);
        final chapter = Folder(
          id: id,
          title: c.string('title'),
          prefix: c.optional('prefix'),
          section: c.optional('section'),
        );
        for (final l in c.objects('leaves')) {
          final leaf = _leaf(l);
          claim(file, leaf.id);
          chapter.add(leaf);
        }
        part.add(chapter);
      }
      for (final l in top.objects('leaves')) {
        final leaf = _leaf(l);
        claim(file, leaf.id);
        part.add(leaf);
      }
    }
    return root;
  }

  static Leaf _leaf(_Fields f) {
    final id = f.string('id');
    final at = f.at(id);
    return Leaf(
      id: id,
      label: at.string('label'),
      name: at.string('name'),
      lead: at.string('lead'),
      section: at.optional('section'),
      alias: at.optional('alias'),
      when: at.strings('when'),
      how: at.optional('how') ?? '',
      time: at.optional('time'),
      space: at.optional('space'),
      vars: at.sizes('vars'),
      sketch: at.optional('sketch')?.trimRight(),
      traps: at.strings('traps'),
      instead: [
        for (final i in at.objects('instead'))
          Instead(condition: i.string('if'), target: i.string('target')),
      ],
      tags: at.strings('tags'),
      steps: [
        for (final s in at.objects('steps'))
          PipelineStep(title: s.string('title'), detail: s.string('detail')),
      ],
      table: [
        for (final r in at.objects('table'))
          SizeRow(
            size: r.string('size'),
            complexity: r.string('fits'),
            examples: r.optional('examples') ?? '',
          ),
      ],
    );
  }
}

/// Typed access to a YAML map, with errors that say where the problem is.
class _Fields {
  _Fields(this.file, Object? node, this.where) : map = _asMap(file, node, where);

  final String file;
  final String where;
  final YamlMap map;

  static YamlMap _asMap(String file, Object? node, String where) {
    if (node is YamlMap) return node;
    throw ContentError(file, '$where: expected a map');
  }

  _Fields at(String name) => _Fields(file, map, name);

  Never _fail(String message) => throw ContentError(file, '$where: $message');

  String string(String key) {
    final v = optional(key);
    if (v == null || v.isEmpty) _fail('missing "$key"');
    return v;
  }

  String? optional(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is YamlMap || v is YamlList) _fail('"$key" should be text');
    return v.toString().trim();
  }

  List<String> strings(String key) {
    final v = map[key];
    if (v == null) return const [];
    if (v is! YamlList) _fail('"$key" should be a list');
    return [for (final item in v) item.toString().trim()];
  }

  _Fields object(String key) {
    final v = map[key];
    if (v == null) _fail('missing "$key"');
    return _Fields(file, v, key);
  }

  List<_Fields> objects(String key) {
    final v = map[key];
    if (v == null) return const [];
    if (v is! YamlList) _fail('"$key" should be a list');
    return [
      for (final (i, item) in v.indexed) _Fields(file, item, '$where.$key[$i]'),
    ];
  }

  Map<String, double> sizes(String key) {
    final v = map[key];
    if (v == null) return const {};
    if (v is! YamlMap) _fail('"$key" should be a map of name: number');
    return {
      for (final MapEntry(:key, :value) in v.entries)
        key.toString(): parseSize(value.toString()) ??
            _fail('"$key" is not a number'),
    };
  }
}
