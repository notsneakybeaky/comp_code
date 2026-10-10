import 'package:flutter/services.dart';

import '../models/node.dart';
import 'topic_parser.dart';

const topicsDir = 'assets/topics/';

/// Finds every YAML file under [topicsDir] through the asset manifest, sorted by
/// file name, and builds the tree from them.
Future<Folder> loadTopics(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith(topicsDir) && p.endsWith('.yaml'))
      .toList()
    ..sort();
  final files = <String, String>{
    for (final p in paths)
      p.substring(topicsDir.length): await bundle.loadString(p, cache: false),
  };
  return TopicParser.buildTree(files);
}
