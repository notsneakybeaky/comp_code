import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/loader.dart';
import 'models/node.dart';
import 'ui/browser_screen.dart';
import 'ui/theme.dart';

void main() => runApp(const ApproachTreeApp());

class ApproachTreeApp extends StatelessWidget {
  const ApproachTreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'approach-tree',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Loader(),
    );
  }
}

/// Loads the YAML topics, then shows the browser (or what went wrong).
class _Loader extends StatefulWidget {
  const _Loader();

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late final Future<Folder> _root = loadTopics(rootBundle);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _root,
      builder: (context, snapshot) {
        if (snapshot.hasData) return BrowserScreen(root: snapshot.data!);
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: snapshot.hasError
                ? SelectableText('could not load topics\n\n${snapshot.error}',
                    style: mono(14, color: AppColors.danger, height: 1.6))
                : Text('loading…', style: mono(14, color: AppColors.dim)),
          ),
        );
      },
    );
  }
}
