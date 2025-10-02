import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vtzero_dart/vtzero_dart.dart';
import 'package:vtzero_dart/vector_tile_adapter.dart';
import 'package:vector_tile/util/geometry.dart' as geom;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String tileInfo = 'Loading tile...';

  @override
  void initState() {
    super.initState();
    _testVtzero();
  }

  Future<void> _testVtzero() async {
    try {
      // Load the test tile from assets
      final ByteData data = await rootBundle.load('assets/chart.pbf');
      final Uint8List bytes = data.buffer.asUint8List();

      // Build info string
      final buffer = StringBuffer();
      buffer.writeln('✓ Tile loaded successfully!');
      buffer.writeln('Tile size: ${bytes.length} bytes');
      buffer.writeln('First byte: 0x${bytes[0].toRadixString(16)}\n');

      // Decode the tile
      final tile = VtzTile.fromBytes(bytes);
      buffer.writeln('✓ Tile decoded successfully!\n');

      // Iterate through layers
      final layers = tile.getLayers();
      buffer.writeln('Found ${layers.length} layers:\n');

      for (final layer in layers) {
        buffer.writeln('Layer: ${layer.name}');
        buffer.writeln('  Extent: ${layer.extent}');
        buffer.writeln('  Version: ${layer.version}');

        final features = layer.getFeatures();
        buffer.writeln('  Features: ${features.length}');

        if (features.isNotEmpty) {
          final firstFeature = features.first;
          buffer.writeln('  First feature:');
          buffer.writeln('    Type: ${firstFeature.geometryType}');
          if (firstFeature.id != null) {
            buffer.writeln('    ID: ${firstFeature.id}');
          }

          final props = firstFeature.getProperties();
          if (props.isNotEmpty) {
            buffer.writeln('    Properties:');
            props.forEach((key, value) {
              buffer.writeln('      $key: $value');
            });
          }

          final geometry = firstFeature.decodeGeometry();
          if (geometry.isNotEmpty) {
            buffer.writeln('    Geometry:');
            buffer.writeln('      ${geometry.length} ring(s)/line(s)');
            if (geometry.first.isNotEmpty) {
              buffer.writeln('      First ring: ${geometry.first.length} points');
              if (geometry.first.length <= 3) {
                // Show coordinates for small geometries
                for (final point in geometry.first) {
                  buffer.writeln('        [${point[0]}, ${point[1]}]');
                }
              }
            }
          }

          firstFeature.dispose();
        }

        buffer.writeln();
        layer.dispose();
      }

      tile.dispose();

      // Test drop-in replacement with native toGeoJson
      buffer.writeln('\n--- Testing Drop-in Replacement ---\n');

      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      buffer.writeln('✓ VectorTileVtzero created!');
      buffer.writeln('Layers: ${vectorTile.layers.length}');

      if (vectorTile.layers.isNotEmpty) {
        final layer = vectorTile.layers.first;
        buffer.writeln('First layer: ${layer.name}');
        buffer.writeln('Features: ${layer.features.length}');

        if (layer.features.isNotEmpty) {
          final feature = layer.features.first;

          // This calls our optimized native toGeoJson!
          final geoJson = feature.toGeoJson(x: 0, y: 0, z: 0);

          buffer.writeln('✓ feature.toGeoJson() works!');
          buffer.writeln('Type: ${feature.type}');
          if (geoJson != null && geoJson.geometry != null) {
            buffer.writeln('Geometry type: ${geoJson.geometry!.type}');

            // Check if we got coordinates
            if (geoJson.geometry is geom.GeometryPolygon) {
              final poly = geoJson.geometry as geom.GeometryPolygon;
              buffer.writeln('Rings: ${poly.coordinates.length}');
              if (poly.coordinates.isNotEmpty && poly.coordinates.first.isNotEmpty) {
                final firstPoint = poly.coordinates.first.first;
                buffer.writeln('First point: [${firstPoint[0]}, ${firstPoint[1]}]');
              }
            }
          }
        }
      }

      setState(() {
        tileInfo = buffer.toString();
      });
    } catch (e, stackTrace) {
      setState(() {
        tileInfo = 'Error: $e\n\nStack trace:\n$stackTrace';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 14, fontFamily: 'monospace');
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('vtzero_dart Example'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'vtzero_dart - Fast Vector Tile Decoder',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  tileInfo,
                  style: textStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
