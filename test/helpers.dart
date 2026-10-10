import 'dart:io';

import 'package:approach_tree/data/topic_parser.dart';
import 'package:approach_tree/models/node.dart';

/// Loads the real topic files the same way the app does, but from disk.
Folder loadFromDisk() {
  final files = Directory('assets/topics')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return TopicParser.buildTree({
    for (final f in files) f.uri.pathSegments.last: f.readAsStringSync(),
  });
}
