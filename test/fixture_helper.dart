import 'dart:io';
import 'package:vtzero_dart/vtzero_dart.dart';

/// Load a fixture tile from the test fixtures directory
VtzTile loadFixtureTile(String fixtureNumber) {
  // In Flutter tests, the working directory is typically the project root
  // Try both relative and absolute paths
  final possiblePaths = [
    'test/fixtures/$fixtureNumber/tile.mvt',
    Directory.current.path + '/test/fixtures/$fixtureNumber/tile.mvt',
  ];
  
  File? file;
  for (final path in possiblePaths) {
    final candidate = File(path);
    if (candidate.existsSync()) {
      file = candidate;
      break;
    }
  }
  
  if (file == null || !file.existsSync()) {
    throw Exception(
      'Fixture file not found: test/fixtures/$fixtureNumber/tile.mvt\n'
      'Tried paths: ${possiblePaths.join(", ")}'
    );
  }
  
  final bytes = file.readAsBytesSync();
  return VtzTile.fromBytes(bytes);
}

/// Check layer properties and return the first feature
/// Matches the C++ check_layer function behavior
VtzFeature checkLayer(VtzTile tile) {
  final layers = tile.getLayers();
  
  if (layers.isEmpty) {
    throw Exception('Tile is empty - expected at least one layer');
  }
  
  if (layers.length != 1) {
    throw Exception('Expected exactly 1 layer, found ${layers.length}');
  }
  
  final layer = layers[0];
  
  if (layer.name != 'hello') {
    throw Exception('Expected layer name "hello", found "${layer.name}"');
  }
  
  if (layer.version != 2) {
    throw Exception('Expected layer version 2, found ${layer.version}');
  }
  
  if (layer.extent != 4096) {
    throw Exception('Expected layer extent 4096, found ${layer.extent}');
  }
  
  final features = layer.getFeatures();
  
  if (features.isEmpty) {
    throw Exception('Layer has no features - expected 1 feature');
  }
  
  if (features.length != 1) {
    throw Exception('Expected exactly 1 feature, found ${features.length}');
  }
  
  return features[0];
}

