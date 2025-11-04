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

    test('MVT test 021: Valid multilinestring geometry', () {
      final tile = loadFixtureTile('021');

      final feature = checkLayer(tile);

      expect(feature.geometryType, VtzGeometryType.linestring);

      final geometry = feature.decodeGeometry();
      // Multilinestring returns multiple linestrings
      expect(geometry, hasLength(2)); // Two linestrings
      expect(geometry[0], hasLength(3)); // First linestring has 3 points
      expect(geometry[0][0], [2.0, 2.0]);
      expect(geometry[0][1], [2.0, 10.0]);
      expect(geometry[0][2], [10.0, 10.0]);
      expect(geometry[1], hasLength(2)); // Second linestring has 2 points
      expect(geometry[1][0], [1.0, 1.0]);
      expect(geometry[1][1], [3.0, 5.0]);

      tile.dispose();
    });

    test('MVT test 022: Valid multipolygon geometry', () {
      final tile = loadFixtureTile('022');

      final feature = checkLayer(tile);

      expect(feature.geometryType, VtzGeometryType.polygon);

      final geometry = feature.decodeGeometry();
      // Multipolygon returns multiple rings
      expect(geometry, hasLength(3)); // Three rings
      expect(geometry[0], hasLength(5)); // First ring
      expect(geometry[0][0], [0.0, 0.0]);
      expect(geometry[0][1], [10.0, 0.0]);
      expect(geometry[0][2], [10.0, 10.0]);
      expect(geometry[0][3], [0.0, 10.0]);
      expect(geometry[0][4], [0.0, 0.0]); // Closed
      expect(geometry[1], hasLength(5)); // Second ring
      expect(geometry[1][0], [11.0, 11.0]);
      expect(geometry[1][1], [20.0, 11.0]);
      expect(geometry[1][2], [20.0, 20.0]);
      expect(geometry[1][3], [11.0, 20.0]);
      expect(geometry[1][4], [11.0, 11.0]); // Closed
      expect(geometry[2], hasLength(5)); // Third ring
      expect(geometry[2][0], [13.0, 13.0]);
      expect(geometry[2][1], [13.0, 17.0]);
      expect(geometry[2][2], [17.0, 17.0]);
      expect(geometry[2][3], [17.0, 13.0]);
      expect(geometry[2][4], [13.0, 13.0]); // Closed

      tile.dispose();
    });

    test('MVT test 023: Invalid layer: missing layer name', () {
      final tile = loadFixtureTile('023');

      // Layer without name should cause layer iteration to fail
      // The wrapper catches format_exception during next_layer() and returns nullptr
      final layers = tile.getLayers();
      // Layer iteration fails, so we get empty list
      expect(layers, isEmpty);

      // Getting layer by name should also fail (returns null when layer format is invalid)
      // The wrapper catches format_exception and returns nullptr
      expect(tile.getLayer('foo'), isNull);

      tile.dispose();
    });

    test('MVT test 024: Missing layer version', () {
      final tile = loadFixtureTile('024');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // Default version is 1 when missing
      expect(layer.version, 1);

      tile.dispose();
    });

    test('MVT test 025: Layer without features', () {
      final tile = loadFixtureTile('025');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      expect(layer.getFeatures(), isEmpty);
      expect(layer.featureCount, 0);

      tile.dispose();
    });

    test('MVT test 026: Extra value type', () {
      final tile = loadFixtureTile('026');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      // Feature should be empty (no properties)
      expect(feature.getProperties(), isEmpty);

      // Note: Value table access is not yet exposed in Dart API
      // The C++ test checks layer.value_table()[0].type() which throws format_exception
      // This test verifies the tile loads but we can't test value type validation yet

      tile.dispose();
    });

    test('MVT test 027: Layer with unused bool property value', () {
      final tile = loadFixtureTile('027');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      // Feature should have no properties (unused value in table)
      expect(feature.getProperties(), isEmpty);

      // Note: Value table access is not yet exposed in Dart API
      // The C++ test checks layer.value_table()[0].bool_value()
      // This test verifies the tile loads but we can't test unused values yet

      tile.dispose();
    });

    test('MVT test 030: Two geometry fields', () {
      final tile = loadFixtureTile('030');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // Layer should not be empty, but getting features should fail
      // The wrapper catches format_exception and returns empty list
      final features = layer.getFeatures();
      expect(features, isEmpty);

      tile.dispose();
    });

    test(
      'MVT test 032: Layer with single feature with string property value',
      () {
        final tile = loadFixtureTile('032');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        final properties = feature.getProperties();
        expect(properties, hasLength(1));
        expect(properties['key1'], 'i am a string value');

        tile.dispose();
      },
    );

    test(
      'MVT test 033: Layer with single feature with float property value',
      () {
        final tile = loadFixtureTile('033');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        final properties = feature.getProperties();
        expect(properties, hasLength(1));
        expect(properties['key1'], closeTo(3.1, 0.0001));

        tile.dispose();
      },
    );

    test(
      'MVT test 034: Layer with single feature with double property value',
      () {
        final tile = loadFixtureTile('034');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        final properties = feature.getProperties();
        expect(properties, hasLength(1));
        expect(properties['key1'], closeTo(1.23, 0.0001));

        tile.dispose();
      },
    );

    test('MVT test 035: Layer with single feature with int property value', () {
      final tile = loadFixtureTile('035');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      final properties = feature.getProperties();
      expect(properties, hasLength(1));
      expect(properties['key1'], 6);

      tile.dispose();
    });

    test(
      'MVT test 036: Layer with single feature with uint property value',
      () {
        final tile = loadFixtureTile('036');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        final properties = feature.getProperties();
        expect(properties, hasLength(1));
        expect(properties['key1'], 87948);

        tile.dispose();
      },
    );

    test(
      'MVT test 037: Layer with single feature with sint property value',
      () {
        final tile = loadFixtureTile('037');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        final properties = feature.getProperties();
        expect(properties, hasLength(1));
        expect(properties['key1'], 87948);

        tile.dispose();
      },
    );

    test('MVT test 038: Layer with all types of property value', () {
      final tile = loadFixtureTile('038');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];

      // Note: Value table access is not yet exposed in Dart API
      // The C++ test checks layer.value_table() for all value types
      // This test verifies the tile loads but we can't test value table validation yet
      // However, we can verify features can be accessed

      expect(layer.getFeatures(), isNotEmpty);

      tile.dispose();
    });

    test('MVT test 039: Default values are actually encoded in the tile', () {
      final tile = loadFixtureTile('039');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      expect(layer.version, 1);
      expect(layer.name, 'hello');
      expect(layer.extent, 4096);

      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      expect(feature.id, 0);
      expect(feature.geometryType, VtzGeometryType.unknown);
      expect(feature.getProperties(), isEmpty);

      // Decoding geometry should fail for unknown geometry type
      expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

      tile.dispose();
    });

    test(
      'MVT test 040: Feature has tags that point to non-existent Key in the layer',
      () {
        final tile = loadFixtureTile('040');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        // Feature has tags pointing to non-existent key, so property access should fail
        // The wrapper catches out_of_range_exception during property iteration
        // and returns empty map (exceptions are caught silently)
        final properties = feature.getProperties();
        expect(properties, isEmpty);

        tile.dispose();
      },
    );

    test('MVT test 041: Tags encoded as floats instead of as ints', () {
      final tile = loadFixtureTile('041');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      // Tags encoded as floats should cause property access to fail
      // The wrapper catches out_of_range_exception during property iteration
      // and returns empty map (exceptions are caught silently)
      final properties = feature.getProperties();
      expect(properties, isEmpty);

      tile.dispose();
    });

    test(
      'MVT test 042: Feature has tags that point to non-existent Value in the layer',
      () {
        final tile = loadFixtureTile('042');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        // Feature has tags pointing to non-existent value, so property access should fail
        // The wrapper catches out_of_range_exception during property iteration
        // and returns empty map (exceptions are caught silently)
        final properties = feature.getProperties();
        expect(properties, isEmpty);

        tile.dispose();
      },
    );

    test(
      'MVT test 043: A layer with six points that all share the same key but each has a unique value',
      () {
        final tile = loadFixtureTile('043');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(6));

        // Check first feature
        final feature1 = features[0];
        expect(feature1, isNotNull);
        final properties1 = feature1.getProperties();
        expect(properties1, hasLength(1));
        expect(properties1['poi'], 'swing');

        // Check second feature
        final feature2 = features[1];
        expect(feature2, isNotNull);
        final properties2 = feature2.getProperties();
        expect(properties2, hasLength(1));
        expect(properties2['poi'], 'water_fountain');

        tile.dispose();
      },
    );

    test(
      'MVT test 044: Geometry field begins with a ClosePath command, which is invalid',
      () {
        final tile = loadFixtureTile('044');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to invalid ClosePath command at start
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );

    test(
      'MVT test 045: Invalid point geometry that includes a MoveTo command and only half of the xy coordinates',
      () {
        final tile = loadFixtureTile('045');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to incomplete coordinates
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );

    test(
      'MVT test 046: Invalid linestring geometry that includes two points in the same position, which is not OGC valid',
      () {
        final tile = loadFixtureTile('046');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Geometry decodes successfully even with duplicate points
        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(3));
        expect(geometry[0][0], [2.0, 2.0]);
        expect(geometry[0][1], [2.0, 10.0]);
        expect(geometry[0][2], [2.0, 10.0]); // Duplicate point

        tile.dispose();
      },
    );

    test(
      'MVT test 047: Invalid polygon with wrong ClosePath count 2 (must be count 1)',
      () {
        final tile = loadFixtureTile('047');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to invalid ClosePath count
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );

    test(
      'MVT test 048: Invalid polygon with wrong ClosePath count 0 (must be count 1)',
      () {
        final tile = loadFixtureTile('048');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to invalid ClosePath count
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );

    test(
      'MVT test 049: decoding linestring with int32 overflow in x coordinate',
      () {
        final tile = loadFixtureTile('049');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Geometry decodes successfully with int32 overflow values
        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(2));
        expect(geometry[0][0][0], 2147483647.0); // int32 max
        expect(geometry[0][0][1], 0.0);
        expect(geometry[0][1][0], -2147483648.0); // int32 min
        expect(geometry[0][1][1], 1.0);

        tile.dispose();
      },
    );

    test(
      'MVT test 050: decoding linestring with int32 overflow in y coordinate',
      () {
        final tile = loadFixtureTile('050');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Geometry decodes successfully with int32 overflow values
        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(2));
        expect(geometry[0][0][0], 0.0);
        expect(geometry[0][0][1], -2147483648.0); // int32 min
        expect(geometry[0][1][0], -1.0);
        expect(geometry[0][1][1], 2147483647.0); // int32 max

        tile.dispose();
      },
    );

    test(
      'MVT test 051: multipoint with a huge count value, useful for ensuring no over-allocation errors',
      () {
        final tile = loadFixtureTile('051');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to huge count value
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );

    test('MVT test 052: multipoint with not enough points', () {
      final tile = loadFixtureTile('052');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      expect(feature, isNotNull);

      // Decoding geometry should fail due to insufficient points
      expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

      tile.dispose();
    });

    test(
      'MVT test 053: clipped square (exact extent): a polygon that covers the entire tile to the exact boundary',
      () {
        final tile = loadFixtureTile('053');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(5));
        expect(geometry[0][0], [0.0, 0.0]);
        expect(geometry[0][1], [4096.0, 0.0]);
        expect(geometry[0][2], [4096.0, 4096.0]);
        expect(geometry[0][3], [0.0, 4096.0]);
        expect(geometry[0][4], [0.0, 0.0]); // Closed

        tile.dispose();
      },
    );

    test(
      'MVT test 054: clipped square (one unit buffer): a polygon that covers the entire tile plus a one unit buffer',
      () {
        final tile = loadFixtureTile('054');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(5));
        expect(geometry[0][0], [-1.0, -1.0]);
        expect(geometry[0][1], [4097.0, -1.0]);
        expect(geometry[0][2], [4097.0, 4097.0]);
        expect(geometry[0][3], [-1.0, 4097.0]);
        expect(geometry[0][4], [-1.0, -1.0]); // Closed

        tile.dispose();
      },
    );

    test(
      'MVT test 055: clipped square (minus one unit buffer): a polygon that almost covers the entire tile minus one unit buffer',
      () {
        final tile = loadFixtureTile('055');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(5));
        expect(geometry[0][0], [1.0, 1.0]);
        expect(geometry[0][1], [4095.0, 1.0]);
        expect(geometry[0][2], [4095.0, 4095.0]);
        expect(geometry[0][3], [1.0, 4095.0]);
        expect(geometry[0][4], [1.0, 1.0]); // Closed

        tile.dispose();
      },
    );

    test(
      'MVT test 056: clipped square (large buffer): a polygon that covers the entire tile plus a 200 unit buffer',
      () {
        final tile = loadFixtureTile('056');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        final geometry = feature.decodeGeometry();
        expect(geometry, hasLength(1));
        expect(geometry[0], hasLength(5));
        expect(geometry[0][0], [-200.0, -200.0]);
        expect(geometry[0][1], [4296.0, -200.0]);
        expect(geometry[0][2], [4296.0, 4296.0]);
        expect(geometry[0][3], [-200.0, 4296.0]);
        expect(geometry[0][4], [-200.0, -200.0]); // Closed

        tile.dispose();
      },
    );

    test(
      'MVT test 057: A point fixture with a gigantic MoveTo command. Can be used to test decoders for memory overallocation situations',
      () {
        final tile = loadFixtureTile('057');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to huge MoveTo count
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );

    test(
      'MVT test 058: A linestring fixture with a gigantic LineTo command',
      () {
        final tile = loadFixtureTile('058');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature, isNotNull);

        // Decoding geometry should fail due to huge LineTo count
        expect(() => feature.decodeGeometry(), throwsA(isA<Exception>()));

        tile.dispose();
      },
    );
  });
}
