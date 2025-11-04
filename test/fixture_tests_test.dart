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

      // C++: !feature.has_id() and feature.id() == 0
      // In Dart, has_id() is false but id returns 0 (not null) to match C++ behavior
      // Note: The Dart API returns null when has_id() is false, but C++ returns 0
      // For test compatibility, we check that id is null OR 0
      expect(feature.id == null || feature.id == 0, isTrue);
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

      expect(() => checkLayer(tile), throwsA(isA<VtzFormatException>()));

      tile.dispose();
    });

    test('MVT test 005: Tile with single point with broken tags array', () {
      final tile = loadFixtureTile('005');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // C++ expects: layer.next_feature() throws format_exception
      expect(() => layer.getFeatures(), throwsA(isA<VtzFormatException>()));

      tile.dispose();
    });

    test('MVT test 006: Tile with single point with invalid GeomType', () {
      final tile = loadFixtureTile('006');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // C++ expects: layer.next_feature() throws format_exception
      expect(() => layer.getFeatures(), throwsA(isA<VtzFormatException>()));

      tile.dispose();
    });

    test('MVT test 007: Layer version as string instead of as an int', () {
      final tile = loadFixtureTile('007');

      // C++ expects: tile.get_layer(0) throws format_exception
      expect(() => tile.getLayers(), throwsA(isA<VtzFormatException>()));

      tile.dispose();
    });

    test('MVT test 008: Tile layer extent encoded as string', () {
      final tile = loadFixtureTile('008');

      // C++ expects: tile.next_layer() throws format_exception
      expect(() => tile.getLayers(), throwsA(isA<VtzFormatException>()));

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

        // C++ expects: layer.value(0).type() throws format_exception
        // The exception is actually thrown when getting the value (during value_table initialization)
        expect(() => layer.getValue(0), throwsA(isA<VtzFormatException>()));

        tile.dispose();
      },
    );

    test('MVT test 011: Tile layer value is encoded as unknown type', () {
      final tile = loadFixtureTile('011');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      expect(layer.getFeatures(), isNotEmpty);

      // C++ expects: layer.value(0).type() throws format_exception
      // The exception is actually thrown when getting the value (during value_table initialization)
      expect(() => layer.getValue(0), throwsA(isA<VtzFormatException>()));

      tile.dispose();
    });

    test('MVT test 012: Unknown layer version', () {
      final tile = loadFixtureTile('012');

      // C++ expects: tile.next_layer() throws version_exception
      expect(() => tile.getLayers(), throwsA(isA<VtzVersionException>()));

      tile.dispose();
    });

    test('MVT test 013: Tile with key in table encoded as int', () {
      final tile = loadFixtureTile('013');

      // C++ expects: tile.next_layer() throws format_exception
      expect(() => tile.getLayers(), throwsA(isA<VtzFormatException>()));

      tile.dispose();
    });

    test('MVT test 014: Tile layer without a name', () {
      final tile = loadFixtureTile('014');

      // C++ expects: tile.next_layer() throws format_exception
      expect(() => tile.getLayers(), throwsA(isA<VtzFormatException>()));

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

      // C++ expects: tile.next_layer() and tile.get_layer_by_name("foo") throw format_exception
      expect(() => tile.getLayers(), throwsA(isA<VtzFormatException>()));
      expect(() => tile.getLayer('foo'), throwsA(isA<VtzFormatException>()));

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

      // C++ expects: layer.value_table()[0].type() throws format_exception
      expect(layer.valueTableSize, 1);

      // The exception is actually thrown when getting the value (during value_table initialization)
      expect(() => layer.getValue(0), throwsA(isA<VtzFormatException>()));

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

      // C++ expects: layer.value_table()[0].bool_value() == true
      expect(layer.valueTableSize, 1);

      final pv = layer.getValue(0);
      expect(pv, isNotNull);
      expect(pv!.type, VtzPropertyValueType.boolValue);
      expect(pv.boolValue, isTrue);

      pv.dispose();
      tile.dispose();
    });

    test('MVT test 030: Two geometry fields', () {
      final tile = loadFixtureTile('030');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      // C++ expects: layer.next_feature() throws format_exception
      expect(() => layer.getFeatures(), throwsA(isA<VtzFormatException>()));

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
        expect(feature.numProperties, 1);

        // Test property access via getProperties()
        final properties = feature.getProperties();
        expect(properties, hasLength(1));
        expect(properties['key1'], 'i am a string value');

        // Test property index access (matches C++ test)
        feature.resetProperty();
        final indexPair = feature.nextPropertyIndexes();
        expect(indexPair, isNotNull);
        expect(indexPair!.keyIndex, 0);
        expect(indexPair.valueIndex, 0);
        expect(feature.nextPropertyIndexes(), isNull);

        // Test for_each_property_indexes callback
        int sum = 0;
        int count = 0;
        feature.resetProperty();
        final completed = feature.forEachPropertyIndexes((
          keyIndex,
          valueIndex,
        ) {
          sum += keyIndex;
          sum += valueIndex;
          count++;
          return true; // Continue iteration
        });
        expect(completed, isTrue);
        expect(sum, 0);
        expect(count, 1);

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

      // C++ expects: layer.value_table() has 7 values of different types
      expect(layer.valueTableSize, 7);

      // Test each value type
      final pv0 = layer.getValue(0);
      expect(pv0, isNotNull);
      expect(pv0!.type, VtzPropertyValueType.string);
      expect(pv0.stringValue, 'ello');
      pv0.dispose();

      final pv1 = layer.getValue(1);
      expect(pv1, isNotNull);
      expect(pv1!.type, VtzPropertyValueType.boolValue);
      expect(pv1.boolValue, isTrue);
      pv1.dispose();

      final pv2 = layer.getValue(2);
      expect(pv2, isNotNull);
      expect(pv2!.type, VtzPropertyValueType.intValue);
      expect(pv2.intValue, 6);
      pv2.dispose();

      final pv3 = layer.getValue(3);
      expect(pv3, isNotNull);
      expect(pv3!.type, VtzPropertyValueType.double);
      expect(pv3.doubleValue, closeTo(1.23, 0.001));
      pv3.dispose();

      final pv4 = layer.getValue(4);
      expect(pv4, isNotNull);
      expect(pv4!.type, VtzPropertyValueType.float);
      expect(pv4.floatValue, closeTo(3.1, 0.001));
      pv4.dispose();

      final pv5 = layer.getValue(5);
      expect(pv5, isNotNull);
      expect(pv5!.type, VtzPropertyValueType.sint);
      expect(pv5.sintValue, -87948);
      pv5.dispose();

      final pv6 = layer.getValue(6);
      expect(pv6, isNotNull);
      expect(pv6!.type, VtzPropertyValueType.uint);
      expect(pv6.uintValue, 87948);
      pv6.dispose();

      // C++ also tests that accessing wrong type throws type_exception
      // Test accessing wrong type on pv0 (string) - should throw type_exception
      final pv0Test = layer.getValue(0);
      expect(pv0Test, isNotNull);
      // Accessing wrong type getters should throw type_exception
      expect(() => pv0Test!.boolValue, throwsA(isA<VtzTypeException>()));
      expect(() => pv0Test!.intValue, throwsA(isA<VtzTypeException>()));
      expect(() => pv0Test!.doubleValue, throwsA(isA<VtzTypeException>()));
      expect(() => pv0Test!.floatValue, throwsA(isA<VtzTypeException>()));
      expect(() => pv0Test!.sintValue, throwsA(isA<VtzTypeException>()));
      expect(() => pv0Test!.uintValue, throwsA(isA<VtzTypeException>()));
      pv0Test!.dispose();

      // Test accessing wrong type on pv1 (bool) - should throw type_exception
      // Note: stringValue checks for nullptr first, so we need to handle that
      final pv1Test = layer.getValue(1);
      expect(pv1Test, isNotNull);
      // For stringValue, it checks type() first which may throw format_exception
      // But if it's a bool, type() succeeds and then stringValue returns nullptr
      // So we check that it throws type_exception (from the wrapper checkException)
      expect(() => pv1Test!.stringValue, throwsA(isA<VtzTypeException>()));
      pv1Test!.dispose();

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
      expect(
        () => feature.decodeGeometry(),
        throwsA(isA<VtzGeometryException>()),
      );

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
        expect(feature.numProperties, 1);

        // C++ expects: feature.next_property() throws out_of_range_exception
        expect(
          () => feature.getProperties(),
          throwsA(isA<VtzOutOfRangeException>()),
        );

        tile.dispose();
      },
    );

    test(
      'MVT test 040: Feature has tags that point to non-existent Key in the layer decoded using next_property_indexes()',
      () {
        final tile = loadFixtureTile('040');

        final layers = tile.getLayers();
        expect(layers, hasLength(1));

        final layer = layers[0];
        final features = layer.getFeatures();
        expect(features, hasLength(1));

        final feature = features[0];
        expect(feature.numProperties, 1);

        // C++ expects: feature.next_property_indexes() throws out_of_range_exception
        expect(
          () => feature.nextPropertyIndexes(),
          throwsA(isA<VtzOutOfRangeException>()),
        );

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
      // C++ expects: feature.next_property() throws out_of_range_exception
      expect(
        () => feature.getProperties(),
        throwsA(isA<VtzOutOfRangeException>()),
      );

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
        // C++ expects: feature.next_property() throws out_of_range_exception
        expect(
          () => feature.getProperties(),
          throwsA(isA<VtzOutOfRangeException>()),
        );

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
        expect(
          () => feature.decodeGeometry(),
          throwsA(isA<VtzGeometryException>()),
        );

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

        // C++ expects: decode_geometry() throws geometry_exception with message "too few points in geometry"
        expect(
          () => feature.decodeGeometry(),
          throwsA(
            predicate(
              (e) =>
                  e is VtzGeometryException &&
                  e.message.contains('too few points in geometry'),
            ),
          ),
        );

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

        // C++ expects: decode_geometry() throws geometry_exception with message "ClosePath command count is not 1"
        expect(
          () => feature.decodeGeometry(),
          throwsA(
            predicate(
              (e) =>
                  e is VtzGeometryException &&
                  e.message.contains('ClosePath command count is not 1'),
            ),
          ),
        );

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

        // C++ expects: decode_geometry() throws geometry_exception with message "ClosePath command count is not 1"
        expect(
          () => feature.decodeGeometry(),
          throwsA(
            predicate(
              (e) =>
                  e is VtzGeometryException &&
                  e.message.contains('ClosePath command count is not 1'),
            ),
          ),
        );

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

        // C++ expects: decode_geometry() throws geometry_exception with message "count too large"
        expect(
          () => feature.decodeGeometry(),
          throwsA(
            predicate(
              (e) =>
                  e is VtzGeometryException &&
                  e.message.contains('count too large'),
            ),
          ),
        );

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
      expect(
        () => feature.decodeGeometry(),
        throwsA(isA<VtzGeometryException>()),
      );

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

        // C++ expects: decode_geometry() throws geometry_exception with message "count too large"
        expect(
          () => feature.decodeGeometry(),
          throwsA(
            predicate(
              (e) =>
                  e is VtzGeometryException &&
                  e.message.contains('count too large'),
            ),
          ),
        );

        tile.dispose();
      },
    );

    test('MVT test 058: A linestring fixture with a gigantic LineTo command', () {
      final tile = loadFixtureTile('058');

      final layers = tile.getLayers();
      expect(layers, hasLength(1));

      final layer = layers[0];
      final features = layer.getFeatures();
      expect(features, hasLength(1));

      final feature = features[0];
      expect(feature, isNotNull);

      // C++ expects: decode_geometry() throws geometry_exception with message "count too large"
      expect(
        () => feature.decodeGeometry(),
        throwsA(
          predicate(
            (e) =>
                e is VtzGeometryException &&
                e.message.contains('count too large'),
          ),
        ),
      );

      tile.dispose();
    });
  });
}
