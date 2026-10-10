/// A node in the approach tree: a [Folder] (root, part or chapter) or a [Leaf].
sealed class Node {
  Node({required this.id, required this.title});

  final String id;

  /// A folder's name, or a leaf's situation label.
  final String title;

  Folder? parent;

  /// Ancestors from the root down to the direct parent.
  List<Folder> get ancestors {
    final out = <Folder>[];
    for (var p = parent; p != null; p = p.parent) {
      out.add(p);
    }
    return out.reversed.toList();
  }

  int get depth {
    var d = 0;
    for (var p = parent; p != null; p = p.parent) {
      d++;
    }
    return d;
  }

  bool get isLastChild =>
      parent == null || identical(parent!.children.last, this);
}

class Folder extends Node {
  Folder({required super.id, required super.title, this.prefix, this.section});

  /// Short dim marker shown before the title, e.g. "I" or "04".
  final String? prefix;

  /// Book citation for the whole folder, e.g. "CPH ch. 4".
  final String? section;

  final List<Node> children = [];

  void add(Node child) {
    child.parent = this;
    children.add(child);
  }

  /// Every leaf below this folder, in tree order.
  Iterable<Leaf> get leaves sync* {
    for (final child in children) {
      switch (child) {
        case Leaf():
          yield child;
        case Folder():
          yield* child.leaves;
      }
    }
  }
}

class Leaf extends Node {
  Leaf({
    required super.id,
    required String label,
    required this.name,
    required this.lead,
    this.section,
    this.alias,
    this.when = const [],
    this.how = '',
    this.time,
    this.space,
    this.vars = const {},
    this.sketch,
    this.traps = const [],
    this.instead = const [],
    this.tags = const [],
    this.steps = const [],
    this.table = const [],
  }) : super(title: label);

  /// The situation, in the user's words: "top-k from a stream".
  String get label => title;

  /// The approach: "heap".
  final String name;

  /// Another common name: "priority queue".
  final String? alias;

  /// Book citation, e.g. "CPH §4.5".
  final String? section;

  /// One line saying what the approach does for you.
  final String lead;

  final List<String> when;
  final String how;

  /// Time complexity, e.g. "O(n log k)". Parsed by the size calculator.
  final String? time;
  final String? space;

  /// Default values for the variables in [time].
  final Map<String, double> vars;

  /// Short Python code.
  final String? sketch;

  final List<String> traps;
  final List<Instead> instead;
  final List<String> tags;

  /// Toolkit only: an ordered checklist.
  final List<PipelineStep> steps;

  /// Toolkit only: input size → complexity rows.
  final List<SizeRow> table;
}

/// "If [condition], use [target] instead", where [target] is a leaf id.
class Instead {
  const Instead({required this.condition, required this.target});

  final String condition;
  final String target;
}

class PipelineStep {
  const PipelineStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

class SizeRow {
  const SizeRow({
    required this.size,
    required this.complexity,
    this.examples = '',
  });

  final String size;
  final String complexity;
  final String examples;
}
