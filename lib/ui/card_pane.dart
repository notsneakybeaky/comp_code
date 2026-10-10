import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/complexity.dart';
import '../models/node.dart';
import 'browser_state.dart';
import 'code_view.dart';
import 'text.dart';
import 'theme.dart';

/// The right-hand pane: a card for the selected leaf, or a folder overview.
class CardPane extends StatelessWidget {
  const CardPane({super.key, required this.state, required this.onOpen});

  final BrowserState state;

  /// Called when a link or a folder entry is clicked.
  final ValueChanged<Node> onOpen;

  @override
  Widget build(BuildContext context) {
    final node = state.selected;
    return SingleChildScrollView(
      key: ValueKey(node.id),
      padding: const EdgeInsets.fromLTRB(32, 26, 32, 32),
      child: switch (node) {
        Leaf() => _LeafCard(leaf: node, state: state, onOpen: onOpen),
        Folder() => _FolderCard(folder: node, state: state, onOpen: onOpen),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Leaf card

class _LeafCard extends StatelessWidget {
  const _LeafCard({required this.leaf, required this.state, required this.onOpen});

  final Leaf leaf;
  final BrowserState state;
  final ValueChanged<Node> onOpen;

  @override
  Widget build(BuildContext context) {
    final complexity = Complexity.tryParse(leaf.time);
    final hasCost = leaf.time != null || leaf.space != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Breadcrumb(node: leaf),
        const SizedBox(height: 18),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 8,
          children: [
            Text(leaf.name, style: mono(30, color: AppColors.approach, weight: FontWeight.w700, height: 1.15)),
            if (leaf.alias != null) _Pill(leaf.alias!),
          ],
        ),
        const SizedBox(height: 10),
        _Prose(leaf.lead, style: sans(16.5, height: 1.45)),
        if (leaf.when.isNotEmpty) _Section('when', child: _Bullets(leaf.when)),
        if (leaf.how.isNotEmpty) _Section('how', child: _Prose(leaf.how)),
        if (leaf.steps.isNotEmpty) _Section('steps', child: _Steps(leaf.steps)),
        if (leaf.table.isNotEmpty) _Section('what fits', child: _SizeTable(leaf.table)),
        if (hasCost)
          _Section(
            'cost',
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              if (leaf.time != null) _CostChip('time', leaf.time!),
              if (leaf.space != null) _CostChip('space', leaf.space!),
            ]),
          ),
        if (complexity != null && complexity.variables.isNotEmpty)
          _Section('your size', child: YourSize(leaf: leaf, complexity: complexity, state: state)),
        if (leaf.sketch != null) _Section('sketch', child: CodeBlock(code: leaf.sketch!)),
        if (leaf.traps.isNotEmpty || leaf.instead.isNotEmpty)
          _TwoColumns(
            left: leaf.traps.isEmpty ? null : _Section('traps', child: _Bullets(leaf.traps)),
            right: leaf.instead.isEmpty
                ? null
                : _Section('instead, if…', child: _InsteadList(leaf.instead, state: state, onOpen: onOpen)),
          ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.node});

  final Node node;

  @override
  Widget build(BuildContext context) {
    final section = switch (node) {
      Leaf(:final section) => section,
      Folder(:final section) => section,
    };
    final dim = mono(12.5, color: AppColors.dim);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              for (final folder in node.ancestors.skip(1)) ...[
                TextSpan(text: folder.title, style: dim),
                TextSpan(text: ' › ', style: dim),
              ],
              TextSpan(text: prettyText(node.title), style: mono(12.5, color: AppColors.text)),
            ]),
          ),
        ),
        if (section != null) ...[
          const SizedBox(width: 16),
          Text(section, style: mono(12.5, color: AppColors.muted)),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: mono(11.5, color: AppColors.dim, spacing: 2)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Text with `backtick` spans rendered as inline code.
class _Prose extends StatelessWidget {
  const _Prose(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? sans(15, height: 1.55);
    return Text.rich(TextSpan(style: base, children: inlineSpans(text, base)));
  }
}

List<InlineSpan> inlineSpans(String text, TextStyle base) {
  final parts = text.split('`');
  final size = (base.fontSize ?? 15) * 0.86;
  return [
    for (final (i, part) in parts.indexed)
      if (part.isEmpty)
        const TextSpan()
      else if (i.isEven)
        TextSpan(text: prettyText(part))
      else
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.selection,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(part, style: mono(size, color: AppColors.approach)),
          ),
        ),
  ];
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final item in items) _Bullet(child: _Prose(item))],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text('›', style: mono(15, color: AppColors.accent, weight: FontWeight.w700, height: 1.45)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: mono(13, color: AppColors.muted)),
    );
  }
}

class _CostChip extends StatelessWidget {
  const _CostChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$label  ', style: mono(13, color: AppColors.dim)),
        TextSpan(text: prettyComplexity(value), style: mono(14)),
      ])),
    );
  }
}

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({this.left, this.right});

  final Widget? left;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final columns = [?left, ?right];
    return LayoutBuilder(builder: (context, constraints) {
      if (columns.length == 1 || constraints.maxWidth < 520) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: columns);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: columns[0]),
          const SizedBox(width: 28),
          Expanded(child: columns[1]),
        ],
      );
    });
  }
}

class _InsteadList extends StatelessWidget {
  const _InsteadList(this.items, {required this.state, required this.onOpen});

  final List<Instead> items;
  final BrowserState state;
  final ValueChanged<Node> onOpen;

  @override
  Widget build(BuildContext context) {
    final base = sans(15, height: 1.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          _Bullet(
            child: Text.rich(TextSpan(style: base, children: [
              ...inlineSpans(item.condition, base),
              const TextSpan(text: ' → '),
              if (state.leafById(item.target) case final target?)
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _Link(text: target.name, onTap: () => onOpen(target)),
                )
              else
                TextSpan(text: item.target, style: mono(14, color: AppColors.muted)),
            ])),
          ),
      ],
    );
  }
}

class _Link extends StatefulWidget {
  const _Link({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<_Link> createState() => _LinkState();
}

class _LinkState extends State<_Link> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? AppColors.bright : AppColors.approach;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.text,
          style: mono(14, color: color).copyWith(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps(this.steps);

  final List<PipelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${i + 1}', style: mono(15, color: AppColors.accent, weight: FontWeight.w700, height: 1.35)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.title, style: mono(15, color: AppColors.bright, weight: FontWeight.w600, height: 1.35)),
                      const SizedBox(height: 3),
                      _Prose(step.detail, style: sans(14.5, color: AppColors.muted, height: 1.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SizeTable extends StatelessWidget {
  const _SizeTable(this.rows);

  final List<SizeRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 104, child: Text(prettyText(row.size), style: mono(14))),
                  SizedBox(
                    width: 150,
                    child: Text(prettyComplexity(row.complexity), style: mono(14, color: AppColors.approach)),
                  ),
                  Expanded(child: _Prose(row.examples, style: sans(14, color: AppColors.muted, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// YOUR SIZE: one input per variable, an estimate and a verdict.

class YourSize extends StatefulWidget {
  const YourSize({super.key, required this.leaf, required this.complexity, required this.state});

  static const fallback = 100000.0;

  final Leaf leaf;
  final Complexity complexity;
  final BrowserState state;

  @override
  State<YourSize> createState() => _YourSizeState();
}

class _YourSizeState extends State<YourSize> {
  final _controllers = <String, TextEditingController>{};
  final _values = <String, double>{};
  final _invalid = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(YourSize old) {
    super.didUpdateWidget(old);
    if (!identical(old.leaf, widget.leaf)) {
      _disposeControllers();
      _load();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _load() {
    _values.clear();
    _invalid.clear();
    for (final v in widget.complexity.variables) {
      final value = widget.state.sizeOf(widget.leaf, v) ?? widget.leaf.vars[v] ?? YourSize.fallback;
      _values[v] = value;
      _controllers[v] = TextEditingController(text: formatSize(value));
    }
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  void _changed(String variable, String text) {
    final value = parseSize(text);
    setState(() {
      if (value == null) {
        _invalid.add(variable);
      } else {
        _invalid.remove(variable);
        _values[variable] = value;
        widget.state.setSize(widget.leaf, variable, value);
      }
    });
  }

  void _tidy(String variable) {
    if (_invalid.contains(variable)) return;
    final text = formatSize(_values[variable]!);
    _controllers[variable]!.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.complexity.steps(_values);
    final verdict = Verdict.of(steps);
    final (Color bg, String mark) = switch (verdict) {
      Verdict.fits => (AppColors.approach, '✓'),
      Verdict.tight => (AppColors.accent, '~'),
      Verdict.tooSlow => (AppColors.danger, '✗'),
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final v in widget.complexity.variables)
          _SizeField(
            name: v,
            controller: _controllers[v]!,
            invalid: _invalid.contains(v),
            onChanged: (text) => _changed(v, text),
            onDone: () => _tidy(v),
          ),
        Text('→', style: mono(14, color: AppColors.dim)),
        Tooltip(
          message: 'O(${widget.complexity.expression}) with log base 2',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('≈ ${formatSteps(steps)} steps', style: mono(14)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text('$mark ${verdict.label}', style: mono(14, color: AppColors.bar, weight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _SizeField extends StatelessWidget {
  const _SizeField({
    required this.name,
    required this.controller,
    required this.invalid,
    required this.onChanged,
    required this.onDone,
  });

  final String name;
  final TextEditingController controller;
  final bool invalid;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final style = mono(14);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: invalid ? AppColors.danger : AppColors.accent, width: 2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: mono(14, color: AppColors.dim)),
              const SizedBox(width: 10),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => SizedBox(
                  width: measureText(context, controller.text.isEmpty ? '0' : controller.text, style) + 6,
                  child: Focus(
                    onFocusChange: (focused) {
                      if (!focused) onDone();
                    },
                    child: TextField(
                      controller: controller,
                      style: style,
                      cursorColor: AppColors.accent,
                      cursorWidth: 1.5,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[0-9.,_'eE^ ]"))],
                      onChanged: onChanged,
                      onSubmitted: (_) => onDone(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Folder card

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, required this.state, required this.onOpen});

  final Folder folder;
  final BrowserState state;
  final ValueChanged<Node> onOpen;

  @override
  Widget build(BuildContext context) {
    final isRoot = identical(folder, state.root);
    final count = folder.leaves.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Breadcrumb(node: folder),
        const SizedBox(height: 18),
        Text('${folder.title}/', style: mono(28, color: AppColors.folder, weight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 10),
        _Prose(
          isRoot
              ? 'Every topic from Antti Laaksonen\'s Competitive Programmer\'s Handbook, '
                  'organized by part and chapter. Search by situation with `/`, '
                  'or press `p` when you\'re stuck.'
              : '$count ${count == 1 ? 'approach' : 'approaches'}. Pick one, or press `→` to open the folder.',
          style: sans(16, color: AppColors.muted, height: 1.5),
        ),
        _Section(
          'contents',
          child: Column(
            children: [for (final child in folder.children) _ContentsLine(node: child, onOpen: onOpen)],
          ),
        ),
      ],
    );
  }
}

class _ContentsLine extends StatefulWidget {
  const _ContentsLine({required this.node, required this.onOpen});

  final Node node;
  final ValueChanged<Node> onOpen;

  @override
  State<_ContentsLine> createState() => _ContentsLineState();
}

class _ContentsLineState extends State<_ContentsLine> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final (String left, String right, Color rightColor) = switch (node) {
      Leaf() => (prettyText(node.label), node.name, AppColors.approach),
      Folder() => (
          '${node.prefix == null ? '' : '${alignedPrefix(node)}  '}${node.title}/',
          '${node.leaves.length}',
          AppColors.dim,
        ),
    };
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onOpen(node),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? AppColors.selection : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  left,
                  style: mono(14, color: node is Folder ? AppColors.folder : AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Text(right, style: mono(14, color: rightColor)),
            ],
          ),
        ),
      ),
    );
  }
}
