// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Downloads heavy vector tiles with depth/elevation data for performance testing
///
/// For heavier tiles with depth/elevation data, uses:
/// - VersaTiles: https://download.versatiles.org/ (bathymetry, hillshade) - No API key needed
/// - MapTiler: https://www.maptiler.com/cloud/ (free tier available) - Requires API key
///
/// To use MapTiler, set the MAPTILER_API_KEY environment variable:
///   export MAPTILER_API_KEY=your_free_api_key_here
Future<void> main() async {
  // Get API key from environment if available
  final maptilerApiKey = Platform.environment['MAPTILER_API_KEY'];

  print('Downloading heavy vector tiles with depth/elevation data...');
  print('This will download tiles from VersaTiles and other sources\n');

  if (maptilerApiKey != null && maptilerApiKey.isNotEmpty) {
    print('MapTiler API key found - will use MapTiler tiles\n');
  } else {
    print(
        'Note: Set MAPTILER_API_KEY environment variable to use MapTiler tiles');
    print('  Get a free API key at: https://www.maptiler.com/cloud/\n');
  }

  final tilesDir = Directory('performance_test/tiles');
  if (!tilesDir.existsSync()) {
    tilesDir.createSync(recursive: true);
  }

  // Use known good coordinates for major cities/regions
  // These coordinates are more likely to have tiles available
  final knownGoodCoordinates = [
    // Europe (zoom 10-12)
    {'z': 10, 'x': 512, 'y': 340}, // Central Europe
    {'z': 11, 'x': 1024, 'y': 680}, // Central Europe
    {'z': 12, 'x': 2048, 'y': 1360}, // Central Europe
    {'z': 10, 'x': 515, 'y': 343}, // Germany
    {'z': 11, 'x': 1030, 'y': 686}, // Germany
    {'z': 12, 'x': 2060, 'y': 1372}, // Germany
    {'z': 10, 'x': 510, 'y': 345}, // France
    {'z': 11, 'x': 1020, 'y': 690}, // France
    {'z': 12, 'x': 2040, 'y': 1380}, // France
    // North America (zoom 10-12)
    {'z': 10, 'x': 256, 'y': 384}, // East Coast USA
    {'z': 11, 'x': 512, 'y': 768}, // East Coast USA
    {'z': 12, 'x': 1024, 'y': 1536}, // East Coast USA
    {'z': 10, 'x': 250, 'y': 380}, // New York area
    {'z': 11, 'x': 500, 'y': 760}, // New York area
    {'z': 12, 'x': 1000, 'y': 1520}, // New York area
    {'z': 10, 'x': 200, 'y': 400}, // West Coast USA
    {'z': 11, 'x': 400, 'y': 800}, // West Coast USA
    {'z': 12, 'x': 800, 'y': 1600}, // West Coast USA
    // Asia (zoom 10-12)
    {'z': 10, 'x': 900, 'y': 400}, // Japan
    {'z': 11, 'x': 1800, 'y': 800}, // Japan
    {'z': 12, 'x': 3600, 'y': 1600}, // Japan
    {'z': 10, 'x': 850, 'y': 380}, // China
    {'z': 11, 'x': 1700, 'y': 760}, // China
    {'z': 12, 'x': 3400, 'y': 1520}, // China
  ];

  // Note: Most free tile servers require API keys or have limited availability
  // The script will try to download, but for best results, use MapTiler with API key
  final tileServers = <Map<String, String>>[];

  // Add MapTiler if API key is available (recommended - most reliable)
  if (maptilerApiKey != null && maptilerApiKey.isNotEmpty) {
    // MapTiler provides detailed vector tiles with elevation data
    // Format: https://api.maptiler.com/tiles/v3/{z}/{x}/{y}.pbf?key={key}
    tileServers.addAll([
      {
        'name': 'MapTiler Terrain',
        'url': 'https://api.maptiler.com/tiles/v3',
        'description': 'Detailed terrain with elevation data',
        'requiresKey': 'true',
        'apiKey': maptilerApiKey,
        'extension': 'pbf',
        'useKnownCoords': 'true',
      },
    ]);
  }

  if (tileServers.isEmpty) {
    print(
        'No tile servers available. Please set MAPTILER_API_KEY to download tiles.');
    print('Get a free API key at: https://www.maptiler.com/cloud/');
    print('');
    print(
        'Alternatively, you can manually add tiles to performance_test/tiles/');
    print('The benchmark will use any .mvt or .pbf files in that directory.');
    exit(0);
  }

  final random = Random();
  final downloadedTiles = <String>[];
  int attempts = 0;
  const maxAttempts = 3000; // Try more attempts for heavier tiles
  const targetCount = 1000; // Download 100 heavy tiles

  // Try each tile server
  for (final server in tileServers) {
    if (downloadedTiles.length >= targetCount) break;

    print('\nTrying ${server['name']}...');
    print('  ${server['description']}');

    final tileServerUrl = server['url'] as String;
    final requiresKey = server['requiresKey'] == 'true';
    final apiKey = server['apiKey'];
    int serverAttempts = 0;
    const maxServerAttempts = 150;

    while (downloadedTiles.length < targetCount &&
        serverAttempts < maxServerAttempts &&
        attempts < maxAttempts) {
      attempts++;
      serverAttempts++;

      // Use known good coordinates or generate random ones
      int z, x, y;
      if (server['useKnownCoords'] == 'true' &&
          knownGoodCoordinates.isNotEmpty) {
        // Use known good coordinates
        final coord =
            knownGoodCoordinates[random.nextInt(knownGoodCoordinates.length)];
        z = coord['z']!;
        x = coord['x']!;
        y = coord['y']!;

        // Add some variation around known coordinates
        final variation = 5;
        x += random.nextInt(variation * 2) - variation;
        y += random.nextInt(variation * 2) - variation;
        x = x.clamp(0, (1 << z) - 1);
        y = y.clamp(0, (1 << z) - 1);
      } else {
        // Generate random coordinates
        z = 10 + random.nextInt(5); // 10-14
        final maxCoord = 1 << z;
        x = random.nextInt(maxCoord);
        y = random.nextInt(maxCoord);
      }

      final tileKey = '$z/$x/$y';
      final serverName = server['name']!.toLowerCase().replaceAll(' ', '-');
      final extension = server['extension'] ?? (requiresKey ? 'pbf' : 'mvt');
      final tilePath = '${tilesDir.path}/heavy-$serverName-$z-$x-$y.$extension';

      // Skip if already downloaded
      if (File(tilePath).existsSync()) {
        continue;
      }

      try {
        // Build URL
        var urlString = '$tileServerUrl/$tileKey.$extension';
        if (requiresKey && apiKey != null) {
          urlString += '?key=$apiKey';
        }
        final url = Uri.parse(urlString);
        stdout.write('  [$serverAttempts] Downloading $tileKey...');

        final response = await http.get(url).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Request timeout');
          },
        );

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          // Check if it's a valid tile (larger files indicate more data)
          if (response.bodyBytes.length > 500) {
            final file = File(tilePath);
            await file.writeAsBytes(response.bodyBytes);
            downloadedTiles.add(tileKey);
            final sizeKB =
                (response.bodyBytes.length / 1024).toStringAsFixed(1);
            print(' ✓ Saved (${sizeKB}KB)');
          } else {
            print(' ✗ Too small (${response.bodyBytes.length} bytes)');
          }
        } else if (response.statusCode == 404) {
          print(' ✗ Not found');
        } else {
          print(' ✗ HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (e is TimeoutException) {
          print(' ✗ Timeout');
        } else {
          print(' ✗ Error: ${e.toString().split('\n').first}');
        }
      }

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 200));
    }

    print(
        '  Downloaded ${downloadedTiles.length} tiles from ${server['name']}');
  }

  // Count total tiles available
  final totalTiles = tilesDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.mvt') || f.path.endsWith('.pbf'))
      .length;

  print('\n=== Download Summary ===');
  print('Total tiles downloaded: ${downloadedTiles.length}');
  print('Total tiles available: $totalTiles');
  print('Tiles directory: ${tilesDir.path}');

  if (downloadedTiles.length < targetCount) {
    print(
        '\nWarning: Only downloaded ${downloadedTiles.length} tiles out of $targetCount requested.');
    print(
        'Some tiles may not exist on the servers or may have failed to download.');
  }

  print('');
  print('You can now run the benchmark with:');
  print('  dart run performance_test/benchmark_test.dart');
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
