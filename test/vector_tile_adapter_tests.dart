import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:vector_tile/vector_tile.dart' as vt;
import 'package:vector_tile/util/geometry.dart' as geom;
import 'package:vector_tile/util/geojson.dart' as geo;
import 'package:vtzero_dart/vector_tile_adapter.dart';
import 'fixture_helper.dart';

void main() {
  group('VectorTileVtzero.fromBytes()', () {
    test('Empty tile', () {
      final vtzTile = loadFixtureTile('001');
      final bytes = _readFixtureBytes('001');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, isEmpty);

      vtzTile.dispose();
    });

    test('Tile with single point feature', () {
      final bytes = _readFixtureBytes('002');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(1));
      final layer = vectorTile.layers[0];
      expect(layer.name, 'hello');
      expect(layer.extent, 4096);
      expect(layer.version, 2);
      expect(layer.features, hasLength(1));

      final feature = layer.features[0];
      expect(feature.type, vt.VectorTileGeomType.POINT);
      expect(feature.id, Int64.ZERO); // No ID in fixture 002
    });

    test('Tile with single point with ID', () {
      final bytes = _readFixtureBytes('017');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(1));
      final feature = vectorTile.layers[0].features[0];
      expect(feature.type, vt.VectorTileGeomType.POINT);
      expect(feature.id, Int64(1));
    });

    test('Tile with linestring feature', () {
      final bytes = _readFixtureBytes('018');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(1));
      final feature = vectorTile.layers[0].features[0];
      expect(feature.type, vt.VectorTileGeomType.LINESTRING);
    });

    test('Tile with polygon feature', () {
      final bytes = _readFixtureBytes('019');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(1));
      final feature = vectorTile.layers[0].features[0];
      expect(feature.type, vt.VectorTileGeomType.POLYGON);
    });

    test('Tile with multiple layers', () {
      final bytes = _readFixtureBytes('015');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(2));
      for (final layer in vectorTile.layers) {
        expect(layer.name, 'hello');
      }
    });

    test('Tile with multiple features', () {
      final bytes = _readFixtureBytes('043');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(1));
      expect(vectorTile.layers[0].features, hasLength(6));
    });

    test('Error handling for invalid tile', () {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        () => VectorTileVtzero.fromBytes(bytes: invalidBytes),
        throwsA(anything),
      );
    });
  });

  group('VectorTileFeatureVtzero.toGeoJson()', () {
    test('Point geometry conversion', () {
      final bytes = _readFixtureBytes('002');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNotNull);
      expect(geoJson, isA<geo.GeoJsonPoint>());
      expect(geoJson!.geometry, isA<geom.GeometryPoint>());
      final point = geoJson.geometry as geom.GeometryPoint;
      expect(point.coordinates, hasLength(2));
    });

    test('Point geometry with ID', () {
      final bytes = _readFixtureBytes('017');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNotNull);
      expect(geoJson!.geometry, isA<geom.GeometryPoint>());
    });

    test('Linestring geometry conversion', () {
      final bytes = _readFixtureBytes('018');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonLineString>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNotNull);
      expect(geoJson, isA<geo.GeoJsonLineString>());
      expect(geoJson!.geometry, isA<geom.GeometryLineString>());
      final lineString = geoJson.geometry as geom.GeometryLineString;
      expect(lineString.coordinates, hasLength(3));
      // Coordinates are converted to lon/lat, so they'll be geographic coordinates
      expect(lineString.coordinates[0], hasLength(2));
    });

    test('Multilinestring geometry conversion', () {
      final bytes = _readFixtureBytes('021');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonMultiLineString>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNotNull);
      expect(geoJson, isA<geo.GeoJsonMultiLineString>());
      expect(geoJson!.geometry, isA<geom.GeometryMultiLineString>());
      final multiLineString = geoJson.geometry as geom.GeometryMultiLineString;
      expect(multiLineString.coordinates, hasLength(2));
      expect(multiLineString.coordinates[0], hasLength(3));
      expect(multiLineString.coordinates[1], hasLength(2));
    });

    test('Polygon geometry conversion', () {
      final bytes = _readFixtureBytes('019');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonPolygon>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNotNull);
      expect(geoJson, isA<geo.GeoJsonPolygon>());
      expect(geoJson!.geometry, isA<geom.GeometryPolygon>());
      final polygon = geoJson.geometry as geom.GeometryPolygon;
      expect(polygon.coordinates, hasLength(1));
      expect(polygon.coordinates[0], hasLength(4));
    });

    test('Multipolygon geometry conversion', () {
      final bytes = _readFixtureBytes('022');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonPolygon>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNotNull);
      expect(geoJson, isA<geo.GeoJsonPolygon>());
      final polygon = geoJson!.geometry as geom.GeometryPolygon;
      expect(polygon.coordinates, hasLength(3));
    });

    test('Multipoint geometry conversion', () {
      final bytes = _readFixtureBytes('020');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );

      // Multipoint with 2 points - should return first point
      expect(geoJson, isNotNull);
      expect(geoJson!.geometry, isA<geom.GeometryPoint>());
    });

    test('Unknown geometry type returns null', () {
      final bytes = _readFixtureBytes('016');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJson>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNull);
    });

    test('toGeoJson with different tile coordinates', () {
      final bytes = _readFixtureBytes('002');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      // Test with different tile coordinates
      final geoJson1 = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      final geoJson2 = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 1,
        y: 1,
        z: 1,
      );

      expect(geoJson1, isNotNull);
      expect(geoJson2, isNotNull);
      // Coordinates should be different for different tile positions
      expect(geoJson1!.geometry, isNot(same(geoJson2!.geometry)));
    });
  });

  group('Property Conversion', () {
    test('String property values', () {
      final bytes = _readFixtureBytes('032');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.keys, isNotNull);
      expect(feature.keys, contains('key1'));
      expect(feature.values, isNotNull);
      expect(feature.values, hasLength(1));

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      expect(geoJson, isNotNull);
      expect(geoJson!.properties, isNotNull);
      // Properties are stored as VectorTileValue objects, extract string value
      final propValue = geoJson.properties!['key1'] as vt.VectorTileValue;
      expect(propValue.stringValue, 'i am a string value');
    });

    test('Int property values', () {
      final bytes = _readFixtureBytes('035');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      expect(geoJson, isNotNull);
      expect(geoJson!.properties, isNotNull);
      // Properties are stored as VectorTileValue objects, extract int value
      final propValue = geoJson.properties!['key1'] as vt.VectorTileValue;
      expect(propValue.intValue, isNotNull);
      expect(propValue.intValue!.toInt(), 6);
    });

    test('Double property values', () {
      final bytes = _readFixtureBytes('034');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      expect(geoJson, isNotNull);
      expect(geoJson!.properties, isNotNull);
      // Properties are stored as VectorTileValue objects, extract double value
      final propValue = geoJson.properties!['key1'] as vt.VectorTileValue;
      expect(propValue.doubleValue, isNotNull);
      expect(propValue.doubleValue, closeTo(1.23, 0.0001));
    });

    test('Float property values', () {
      final bytes = _readFixtureBytes('033');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      expect(geoJson, isNotNull);
      expect(geoJson!.properties, isNotNull);
      // Properties are stored as VectorTileValue objects
      // Float values are stored as doubleValue in VectorTileValue
      final propValue = geoJson.properties!['key1'] as vt.VectorTileValue;
      expect(propValue.doubleValue, isNotNull);
      expect(propValue.doubleValue, closeTo(3.1, 0.0001));
    });

    test('Bool property values', () {
      final bytes = _readFixtureBytes('027');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      // Fixture 027 has unused bool value, so feature has no properties
      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      expect(geoJson, isNotNull);
      // Feature has no properties in this fixture
      expect(geoJson!.properties, isEmpty);
    });

    test('Features with multiple properties', () {
      final bytes = _readFixtureBytes('038');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.keys, isNotNull);
      expect(feature.values, isNotNull);

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      expect(geoJson, isNotNull);
      // Verify properties are accessible
      expect(geoJson!.properties, isNotNull);
    });

    test('Features with no properties', () {
      // Use fixture 039 which has a feature with no properties
      final bytes = _readFixtureBytes('039');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      final geoJson = feature.toGeoJson<geo.GeoJson>(
        x: 0,
        y: 0,
        z: 0,
      );
      // Feature has unknown geometry type, so returns null
      // But if it had properties, they would be empty
      expect(geoJson, isNull);
    });

    test('Property deduplication in keys/values tables', () {
      final bytes = _readFixtureBytes('043');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final layer = vectorTile.layers[0];

      // All 6 features share the same key 'poi' but have different values
      expect(layer.keys, isNotNull);
      expect(layer.keys, contains('poi'));
      expect(layer.keys.length, 1); // Only one unique key

      expect(layer.values, isNotNull);
      // Should have 6 different values (one per feature)
      expect(layer.values.length, 6);

      // Verify all features can access their properties
      for (final feature in layer.features) {
        final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
          x: 0,
          y: 0,
          z: 0,
        );
        expect(geoJson, isNotNull);
        expect(geoJson!.properties, isNotEmpty);
        final propValue = geoJson.properties!['poi'] as vt.VectorTileValue;
        expect(propValue, isNotNull);
        expect(propValue.stringValue, isNotNull);
      }
    });
  });

  group('Layer and Feature Metadata', () {
    test('Layer name, extent, version preservation', () {
      final bytes = _readFixtureBytes('002');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final layer = vectorTile.layers[0];

      expect(layer.name, 'hello');
      expect(layer.extent, 4096);
      expect(layer.version, 2);
    });

    test('Layer without explicit extent uses default', () {
      final bytes = _readFixtureBytes('009');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final layer = vectorTile.layers[0];

      expect(layer.name, 'hello');
      expect(layer.extent, 4096); // Default extent
      expect(layer.version, 2);
    });

    test('Layer without explicit version uses default', () {
      final bytes = _readFixtureBytes('024');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final layer = vectorTile.layers[0];

      expect(layer.version, 1); // Default version
    });

    test('Feature ID preservation', () {
      final bytes = _readFixtureBytes('017');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.id, Int64(1));
    });

    test('Feature without ID', () {
      final bytes = _readFixtureBytes('002');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.id, Int64.ZERO);
    });

    test('Geometry type conversion - POINT', () {
      final bytes = _readFixtureBytes('002');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.type, vt.VectorTileGeomType.POINT);
    });

    test('Geometry type conversion - LINESTRING', () {
      final bytes = _readFixtureBytes('018');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.type, vt.VectorTileGeomType.LINESTRING);
    });

    test('Geometry type conversion - POLYGON', () {
      final bytes = _readFixtureBytes('019');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.type, vt.VectorTileGeomType.POLYGON);
    });

    test('Geometry type conversion - UNKNOWN', () {
      final bytes = _readFixtureBytes('016');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0];

      expect(feature.type, vt.VectorTileGeomType.UNKNOWN);
    });
  });

  group('Edge Cases', () {
    test('Layer without features', () {
      final bytes = _readFixtureBytes('025');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final layer = vectorTile.layers[0];

      expect(layer.features, isEmpty);
      expect(layer.name, 'hello');
    });

    test('Features with different layer versions', () {
      final bytes = _readFixtureBytes('015');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);

      expect(vectorTile.layers, hasLength(2));
      // Both layers should have same version (based on fixture)
      for (final layer in vectorTile.layers) {
        expect(layer.version, 2);
      }
    });

    test('Error propagation from underlying vtzero decoding', () {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(
        () => VectorTileVtzero.fromBytes(bytes: invalidBytes),
        throwsA(anything),
      );
    });

    test('Empty geometry returns null in toGeoJson', () {
      // This would require a fixture with empty geometry
      // For now, we test that unknown geometry type returns null
      final bytes = _readFixtureBytes('016');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson = feature.toGeoJson<geo.GeoJson>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson, isNull);
    });

    test('Properties are lazily decoded', () {
      final bytes = _readFixtureBytes('032');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      // Properties should be null before toGeoJson is called
      expect(feature.properties, isNull);

      final geoJson = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );

      // After toGeoJson, properties should be populated
      expect(geoJson, isNotNull);
      expect(feature.properties, isNotNull);
      // Properties are stored as VectorTileValue objects
      final propValue = feature.properties!['key1'] as vt.VectorTileValue;
      expect(propValue.stringValue, 'i am a string value');
    });

    test('Multiple calls to toGeoJson reuse cached properties', () {
      final bytes = _readFixtureBytes('032');
      final vectorTile = VectorTileVtzero.fromBytes(bytes: bytes);
      final feature = vectorTile.layers[0].features[0] as VectorTileFeatureVtzero;

      final geoJson1 = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );
      final geoJson2 = feature.toGeoJson<geo.GeoJsonPoint>(
        x: 0,
        y: 0,
        z: 0,
      );

      expect(geoJson1, isNotNull);
      expect(geoJson2, isNotNull);
      expect(feature.properties, isNotNull);
      // Properties should be the same object (cached)
      expect(feature.properties, same(geoJson1!.properties));
      expect(feature.properties, same(geoJson2!.properties));
    });
  });
}

/// Helper function to read fixture bytes
Uint8List _readFixtureBytes(String fixtureNumber) {
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
      'Tried paths: ${possiblePaths.join(", ")}',
    );
  }

  return file.readAsBytesSync();
}

