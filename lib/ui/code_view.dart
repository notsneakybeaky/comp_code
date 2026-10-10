import 'package:flutter/material.dart';

import 'theme.dart';

/// A bordered Python code block with simple syntax highlighting. Long lines
/// scroll sideways; the scrollbar only shows when something overflows.
class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key, required this.code});

  final String code;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = mono(13, height: 1.6, spacing: 0);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bar,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 0),
            child: Text('python', textAlign: TextAlign.right, style: mono(11, color: AppColors.dim)),
          ),
          Scrollbar(
            controller: _scroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: SelectableText.rich(
                TextSpan(style: base, children: highlightPython(widget.code, base)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _keywords = {
  'and', 'as', 'assert', 'break', 'class', 'continue', 'def', 'del', 'elif', //
  'else', 'except', 'finally', 'for', 'from', 'global', 'if', 'import', 'in',
  'is', 'lambda', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'try',
  'while', 'with', 'yield', 'True', 'False', 'None',
};

final _token = RegExp(
  r'''(#[^\n]*)|("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')|(\b\d[\d_]*(?:\.\d+)?(?:e\d+)?\b)|([A-Za-z_]\w*)|(\s+|.)''',
);

/// Splits Python source into colored spans: keywords, calls, strings, numbers, comments.
List<TextSpan> highlightPython(String code, TextStyle base) {
  final spans = <TextSpan>[];
  final plain = StringBuffer();
  var afterDef = false;

  void flush() {
    if (plain.isEmpty) return;
    spans.add(TextSpan(text: plain.toString()));
    plain.clear();
  }

  void add(String text, Color color) {
    flush();
    spans.add(TextSpan(text: text, style: base.copyWith(color: color)));
  }

  for (final m in _token.allMatches(code)) {
    final text = m[0]!;
    if (m[1] != null) {
      add(text, AppColors.dim);
    } else if (m[2] != null) {
      add(text, AppColors.approach);
    } else if (m[3] != null) {
      add(text, AppColors.accent);
    } else if (m[4] != null) {
      final isCall = m.end < code.length && code[m.end] == '(';
      if (_keywords.contains(text)) {
        add(text, AppColors.folder);
      } else if (afterDef || isCall) {
        add(text, AppColors.call);
      } else {
        plain.write(text);
      }
      afterDef = text == 'def' || text == 'class';
      continue;
    } else {
      plain.write(text);
      if (text.trim().isEmpty) continue;
    }
    afterDef = false;
  }
  flush();
  return spans;
}
