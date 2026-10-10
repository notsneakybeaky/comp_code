import 'package:flutter/material.dart';

import 'browser_state.dart';
import 'theme.dart';

/// The search bar at the top. `/` focuses it.
class QueryBar extends StatelessWidget {
  const QueryBar({
    super.key,
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final BrowserState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final count = state.matchCount;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(
        color: AppColors.bar,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Text('/', style: mono(22, color: AppColors.accent, weight: FontWeight.w700)),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: mono(20, color: AppColors.bright),
              cursorColor: AppColors.accent,
              cursorWidth: 10,
              cursorHeight: 24,
              cursorRadius: Radius.zero,
              cursorOpacityAnimates: false,
              decoration: InputDecoration.collapsed(
                hintText: 'describe your situation…',
                hintStyle: mono(20, color: AppColors.dim),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text.rich(
            TextSpan(children: [
              if (state.filtering) ...[
                TextSpan(
                  text: '$count ${count == 1 ? 'match' : 'matches'}',
                  style: mono(14, color: count == 0 ? AppColors.danger : AppColors.accent, weight: FontWeight.w700),
                ),
                TextSpan(text: '  ·  searching names + tags', style: mono(14, color: AppColors.muted)),
              ] else
                TextSpan(text: 'press / to search', style: mono(14, color: AppColors.dim)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Key hints along the bottom, plus the filter summary.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.state});

  final BrowserState state;

  static const _keys = [
    ('↑↓', 'move'),
    ('→', 'open'),
    ('←', 'back'),
    ('/', 'search'),
    ('p', 'pipeline'),
    ('esc', 'clear'),
  ];

  @override
  Widget build(BuildContext context) {
    final total = state.leaves.length;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: AppColors.bar,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (key, label) in _keys) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(key, style: mono(12.5, color: AppColors.text)),
                    ),
                    const SizedBox(width: 8),
                    Text(label, style: mono(13, color: AppColors.dim)),
                    const SizedBox(width: 24),
                  ],
                ],
              ),
            ),
          ),
          Text.rich(
            TextSpan(children: [
              if (state.filtering) ...[
                TextSpan(text: 'filter ', style: mono(13, color: AppColors.dim)),
                TextSpan(text: state.query.trim(), style: mono(13, color: AppColors.accent, weight: FontWeight.w700)),
                TextSpan(text: '  ·  ${state.matchCount} / $total', style: mono(13, color: AppColors.dim)),
              ] else
                TextSpan(text: '$total approaches', style: mono(13, color: AppColors.dim)),
            ]),
          ),
        ],
      ),
    );
  }
}
