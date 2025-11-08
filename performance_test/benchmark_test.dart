// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:vector_tile/vector_tile.dart' as vt;
import 'package:vector_tile/util/geojson.dart' as geo;
import 'package:vtzero_dart/vector_tile_adapter.dart';

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

  // Benchmark vtzero_dart adapter
  print('Testing vtzero_dart adapter (VectorTileVtzero)...');
  final vtzeroResults = await _benchmarkVtzero(tiles);
  _printResults('vtzero_dart', vtzeroResults);

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
  _printComparison(vtzeroResults, vectorTileResults);
}

/// Warmup runs to avoid JIT compilation affecting results
Future<void> _warmup(List<MapEntry<String, Uint8List>> tiles) async {
  if (tiles.isEmpty) return;

  // Use first tile for warmup
  final warmupTile = tiles.first.value;

  // Warmup vtzero_dart
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

/// Benchmark vtzero_dart adapter
Future<BenchmarkResults> _benchmarkVtzero(
  List<MapEntry<String, Uint8List>> tiles,
) async {
  final decodeTimes = <int>[];
  final geojsonTimes = <int>[];

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

      // Measure GeoJSON conversion time
      final geojsonStart = DateTime.now();
      for (final layer in vtzTile.layers) {
        for (final feature in layer.features) {
          try {
            // Extract tile coordinates from filename
            // Format can be: heavy-server-z-x-y.mvt or z-x-y.mvt
            final fileName =
                tileEntry.key.replaceAll('.mvt', '').replaceAll('.pbf', '');
            int x = 0, y = 0, z = 0;

            // Parse filename format: heavy-server-z-x-y or z-x-y
            final parts = fileName.split('-');
            if (parts.length >= 3) {
              // Find the last 3 parts that should be z, x, y
              final zIndex = parts.length - 3;
              z = int.tryParse(parts[zIndex]) ?? 0;
              x = int.tryParse(parts[zIndex + 1]) ?? 0;
              y = int.tryParse(parts[zIndex + 2]) ?? 0;
            }

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
      final geojsonEnd = DateTime.now();
      final geojsonMs = geojsonEnd.difference(geojsonStart).inMicroseconds;
      geojsonTimes.add(geojsonMs);
    } catch (e) {
      // Skip tiles that fail to decode
      print('Warning: Failed to decode ${tileEntry.key}: $e');
    }
  }

  return BenchmarkResults(
    decodeTimes: decodeTimes,
    geojsonTimes: geojsonTimes,
  );
}

/// Benchmark vector_tile package
Future<BenchmarkResults> _benchmarkVectorTile(
  List<MapEntry<String, Uint8List>> tiles,
) async {
  final decodeTimes = <int>[];
  final geojsonTimes = <int>[];

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

      // Measure GeoJSON conversion time
      final geojsonStart = DateTime.now();
      for (final layer in vtTile.layers) {
        for (final feature in layer.features) {
          try {
            // Extract tile coordinates from filename
            // Format can be: heavy-server-z-x-y.mvt or z-x-y.mvt
            final fileName =
                tileEntry.key.replaceAll('.mvt', '').replaceAll('.pbf', '');
            int x = 0, y = 0, z = 0;

            // Parse filename format: heavy-server-z-x-y or z-x-y
            final parts = fileName.split('-');
            if (parts.length >= 3) {
              // Find the last 3 parts that should be z, x, y
              final zIndex = parts.length - 3;
              z = int.tryParse(parts[zIndex]) ?? 0;
              x = int.tryParse(parts[zIndex + 1]) ?? 0;
              y = int.tryParse(parts[zIndex + 2]) ?? 0;
            }

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
      final geojsonEnd = DateTime.now();
      final geojsonMs = geojsonEnd.difference(geojsonStart).inMicroseconds;
      geojsonTimes.add(geojsonMs);
    } catch (e) {
      // Skip tiles that fail to decode
      print('Warning: Failed to decode ${tileEntry.key}: $e');
    }
  }

  return BenchmarkResults(
    decodeTimes: decodeTimes,
    geojsonTimes: geojsonTimes,
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
  print('  GeoJSON Conversion Time:');
  _printStats(results.geojsonTimes);
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

/// Print comparison between two benchmark results
void _printComparison(
  BenchmarkResults vtzeroResults,
  BenchmarkResults vectorTileResults,
) {
  if (vtzeroResults.decodeTimes.isEmpty ||
      vectorTileResults.decodeTimes.isEmpty) {
    print('Cannot compare: missing results');
    return;
  }

  final vtzeroDecodeMean = vtzeroResults.decodeTimes.reduce((a, b) => a + b) /
      vtzeroResults.decodeTimes.length;
  final vectorTileDecodeMean =
      vectorTileResults.decodeTimes.reduce((a, b) => a + b) /
          vectorTileResults.decodeTimes.length;

  final vtzeroGeojsonMean = vtzeroResults.geojsonTimes.reduce((a, b) => a + b) /
      vtzeroResults.geojsonTimes.length;
  final vectorTileGeojsonMean =
      vectorTileResults.geojsonTimes.reduce((a, b) => a + b) /
          vectorTileResults.geojsonTimes.length;

  print('Decoding Performance:');
  print(
    '  vtzero_dart:  ${_formatTime(vtzeroDecodeMean.round())} '
    '(mean)',
  );
  print(
    '  vector_tile:  ${_formatTime(vectorTileDecodeMean.round())} '
    '(mean)',
  );
  final decodeSpeedup = vectorTileDecodeMean / vtzeroDecodeMean;
  if (decodeSpeedup > 1) {
    print(
      '  vtzero_dart is ${decodeSpeedup.toStringAsFixed(2)}x faster',
    );
  } else {
    print(
      '  vector_tile is ${(1 / decodeSpeedup).toStringAsFixed(2)}x faster',
    );
  }

  print('');
  print('GeoJSON Conversion Performance:');
  print(
    '  vtzero_dart:  ${_formatTime(vtzeroGeojsonMean.round())} '
    '(mean)',
  );
  print(
    '  vector_tile:  ${_formatTime(vectorTileGeojsonMean.round())} '
    '(mean)',
  );
  final geojsonSpeedup = vectorTileGeojsonMean / vtzeroGeojsonMean;
  if (geojsonSpeedup > 1) {
    print(
      '  vtzero_dart is ${geojsonSpeedup.toStringAsFixed(2)}x faster',
    );
  } else {
    print(
      '  vector_tile is ${(1 / geojsonSpeedup).toStringAsFixed(2)}x faster',
    );
  }
}

/// Benchmark results container
class BenchmarkResults {
  final List<int> decodeTimes;
  final List<int> geojsonTimes;

  BenchmarkResults({
    required this.decodeTimes,
    required this.geojsonTimes,
  });
}
