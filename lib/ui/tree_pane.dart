import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/node.dart';
import 'browser_state.dart';
import 'text.dart';
import 'theme.dart';

/// Example searches shown under the tree.
const searchExamples = ['leaderboard', 'depends on', 'shortest', 'stuck'];

class TreePane extends StatefulWidget {
  const TreePane({
    super.key,
    required this.state,
    required this.onRowTap,
    required this.onExample,
  });

  final BrowserState state;
  final ValueChanged<Node> onRowTap;
  final ValueChanged<String> onExample;

  @override
  State<TreePane> createState() => _TreePaneState();
}

class _TreePaneState extends State<TreePane> {
  static const _padTop = 14.0;
  final _scroll = ScrollController();
  Node? _lastSelected;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
  }

  @override
  void didUpdateWidget(TreePane old) {
    super.didUpdateWidget(old);
    if (!identical(old.state, widget.state)) {
      old.state.removeListener(_onState);
      widget.state.addListener(_onState);
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    _scroll.dispose();
    super.dispose();
  }

  void _onState() {
    setState(() {});
    if (!identical(_lastSelected, widget.state.selected)) {
      _lastSelected = widget.state.selected;
      WidgetsBinding.instance.addPostFrameCallback((_) => _keepSelectionVisible());
    }
  }

  void _keepSelectionVisible() {
    final i = widget.state.selectedIndex;
    if (i < 0 || !_scroll.hasClients) return;
    final pos = _scroll.position;
    const margin = TreeGeometry.rowHeight * 2;
    final top = _padTop + i * TreeGeometry.rowHeight;
    final bottom = top + TreeGeometry.rowHeight;
    double? target;
    if (top - margin < pos.pixels) {
      target = top - margin;
    } else if (bottom + margin > pos.pixels + pos.viewportDimension) {
      target = bottom + margin - pos.viewportDimension;
    }
    if (target != null) {
      _scroll.jumpTo(target.clamp(pos.minScrollExtent, pos.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final rows = state.rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.only(top: _padTop, bottom: 24, right: 8),
            itemExtent: TreeGeometry.rowHeight,
            itemCount: rows.length,
            itemBuilder: (context, i) => _TreeRowView(
              key: ValueKey(rows[i].node.id),
              row: rows[i],
              state: state,
              onTap: widget.onRowTap,
            ),
          ),
        ),
        _Tips(onExample: widget.onExample),
      ],
    );
  }
}

/// Fixed indents, so guide lines line up whatever the font.
abstract final class TreeGeometry {
  static const rowHeight = 28.0;
  static const indent = 30.0;
  static const left = 22.0;

  static double textX(int depth) => left + depth * indent;
  static double lineX(int depth) => (textX(depth) + 5).floorToDouble() + 0.5;
}

class _TreeRowView extends StatefulWidget {
  const _TreeRowView({super.key, required this.row, required this.state, required this.onTap});

  final TreeRow row;
  final BrowserState state;
  final ValueChanged<Node> onTap;

  @override
  State<_TreeRowView> createState() => _TreeRowViewState();
}

class _TreeRowViewState extends State<_TreeRowView> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.row.node;
    final state = widget.state;
    final selected = identical(node, state.selected);
    final depth = node.depth;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTap(node),
        child: Stack(
          children: [
            if (selected || _hover)
              Positioned(
                left: 6,
                right: 0,
                top: 1,
                bottom: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected ? AppColors.selection : AppColors.selection.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            if (selected)
              const Positioned(
                left: 0,
                width: 3,
                top: 5,
                bottom: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: _GuidePainter(depth, widget.row.rails, node.isLastChild),
              ),
            ),
            Positioned.fill(
              left: TreeGeometry.textX(depth),
              right: 14,
              child: Align(
                alignment: Alignment.centerLeft,
                child: switch (node) {
                  Leaf() => _LeafLine(leaf: node, state: state),
                  Folder() => _FolderLine(folder: node, state: state),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderLine extends StatelessWidget {
  const _FolderLine({required this.folder, required this.state});

  final Folder folder;
  final BrowserState state;

  @override
  Widget build(BuildContext context) {
    if (identical(folder, state.root)) {
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: '~/', style: mono(14, color: AppColors.dim)),
          TextSpan(text: '${folder.title}/', style: mono(14, color: AppColors.folder, weight: FontWeight.w600)),
          TextSpan(text: '   ${state.leaves.length} approaches', style: mono(12.5, color: AppColors.dim)),
        ]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final dim = state.isDimmed(folder);
    final count = state.matchesIn(folder);
    return Text.rich(
      TextSpan(children: [
        if (folder.prefix != null)
          TextSpan(text: '${alignedPrefix(folder)}  ', style: mono(13, color: AppColors.dim)),
        TextSpan(
          text: '${folder.title}/',
          style: mono(14, color: dim ? AppColors.dim : AppColors.folder),
        ),
        if (state.filtering && count > 0)
          TextSpan(
            text: '   $count ${count == 1 ? 'match' : 'matches'}',
            style: mono(12.5, color: AppColors.accent),
          ),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _LeafLine extends StatelessWidget {
  const _LeafLine({required this.leaf, required this.state});

  final Leaf leaf;
  final BrowserState state;

  @override
  Widget build(BuildContext context) {
    final dim = state.isDimmed(leaf);
    final match = state.matchOf(leaf);
    final emphasis = match != null ? FontWeight.w600 : null;
    final labelStyle = mono(14,
        color: dim ? AppColors.dim : (match != null ? AppColors.bright : AppColors.text),
        weight: emphasis);
    final nameStyle = mono(14, color: dim ? AppColors.dim : AppColors.approach, weight: emphasis);
    final tag = match?.tag;
    final tagStyle = mono(13, color: AppColors.accent);
    final label = prettyText(leaf.label);

    // Widths are budgeted so the row never overflows: the approach name comes
    // first, the label gets the rest, the tag shows only if it fits whole, and
    // the dotted leader always keeps its padding.
    return LayoutBuilder(builder: (context, constraints) {
      const leader = 24.0;
      double width(String text, TextStyle style) => measureText(context, text, style).ceilToDouble() + 1;
      final nameMax = math.min(width(leaf.name, nameStyle), constraints.maxWidth * 0.6);
      final rest = math.max(0.0, constraints.maxWidth - nameMax - leader);
      final tagWidth = tag == null ? 0.0 : width('#$tag', tagStyle) + 12;
      final showTag = tag != null && width(label, labelStyle) + tagWidth <= rest;
      final labelMax = math.max(0.0, rest - (showTag ? tagWidth : 0));
      Widget line(String text, TextStyle style, double max) => ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: Text(text, style: style, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
          );
      return Row(
        children: [
          line(label, labelStyle, labelMax),
          if (showTag)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('#$tag', style: tagStyle, maxLines: 1, softWrap: false),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: leader / 2),
              child: SizedBox(
                height: 16,
                child: CustomPaint(painter: _DotsPainter(AppColors.dim.withValues(alpha: dim ? 0.35 : 0.6))),
              ),
            ),
          ),
          line(leaf.name, nameStyle, nameMax),
        ],
      );
    });
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.depth, this.rails, this.isLast);

  final int depth;
  final List<bool> rails;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    if (depth == 0) return;
    final paint = Paint()
      ..color = AppColors.guide
      ..strokeWidth = 1;
    final mid = (size.height / 2).floorToDouble() + 0.5;
    for (var i = 0; i < depth - 1 && i < rails.length; i++) {
      if (rails[i]) {
        final x = TreeGeometry.lineX(i);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
    final x = TreeGeometry.lineX(depth - 1);
    canvas.drawLine(Offset(x, 0), Offset(x, isLast ? mid : size.height), paint);
    canvas.drawLine(Offset(x, mid), Offset(TreeGeometry.textX(depth) - 8, mid), paint);
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.depth != depth || old.isLast != isLast || !_sameRails(old.rails, rails);

  static bool _sameRails(List<bool> a, List<bool> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The dotted leader between a situation and its approach.
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const gap = 6.0;
    final y = size.height - 4;
    for (var x = 1.0; x < size.width; x += gap) {
      canvas.drawCircle(Offset(x, y), 0.8, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

class _Tips extends StatelessWidget {
  const _Tips({required this.onExample});

  final ValueChanged<String> onExample;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('tip', style: mono(12, color: AppColors.muted)),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text('search by situation, not by name',
                    style: mono(12.5, color: AppColors.dim), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final e in searchExamples) _ExampleChip(text: e, onTap: () => onExample(e))],
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatefulWidget {
  const _ExampleChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<_ExampleChip> createState() => _ExampleChipState();
}

class _ExampleChipState extends State<_ExampleChip> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: _hover ? AppColors.accent : AppColors.line),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(widget.text, style: mono(13, color: _hover ? AppColors.text : AppColors.muted)),
        ),
      ),
    );
  }
}
