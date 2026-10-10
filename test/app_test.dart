import 'package:approach_tree/models/node.dart';
import 'package:approach_tree/ui/browser_screen.dart';
import 'package:approach_tree/ui/browser_state.dart';
import 'package:approach_tree/ui/card_pane.dart';
import 'package:approach_tree/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final root = loadFromDisk();

  void useWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  testWidgets('search, keys and links work end to end', (tester) async {
    // Wide enough for tags to fit beside labels in the (wide-glyph) test font.
    useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: BrowserScreen(root: root)));
    await tester.pump();

    expect(rich('approaches/'), findsWidgets);
    expect(rich('press / to search'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'leaderboard');
    await tester.pump();
    expect(rich('2 matches'), findsWidgets); // search bar and the folders that hold them
    expect(rich('filter leaderboard'), findsOneWidget);
    expect(find.text('#leaderboard'), findsWidgets); // shown where it fits beside the label
    expect(rich('Keep only the k best while data streams in.'), findsOneWidget);
    expect(find.text('✓ fits'), findsOneWidget);
    expect(find.text('≈ 3.3 × 10⁷ steps'), findsOneWidget);

    // ↓ in the search field steps to the next match.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(rich('who is k-th?'), findsOneWidget);

    // esc clears the filter and returns focus to the tree.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(rich('press / to search'), findsOneWidget);
    expect(rich('who is k-th?'), findsOneWidget, reason: 'selection survives clearing');

    // p jumps to the pipeline.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pump();
    expect(find.text('find the waste'), findsOneWidget);

    // Links in INSTEAD, IF… open the target card.
    final link = find.text('size table').last; // the card's link, not the tree row
    await tester.ensureVisible(link);
    await tester.pump();
    await tester.tap(link);
    await tester.pump();
    expect(find.text('n ≤ 10'), findsOneWidget);

    // ← goes up to the folder, → steps back in.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text('toolkit/'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('find the waste'), findsOneWidget);
  });

  testWidgets('the size calculator reacts to typed sizes', (tester) async {
    useWindow(tester, const Size(1320, 860));
    final state = BrowserState(root);
    final heap = state.leafById('heap')!;
    state.reveal(heap);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: CardPane(state: state, onOpen: state.reveal)),
    ));

    expect(find.text('✓ fits'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '10,000,000'), '1e12');
    await tester.pump();
    expect(find.text('✗ too slow'), findsOneWidget);
    expect(state.sizeOf(heap, 'n'), 1e12);

    await tester.enterText(find.widgetWithText(TextField, '1e12'), 'oops');
    await tester.pump();
    expect(find.text('✗ too slow'), findsOneWidget, reason: 'keeps the last valid value');
  });

  testWidgets('every card renders without layout errors', (tester) async {
    for (final size in const [Size(620, 900), Size(380, 900)]) {
      useWindow(tester, size);
      final state = BrowserState(root);
      final nodes = <Node>[root, ...root.children, ...root.leaves];
      for (final node in nodes) {
        state.reveal(node);
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: Scaffold(body: CardPane(state: state, onOpen: state.reveal)),
        ));
        expect(tester.takeException(), isNull, reason: '${node.id} at $size');
      }
    }
  });

  testWidgets('the tree renders while browsing and filtering', (tester) async {
    useWindow(tester, const Size(1320, 860));
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: BrowserScreen(root: root)));
    for (var i = 0; i < 60; i++) {
      await tester.sendKeyEvent(i % 7 == 0 ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    for (final query in ['shortest', 'depends on', 'stuck', 'zzz', 'a']) {
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, query);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
