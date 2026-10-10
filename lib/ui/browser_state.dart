import 'package:flutter/foundation.dart';

import '../data/search.dart';
import '../models/node.dart';

/// One visible line of the tree.
class TreeRow {
  const TreeRow(this.node, this.rails);

  final Node node;

  /// For each ancestor depth 1..depth-1: whether that ancestor has a later
  /// sibling, so its guide line continues through this row.
  final List<bool> rails;
}

/// Selection, expansion and filter state for the tree and card.
class BrowserState extends ChangeNotifier {
  BrowserState(this.root) : leaves = root.leaves.toList() {
    for (final leaf in leaves) {
      _leafById[leaf.id] = leaf;
    }
    _expanded.addAll(root.children.whereType<Folder>().map((f) => f.id));
    _rebuildRows();
  }

  static const pipelineId = 'pipeline';

  final Folder root;
  final List<Leaf> leaves;
  final _leafById = <String, Leaf>{};

  /// Expansion when no filter is active; kept while searching.
  final _expanded = <String>{};

  /// Expansion while searching: folders with matches, plus anything toggled.
  var _filterExpanded = <String>{};

  var _query = '';
  var _words = const <String>[];
  var _matches = <String, LeafMatch>{};
  var _folderMatches = <String, int>{};
  late Node _selected = root;
  var _rows = const <TreeRow>[];

  /// Size inputs the user typed, per leaf.
  final _sizes = <String, Map<String, double>>{};

  String get query => _query;
  bool get filtering => _words.isNotEmpty;
  int get matchCount => _matches.length;
  Node get selected => _selected;
  List<TreeRow> get rows => _rows;
  int get selectedIndex => _rows.indexWhere((r) => identical(r.node, _selected));

  Leaf? leafById(String id) => _leafById[id];
  LeafMatch? matchOf(Leaf leaf) => _matches[leaf.id];
  int matchesIn(Folder folder) => _folderMatches[folder.id] ?? 0;

  bool isExpanded(Folder folder) =>
      identical(folder, root) || _activeExpanded.contains(folder.id);

  Set<String> get _activeExpanded => filtering ? _filterExpanded : _expanded;

  /// While searching, rows that aren't matches (or don't contain any) are dimmed.
  bool isDimmed(Node node) {
    if (!filtering) return false;
    return switch (node) {
      Leaf() => !_matches.containsKey(node.id),
      Folder() => !identical(node, root) && matchesIn(node) == 0,
    };
  }

  void setQuery(String query) {
    if (query == _query) return;
    _query = query;
    _words = SearchMatcher.words(query);
    final found = SearchMatcher.search(leaves, _words);
    _matches = {for (final m in found) m.leaf.id: m};
    _folderMatches = {};
    for (final m in found) {
      for (final folder in m.leaf.ancestors) {
        _folderMatches[folder.id] = (_folderMatches[folder.id] ?? 0) + 1;
      }
    }
    _filterExpanded = _folderMatches.keys.toSet();

    if (filtering) {
      final selectedIsMatch = _selected is Leaf && _matches.containsKey(_selected.id);
      if (!selectedIsMatch && found.isNotEmpty) _selected = found.first.leaf;
    } else {
      _expandAncestors(_selected);
    }
    _rebuildRows();
    notifyListeners();
  }

  /// Row indexes of visible matches.
  List<int> get _matchRows => [
        for (final (i, row) in _rows.indexed)
          if (row.node is Leaf && _matches.containsKey(row.node.id)) i,
      ];

  /// Moves the selection. While searching it steps between matches only.
  void move(int delta) {
    final current = selectedIndex;
    if (filtering) {
      final targets = _matchRows;
      if (targets.isEmpty) return;
      int? next;
      if (delta > 0) {
        next = targets.where((i) => i > current).firstOrNull ?? targets.last;
      } else {
        next = targets.where((i) => i < current).lastOrNull ?? targets.first;
      }
      _selected = _rows[next].node;
    } else {
      if (_rows.isEmpty) return;
      final next = current < 0 ? 0 : (current + delta).clamp(0, _rows.length - 1);
      _selected = _rows[next].node;
    }
    notifyListeners();
  }

  /// Home / End: the first or last row (or match, while searching).
  void moveToEnd({required bool last}) {
    final targets = filtering ? _matchRows : [for (var i = 0; i < _rows.length; i++) i];
    if (targets.isEmpty) return;
    _selected = _rows[last ? targets.last : targets.first].node;
    notifyListeners();
  }

  /// `→`: expand a folder, or step into it if it is already open.
  void expandOrEnter() {
    final node = _selected;
    if (node is! Folder) return;
    if (!isExpanded(node)) {
      _activeExpanded.add(node.id);
      _rebuildRows();
    } else if (node.children.isNotEmpty) {
      final children = node.children;
      _selected = filtering
          ? children.firstWhere((c) => !isDimmed(c), orElse: () => children.first)
          : children.first;
    }
    notifyListeners();
  }

  /// `←`: collapse an open folder, otherwise go up to the parent.
  void collapseOrBack() {
    final node = _selected;
    if (node is Folder && !identical(node, root) && isExpanded(node)) {
      _activeExpanded.remove(node.id);
      _rebuildRows();
    } else if (node.parent != null) {
      _selected = node.parent!;
    }
    notifyListeners();
  }

  /// Clicking a row: select it, and open or close it if it's a folder.
  void activate(Node node) {
    if (node is Folder && !identical(node, root) && identical(node, _selected)) {
      if (!_activeExpanded.remove(node.id)) _activeExpanded.add(node.id);
      _rebuildRows();
    } else if (node is Folder && !isExpanded(node)) {
      _activeExpanded.add(node.id);
      _rebuildRows();
    }
    _selected = node;
    notifyListeners();
  }

  /// Selects [node] and opens every folder above it so it is visible.
  void reveal(Node node) {
    _expandAncestors(node, into: _activeExpanded);
    _selected = node;
    _rebuildRows();
    notifyListeners();
  }

  void openPipeline() {
    final pipeline = leafById(pipelineId);
    if (pipeline != null) reveal(pipeline);
  }

  double? sizeOf(Leaf leaf, String variable) => _sizes[leaf.id]?[variable];

  /// Remembers a typed size. The card owns the redraw, so no notification.
  void setSize(Leaf leaf, String variable, double value) =>
      (_sizes[leaf.id] ??= {})[variable] = value;

  void _expandAncestors(Node node, {Set<String>? into}) {
    for (final folder in node.ancestors) {
      (into ?? _expanded).add(folder.id);
    }
  }

  void _rebuildRows() {
    final rows = <TreeRow>[];
    void visit(Node node, List<bool> rails) {
      rows.add(TreeRow(node, rails));
      if (node is Folder && isExpanded(node)) {
        final childRails = identical(node, root) ? const <bool>[] : [...rails, !node.isLastChild];
        for (final child in node.children) {
          visit(child, childRails);
        }
      }
    }

    visit(root, const []);
    _rows = rows;
  }
}
