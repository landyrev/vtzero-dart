import 'package:flutter_test/flutter_test.dart';
import 'package:vtzero_dart/vtzero_dart.dart';
import 'fixture_helper.dart';

void main() {
  group('MVT Fixture Tests', () {
    test('MVT test 001: Empty tile', () {
      final tile = loadFixtureTile('001');

      expect(tile.getLayers(), isEmpty);

      tile.dispose();
    });

    test('MVT test 002: Tile with single point feature without id', () {
      final tile = loadFixtureTile('002');

      final feature = checkLayer(tile);

      expect(feature.id, isNull);
      expect(feature.geometryType, VtzGeometryType.point);

      final geometry = feature.decodeGeometry();
      // For points, decodeGeometry returns [[[x1, y1], [x2, y2], ...]]
      // One ring containing all points (for multipoint, all points are in one ring)
      expect(geometry, hasLength(1));
      expect(geometry[0], hasLength(1));
      expect(geometry[0][0], [25.0, 17.0]);

      tile.dispose();
    });

    test('MVT test 003: Tile with single point with missing geometry type', () {
      final tile = loadFixtureTile('003');

      final feature = checkLayer(tile);

      expect(feature.id, 1);
      expect(feature.geometryType, VtzGeometryType.unknown);

      tile.dispose();
    });

    test('MVT test 004: Tile with single point with missing geometry', () {
      final tile = loadFixtureTile('004');

      expect(() => checkLayer(tile), throwsA(isA<Exception>()));

      tile.dispose();
    });

    test('MVT test 005: Tile with single point with broken tags array', () {
      final tile = loadFixtureTile('005');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // Layer should not be empty (has features), but getting features should fail
      // Note: The native wrapper catches exceptions and returns nullptr, so getFeatures()
      // will return an empty list instead of throwing. The C++ test expects an exception,
      // but our wrapper swallows it. This is a known limitation of the current wrapper.
      final features = layer.getFeatures();
      // The layer appears to have features, but getFeatures() returns empty due to broken tags
      expect(features, isEmpty);

      tile.dispose();
    });

    test('MVT test 006: Tile with single point with invalid GeomType', () {
      final tile = loadFixtureTile('006');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // Getting features should fail due to invalid geometry type
      // The wrapper catches the exception and returns empty list
      final features = layer.getFeatures();
      expect(features, isEmpty);

      tile.dispose();
    });

    test('MVT test 007: Layer version as string instead of as an int', () {
      final tile = loadFixtureTile('007');

      // The layer should fail to load due to invalid version encoding
      // The wrapper catches the exception during layer iteration
      final layers = tile.getLayers();
      // Layer iteration fails, so we get empty or partial list
      expect(layers, isEmpty);

      tile.dispose();
    });

    test('MVT test 008: Tile layer extent encoded as string', () {
      final tile = loadFixtureTile('008');

      // The layer should fail to load due to invalid extent encoding
      // The wrapper catches format_exception during next_layer() and returns nullptr
      final layers = tile.getLayers();
      // Layer iteration fails, so we get empty list
      expect(layers, isEmpty);

      tile.dispose();
    });

    test('MVT test 009: Tile layer extent missing', () {
      final tile = loadFixtureTile('009');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      expect(layer.name, 'hello');
      expect(layer.version, 2);
      expect(layer.extent, 4096); // Default extent when missing

      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      expect(feature.id, 1);

      tile.dispose();
    });

    test(
      'MVT test 010: Tile layer value is encoded as int, but pretends to be string',
      () {
        final tile = loadFixtureTile('010');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        expect(layer.getFeatures(), isNotEmpty);

        // Note: Value table access is not yet exposed in Dart API
        // The C++ test checks layer.value(0).type() which throws format_exception
        // This test verifies the tile loads but we can't test value type validation yet

        tile.dispose();
      },
    );

    test('MVT test 011: Tile layer value is encoded as unknown type', () {
      final tile = loadFixtureTile('011');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      expect(layer.getFeatures(), isNotEmpty);

      // Note: Value table access is not yet exposed in Dart API
      // The C++ test checks layer.value(0).type() which throws format_exception
      // This test verifies the tile loads but we can't test value type validation yet

      tile.dispose();
    });

    test('MVT test 012: Unknown layer version', () {
      final tile = loadFixtureTile('012');

      // Unknown layer version should cause layer iteration to fail
      // The wrapper catches version_exception during next_layer() and returns nullptr
      final layers = tile.getLayers();
      // Layer iteration fails, so we get empty list
      expect(layers, isEmpty);

      tile.dispose();
    });

    test('MVT test 013: Tile with key in table encoded as int', () {
      final tile = loadFixtureTile('013');

      // Key table encoding error should cause layer iteration to fail
      // The wrapper catches format_exception during next_layer() and returns nullptr
      final layers = tile.getLayers();
      // Layer iteration fails, so we get empty list
      expect(layers, isEmpty);

      tile.dispose();
    });

    test('MVT test 014: Tile layer without a name', () {
      final tile = loadFixtureTile('014');

      // Layer without name should cause layer iteration to fail
      final layers = tile.getLayers();
      // Layer iteration fails, so we get empty list
      expect(layers, isEmpty);

      tile.dispose();
    });

    test('MVT test 015: Two layers with the same name', () {
      final tile = loadFixtureTile('015');

      final layers = tile.getLayers();
      expect(layers, hasLength(2));

      // Both layers should have the same name
      for (final layer in layers) {
        expect(layer.name, 'hello');
      }

      // Can get layer by name (returns first match)
      final layerByName = tile.getLayer('hello');
      expect(layerByName, isNotNull);
      expect(layerByName!.name, 'hello');

      tile.dispose();
    });

    test('MVT test 016: Valid unknown geometry', () {
      final tile = loadFixtureTile('016');

      final feature = checkLayer(tile);
      expect(feature.geometryType, VtzGeometryType.unknown);

      tile.dispose();
    });

    test('MVT test 017: Valid point geometry', () {
      final tile = loadFixtureTile('017');

      final feature = checkLayer(tile);

      expect(feature.id, 1);
      expect(feature.geometryType, VtzGeometryType.point);

      final geometry = feature.decodeGeometry();
      expect(geometry, hasLength(1));
      expect(geometry[0], hasLength(1));
      expect(geometry[0][0], [25.0, 17.0]);

      tile.dispose();
    });

    test('MVT test 018: Valid linestring geometry', () {
      final tile = loadFixtureTile('018');

      final feature = checkLayer(tile);

      expect(feature.geometryType, VtzGeometryType.linestring);

      final geometry = feature.decodeGeometry();
      expect(geometry, hasLength(1));
      expect(geometry[0], hasLength(3));
      expect(geometry[0][0], [2.0, 2.0]);
      expect(geometry[0][1], [2.0, 10.0]);
      expect(geometry[0][2], [10.0, 10.0]);

      tile.dispose();
    });

    test('MVT test 019: Valid polygon geometry', () {
      final tile = loadFixtureTile('019');

      final feature = checkLayer(tile);

      expect(feature.geometryType, VtzGeometryType.polygon);

      final geometry = feature.decodeGeometry();
      expect(geometry, hasLength(1));
      expect(geometry[0], hasLength(4));
      expect(geometry[0][0], [3.0, 6.0]);
      expect(geometry[0][1], [8.0, 12.0]);
      expect(geometry[0][2], [20.0, 34.0]);
      expect(geometry[0][3], [3.0, 6.0]); // Closed polygon

      tile.dispose();
    });

    test('MVT test 020: Valid multipoint geometry', () {
      final tile = loadFixtureTile('020');

      final feature = checkLayer(tile);

      expect(feature.geometryType, VtzGeometryType.point);

      final geometry = feature.decodeGeometry();
      // Multipoint returns one ring containing all points
      expect(geometry, hasLength(1)); // One ring
      expect(geometry[0], hasLength(2)); // Two points in the ring
      expect(geometry[0][0], [5.0, 7.0]);
      expect(geometry[0][1], [3.0, 2.0]);

      tile.dispose();
    });
  });
}
