// ignore_for_file: avoid_print, unused_local_variable

import 'dart:io';
import 'dart:typed_data';
import 'package:vector_tile/vector_tile.dart' as vt;
import 'package:vector_tile/util/geojson.dart' as geo;
import 'package:vtzero_dart/vector_tile_adapter.dart';
import 'package:vtzero_dart/vtzero_dart.dart';

/// Performance benchmark comparing vtzero_dart adapter with vector_tile package
Future<void> main() async {
  final tilesDir = Directory('performance_test/tiles');
  if (!tilesDir.existsSync()) {
    print(
        'Error: Tiles directory not found. Please run download_tiles.dart first.');
    exit(1);
  }

  // Find all tile files (both .mvt and .pbf formats)
  final tileFiles = tilesDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mvt') || f.path.endsWith('.pbf'))
      .toList();

  if (tileFiles.isEmpty) {
    print('Error: No tile files found. Please run download_tiles.dart first.');
    exit(1);
  }

  print('Found ${tileFiles.length} tile files');
  print('Running performance benchmark...\n');

  // Load all tiles into memory
  final tiles = <MapEntry<String, Uint8List>>[];
  for (final file in tileFiles) {
    try {
      final bytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;
      tiles.add(MapEntry(fileName, bytes));
    } catch (e) {
      print('Warning: Failed to load ${file.path}: $e');
    }
  }

  if (tiles.isEmpty) {
    print('Error: No valid tiles loaded.');
    exit(1);
  }

  print('Loaded ${tiles.length} tiles\n');

  // Warmup runs to avoid JIT compilation affecting results
  print('Warming up...');
  await _warmup(tiles);
  print('Warmup complete\n');

  // Run benchmarks
  print('=' * 80);
  print('BENCHMARK RESULTS');
  print('=' * 80);
  print('');

  // Benchmark bare vtzero_dart implementation
  print('Testing bare vtzero_dart (VtzTile)...');
  final bareVtzeroResults = await _benchmarkBareVtzero(tiles);
  _printResults('bare vtzero_dart', bareVtzeroResults);

  print('');

  // Benchmark vtzero_dart adapter
  print('Testing vtzero_dart adapter (VectorTileVtzero)...');
  final vtzeroResults = await _benchmarkVtzero(tiles);
  _printResults('vtzero_dart adapter', vtzeroResults);

  print('');

  // Benchmark vector_tile package
  print('Testing vector_tile package (VectorTile)...');
  final vectorTileResults = await _benchmarkVectorTile(tiles);
  _printResults('vector_tile', vectorTileResults);

  print('');

  // Comparison
  print('=' * 80);
  print('COMPARISON');
  print('=' * 80);
  _printComparison(bareVtzeroResults, vtzeroResults, vectorTileResults);
}

/// Warmup runs to avoid JIT compilation affecting results
Future<void> _warmup(List<MapEntry<String, Uint8List>> tiles) async {
  if (tiles.isEmpty) return;

  // Use first tile for warmup
  final warmupTile = tiles.first.value;

  // Warmup bare vtzero_dart
  try {
    final vtzTile = VtzTile.fromBytes(warmupTile);
    final layers = vtzTile.getLayers();
    if (layers.isNotEmpty) {
      final features = layers.first.getFeatures();
      if (features.isNotEmpty) {
        features.first.toGeoJson(
          extent: layers.first.extent,
          tileX: 0,
          tileY: 0,
          tileZ: 0,
        );
      }
      // Dispose layers and features
      for (final layer in layers) {
        for (final feature in layer.getFeatures()) {
          feature.dispose();
        }
        layer.dispose();
      }
    }
    vtzTile.dispose();
  } catch (_) {
    // Ignore errors during warmup
  }

  // Warmup vtzero_dart adapter
  try {
    final vtzTile = VectorTileVtzero.fromBytes(bytes: warmupTile);
    if (vtzTile.layers.isNotEmpty && vtzTile.layers.first.features.isNotEmpty) {
      final feature = vtzTile.layers.first.features.first;
      feature.toGeoJson<geo.GeoJson>(
        x: 0,
        y: 0,
        z: 0,
      );
    }
  } catch (_) {
    // Ignore errors during warmup
  }

  // Warmup vector_tile
  try {
    final vtTile = vt.VectorTile.fromBytes(bytes: warmupTile);
    if (vtTile.layers.isNotEmpty && vtTile.layers.first.features.isNotEmpty) {
      final feature = vtTile.layers.first.features.first;
      feature.toGeoJson<geo.GeoJson>(
        x: 0,
        y: 0,
        z: 0,
      );
    }
  } catch (_) {
    // Ignore errors during warmup
  }
}

/// Benchmark bare vtzero_dart implementation
Future<BenchmarkResults> _benchmarkBareVtzero(
  List<MapEntry<String, Uint8List>> tiles,
) async {
  final decodeTimes = <int>[];
  final endToEndTimes = <int>[];

  for (final tileEntry in tiles) {
    final bytes = tileEntry.value;

    // Measure decoding time
    final decodeStart = DateTime.now();
    VtzTile? vtzTile;
    try {
      vtzTile = VtzTile.fromBytes(bytes);
      final decodeEnd = DateTime.now();
      final decodeMs = decodeEnd.difference(decodeStart).inMicroseconds;
      decodeTimes.add(decodeMs);

      // Measure end-to-end: decode + iterate + access properties + convert to GeoJSON
      final endToEndStart = decodeStart; // Include decoding in end-to-end

      // Extract tile coordinates from filename
      final fileName =
          tileEntry.key.replaceAll('.mvt', '').replaceAll('.pbf', '');
      int x = 0, y = 0, z = 0;
      final parts = fileName.split('-');
      if (parts.length >= 3) {
        final zIndex = parts.length - 3;
        z = int.tryParse(parts[zIndex]) ?? 0;
        x = int.tryParse(parts[zIndex + 1]) ?? 0;
        y = int.tryParse(parts[zIndex + 2]) ?? 0;
      }

      // Iterate through all layers
      final layers = vtzTile.getLayers();
      for (final layer in layers) {
        // Access layer properties
        final layerName = layer.name;
        final layerExtent = layer.extent;
        final layerVersion = layer.version;

        // Iterate through all features
        final features = layer.getFeatures();
        for (final feature in features) {
          // Access feature properties
          final geomType = feature.geometryType;
          final featureId = feature.id;

          // Get and iterate properties
          final properties = feature.getProperties();
          for (final entry in properties.entries) {
            final key = entry.key;
            final value = entry.value;
            // Access property value
            if (value != null) {
              final valueStr = value.toString();
            }
          }

          // Convert to GeoJSON
          try {
            feature.toGeoJson(
              extent: layerExtent,
              tileX: x,
              tileY: y,
              tileZ: z,
            );
          } catch (_) {
            // Skip features that fail to convert
          }

          // Dispose feature
          feature.dispose();
        }

        // Dispose layer
        layer.dispose();
      }

      final endToEndEnd = DateTime.now();
      final endToEndMs = endToEndEnd.difference(endToEndStart).inMicroseconds;
      endToEndTimes.add(endToEndMs);

      // Dispose tile
      vtzTile.dispose();
    } catch (e) {
      // Skip tiles that fail to decode
      print('Warning: Failed to decode ${tileEntry.key}: $e');
      if (vtzTile != null) {
        vtzTile.dispose();
      }
    }
  }

  return BenchmarkResults(
    decodeTimes: decodeTimes,
    endToEndTimes: endToEndTimes,
  );
}

/// Benchmark vtzero_dart adapter
Future<BenchmarkResults> _benchmarkVtzero(
  List<MapEntry<String, Uint8List>> tiles,
) async {
  final decodeTimes = <int>[];
  final endToEndTimes = <int>[];

  for (final tileEntry in tiles) {
    final bytes = tileEntry.value;

    // Measure decoding time
    final decodeStart = DateTime.now();
    VectorTileVtzero? vtzTile;
    try {
      vtzTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final decodeEnd = DateTime.now();
      final decodeMs = decodeEnd.difference(decodeStart).inMicroseconds;
      decodeTimes.add(decodeMs);

      // Measure end-to-end: decode + iterate + access properties + convert to GeoJSON
      final endToEndStart = decodeStart; // Include decoding in end-to-end

      // Extract tile coordinates from filename
      final fileName =
          tileEntry.key.replaceAll('.mvt', '').replaceAll('.pbf', '');
      int x = 0, y = 0, z = 0;
      final parts = fileName.split('-');
      if (parts.length >= 3) {
        final zIndex = parts.length - 3;
        z = int.tryParse(parts[zIndex]) ?? 0;
        x = int.tryParse(parts[zIndex + 1]) ?? 0;
        y = int.tryParse(parts[zIndex + 2]) ?? 0;
      }

      // Iterate through all layers
      for (final layer in vtzTile.layers) {
        // Access layer properties
        final layerName = layer.name;
        final layerExtent = layer.extent;
        final layerVersion = layer.version;
        final featureCount = layer.features.length;

        // Iterate through all features
        for (final feature in layer.features) {
          // Access feature properties
          final geomType = feature.type;
          final featureId = feature.id;
          final featureExtent = feature.extent;

          // Get and iterate properties
          final properties = feature.properties ?? {};
          for (final entry in properties.entries) {
            final key = entry.key;
            final value = entry.value;
            // Access property value
            final valueStr = value.toString();
          }

          // Convert to GeoJSON
          try {
            feature.toGeoJson<geo.GeoJson>(
              x: x,
              y: y,
              z: z,
            );
          } catch (_) {
            // Skip features that fail to convert
          }
        }
      }

      final endToEndEnd = DateTime.now();
      final endToEndMs = endToEndEnd.difference(endToEndStart).inMicroseconds;
      endToEndTimes.add(endToEndMs);
    } catch (e) {
      // Skip tiles that fail to decode
      print('Warning: Failed to decode ${tileEntry.key}: $e');
    }
  }

  return BenchmarkResults(
    decodeTimes: decodeTimes,
    endToEndTimes: endToEndTimes,
  );
}

/// Benchmark vector_tile package
Future<BenchmarkResults> _benchmarkVectorTile(
  List<MapEntry<String, Uint8List>> tiles,
) async {
  final decodeTimes = <int>[];
  final endToEndTimes = <int>[];

  for (final tileEntry in tiles) {
    final bytes = tileEntry.value;

    // Measure decoding time
    final decodeStart = DateTime.now();
    vt.VectorTile? vtTile;
    try {
      vtTile = vt.VectorTile.fromBytes(bytes: bytes);
      final decodeEnd = DateTime.now();
      final decodeMs = decodeEnd.difference(decodeStart).inMicroseconds;
      decodeTimes.add(decodeMs);

      // Measure end-to-end: decode + iterate + access properties + convert to GeoJSON
      final endToEndStart = decodeStart; // Include decoding in end-to-end

      // Extract tile coordinates from filename
      final fileName =
          tileEntry.key.replaceAll('.mvt', '').replaceAll('.pbf', '');
      int x = 0, y = 0, z = 0;
      final parts = fileName.split('-');
      if (parts.length >= 3) {
        final zIndex = parts.length - 3;
        z = int.tryParse(parts[zIndex]) ?? 0;
        x = int.tryParse(parts[zIndex + 1]) ?? 0;
        y = int.tryParse(parts[zIndex + 2]) ?? 0;
      }

      // Iterate through all layers
      for (final layer in vtTile.layers) {
        // Access layer properties
        final layerName = layer.name;
        final layerExtent = layer.extent;
        final layerVersion = layer.version;
        final featureCount = layer.features.length;

        // Iterate through all features
        for (final feature in layer.features) {
          // Access feature properties
          final geomType = feature.type;
          final featureId = feature.id;
          final featureExtent = feature.extent;

          // Get and iterate properties
          final properties = feature.properties ?? {};
          for (final entry in properties.entries) {
            final key = entry.key;
            final value = entry.value;
            // Access property value
            final valueStr = value.toString();
          }

          // Convert to GeoJSON
          try {
            feature.toGeoJson<geo.GeoJson>(
              x: x,
              y: y,
              z: z,
            );
          } catch (_) {
            // Skip features that fail to convert
          }
        }
      }

      final endToEndEnd = DateTime.now();
      final endToEndMs = endToEndEnd.difference(endToEndStart).inMicroseconds;
      endToEndTimes.add(endToEndMs);
    } catch (e) {
      // Skip tiles that fail to decode
      print('Warning: Failed to decode ${tileEntry.key}: $e');
    }
  }

  return BenchmarkResults(
    decodeTimes: decodeTimes,
    endToEndTimes: endToEndTimes,
  );
}

/// Print benchmark results
void _printResults(String name, BenchmarkResults results) {
  if (results.decodeTimes.isEmpty) {
    print('  No valid results');
    return;
  }

  print('  Decoding Time:');
  _printStats(results.decodeTimes);
  print('  End-to-End Time (decode + iterate + properties + GeoJSON):');
  _printStats(results.endToEndTimes);
}

/// Print statistics for a list of times (in microseconds)
void _printStats(List<int> times) {
  if (times.isEmpty) {
    print('    No data');
    return;
  }

  times.sort();
  final min = times.first;
  final max = times.last;
  final mean = times.reduce((a, b) => a + b) / times.length;
  final median = times[times.length ~/ 2];
  final p95 = times[(times.length * 0.95).floor()];
  final p99 = times[(times.length * 0.99).floor()];

  print('    Samples: ${times.length}');
  print('    Min:     ${_formatTime(min)}');
  print('    Max:     ${_formatTime(max)}');
  print('    Mean:    ${_formatTime(mean.round())}');
  print('    Median:  ${_formatTime(median)}');
  print('    P95:     ${_formatTime(p95)}');
  print('    P99:     ${_formatTime(p99)}');
}

/// Format time in microseconds to readable format
String _formatTime(int microseconds) {
  if (microseconds < 1000) {
    return '$microsecondsμs';
  } else if (microseconds < 1000000) {
    return '${(microseconds / 1000).toStringAsFixed(2)}ms';
  } else {
    return '${(microseconds / 1000000).toStringAsFixed(2)}s';
  }
}

/// Print comparison between three benchmark results
void _printComparison(
  BenchmarkResults bareVtzeroResults,
  BenchmarkResults adapterVtzeroResults,
  BenchmarkResults vectorTileResults,
) {
  if (bareVtzeroResults.decodeTimes.isEmpty ||
      adapterVtzeroResults.decodeTimes.isEmpty ||
      vectorTileResults.decodeTimes.isEmpty) {
    print('Cannot compare: missing results');
    return;
  }

  final bareDecodeMean = bareVtzeroResults.decodeTimes.reduce((a, b) => a + b) /
      bareVtzeroResults.decodeTimes.length;
  final adapterDecodeMean =
      adapterVtzeroResults.decodeTimes.reduce((a, b) => a + b) /
          adapterVtzeroResults.decodeTimes.length;
  final vectorTileDecodeMean =
      vectorTileResults.decodeTimes.reduce((a, b) => a + b) /
          vectorTileResults.decodeTimes.length;

  final bareEndToEndMean =
      bareVtzeroResults.endToEndTimes.reduce((a, b) => a + b) /
          bareVtzeroResults.endToEndTimes.length;
  final adapterEndToEndMean =
      adapterVtzeroResults.endToEndTimes.reduce((a, b) => a + b) /
          adapterVtzeroResults.endToEndTimes.length;
  final vectorTileEndToEndMean =
      vectorTileResults.endToEndTimes.reduce((a, b) => a + b) /
          vectorTileResults.endToEndTimes.length;

  print('Decoding Performance:');
  print('  bare vtzero_dart:    ${_formatTime(bareDecodeMean.round())} (mean)');
  print(
      '  adapter vtzero_dart: ${_formatTime(adapterDecodeMean.round())} (mean)');
  print(
      '  vector_tile:          ${_formatTime(vectorTileDecodeMean.round())} (mean)');
  _printSpeedup(
      'bare vtzero_dart', bareDecodeMean, 'vector_tile', vectorTileDecodeMean);
  _printSpeedup('adapter vtzero_dart', adapterDecodeMean, 'vector_tile',
      vectorTileDecodeMean);

  print('');
  print('End-to-End Performance (decode + iterate + properties + GeoJSON):');
  print(
      '  bare vtzero_dart:    ${_formatTime(bareEndToEndMean.round())} (mean)');
  print(
      '  adapter vtzero_dart: ${_formatTime(adapterEndToEndMean.round())} (mean)');
  print(
      '  vector_tile:          ${_formatTime(vectorTileEndToEndMean.round())} (mean)');
  _printSpeedup('bare vtzero_dart', bareEndToEndMean, 'vector_tile',
      vectorTileEndToEndMean);
  _printSpeedup('adapter vtzero_dart', adapterEndToEndMean, 'vector_tile',
      vectorTileEndToEndMean);
}

/// Print speedup comparison between two implementations
void _printSpeedup(String name1, double mean1, String name2, double mean2) {
  final speedup = mean2 / mean1;
  if (speedup > 1) {
    print('  $name1 is ${speedup.toStringAsFixed(2)}x faster than $name2');
  } else {
    print(
        '  $name2 is ${(1 / speedup).toStringAsFixed(2)}x faster than $name1');
  }
}

/// Benchmark results container
class BenchmarkResults {
  final List<int> decodeTimes;
  final List<int> endToEndTimes;

  BenchmarkResults({
    required this.decodeTimes,
    required this.endToEndTimes,
  });
}
