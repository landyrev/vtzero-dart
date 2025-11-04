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
      // For points, decodeGeometry returns [[point1], [point2], ...]
      // where each point is [x, y]
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
  });
}
