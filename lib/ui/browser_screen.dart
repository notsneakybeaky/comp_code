import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/node.dart';
import 'bars.dart';
import 'browser_state.dart';
import 'card_pane.dart';
import 'theme.dart';
import 'tree_pane.dart';

/// The whole window: search bar, tree, card and status bar.
///
/// Keys are handled in one place. The screen's own focus node stands for "the
/// tree has focus"; text fields inside it get key events first and only see
/// the keys they need.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key, required this.root});

  final Folder root;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final _state = BrowserState(widget.root);
  final _treeFocus = FocusNode(debugLabel: 'tree');
  final _searchFocus = FocusNode(debugLabel: 'search');
  final _query = TextEditingController();

  @override
  void dispose() {
    _state.dispose();
    _treeFocus.dispose();
    _searchFocus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _focusTree() => _treeFocus.requestFocus();

  void _focusSearch() {
    _searchFocus.requestFocus();
    _query.selection = TextSelection(baseOffset: 0, extentOffset: _query.text.length);
  }

  void _setQuery(String text) {
    if (_query.text != text) {
      _query.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }
    _state.setQuery(text);
  }

  void _open(Node node) {
    _state.reveal(node);
    _focusTree();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final focused = FocusManager.instance.primaryFocus;
    final inSearch = identical(focused, _searchFocus);
    final inOtherField = !inSearch && !identical(focused, _treeFocus);

    if (key == LogicalKeyboardKey.escape) {
      if (!inOtherField && _state.query.isNotEmpty) _setQuery('');
      _focusTree();
      return KeyEventResult.handled;
    }
    if (inOtherField) return KeyEventResult.ignored;

    if (inSearch) {
      switch (key) {
        case LogicalKeyboardKey.arrowDown:
          _state.move(1);
        case LogicalKeyboardKey.arrowUp:
          _state.move(-1);
        case LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
          _focusTree();
        default:
          return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }

    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        _state.move(1);
      case LogicalKeyboardKey.arrowUp:
        _state.move(-1);
      case LogicalKeyboardKey.pageDown:
        _state.move(10);
      case LogicalKeyboardKey.pageUp:
        _state.move(-10);
      case LogicalKeyboardKey.home:
        _state.moveToEnd(last: false);
      case LogicalKeyboardKey.end:
        _state.moveToEnd(last: true);
      case LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter:
        _state.expandOrEnter();
      case LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.backspace:
        _state.collapseOrBack();
      default:
        final char = event.character;
        if (char == '/' || key == LogicalKeyboardKey.slash || key == LogicalKeyboardKey.numpadDivide) {
          _focusSearch();
        } else if (char == 'p' || char == 'P') {
          _state.openPipeline();
        } else {
          return KeyEventResult.ignored;
        }
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _treeFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: _state,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QueryBar(
                state: _state,
                controller: _query,
                focusNode: _searchFocus,
                onChanged: _state.setQuery,
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final treeWidth = (constraints.maxWidth * 0.49).clamp(360.0, 760.0);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: treeWidth,
                        child: TreePane(
                          state: _state,
                          onRowTap: (node) {
                            _state.activate(node);
                            _focusTree();
                          },
                          onExample: (text) {
                            _setQuery(text);
                            _focusTree();
                          },
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _focusTree,
                          child: CardPane(state: _state, onOpen: _open),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              StatusBar(state: _state),
            ],
          ),
        ),
      ),
    );
  }
}
