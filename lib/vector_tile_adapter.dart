// Optional compatibility layer for vector_tile package
// Only import this if you need vector_tile API compatibility

import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:vector_tile/vector_tile.dart' as vt;
import 'package:vector_tile/util/geometry.dart' as geom;
import 'package:vector_tile/util/geojson.dart' as geo;
import 'src/vtz_tile.dart';
import 'src/vtz_geometry_type.dart';

/// Fast VectorTileFeature that uses native toGeoJson
class VectorTileFeatureVtzero extends vt.VectorTileFeature {
  // Cache the native-decoded geometry coordinates
  final List<List<List<double>>> Function(int x, int y, int z) _geometryDecoder;
  final VtzGeometryType _geometryTypeVtz;

  VectorTileFeatureVtzero({
    required List<List<List<double>>> Function(int x, int y, int z)
        geometryDecoder,
    required VtzGeometryType geometryTypeVtz,
    required int super.extent,
    required super.id,
    required super.tags,
    required super.type,
    required super.geometryList,
    required super.keys,
    required super.values,
  })  : _geometryDecoder = geometryDecoder,
        _geometryTypeVtz = geometryTypeVtz;

  /// Optimized toGeoJson using native code
  @override
  T? toGeoJson<T extends geo.GeoJson>({
    required int x,
    required int y,
    required int z,
  }) {
    // Decode geometry using native optimized path
    final coords = _geometryDecoder(x, y, z);

    // Decode properties if not already done
    if (properties == null) {
      properties = {};
      for (int i = 0; i < tags.length; i += 2) {
        final keyIndex = tags[i];
        final valueIndex = tags[i + 1];
        if (keys != null &&
            values != null &&
            keyIndex < keys!.length &&
            valueIndex < values!.length) {
          properties![keys![keyIndex]] = values![valueIndex];
        }
      }
    }

    // Convert to appropriate GeoJson type based on geometry type
    switch (_geometryTypeVtz) {
      case VtzGeometryType.point:
        if (coords.isEmpty || coords.first.isEmpty) {
          return null;
        }
        final point = coords.first.first;
        return geo.GeoJsonPoint(
          geometry: geom.GeometryPoint(coordinates: point),
          properties: properties,
        ) as T;

      case VtzGeometryType.linestring:
        if (coords.isEmpty) return null;
        if (coords.length == 1) {
          return geo.GeoJsonLineString(
            geometry: geom.GeometryLineString(coordinates: coords.first),
            properties: properties,
          ) as T;
        } else {
          return geo.GeoJsonMultiLineString(
            geometry: geom.GeometryMultiLineString(coordinates: coords),
            properties: properties,
          ) as T;
        }

      case VtzGeometryType.polygon:
        if (coords.isEmpty) return null;
        return geo.GeoJsonPolygon(
          geometry: geom.GeometryPolygon(coordinates: coords),
          properties: properties,
        ) as T;

      default:
        return null;
    }
  }
}

/// Fast VectorTileLayer that creates VectorTileFeatureVtzero
class VectorTileLayerVtzero extends vt.VectorTileLayer {
  VectorTileLayerVtzero({
    required super.name,
    required super.extent,
    required super.version,
    required super.keys,
    required super.values,
    required super.features,
  });
}

/// Fast VectorTile using vtzero backend
class VectorTileVtzero extends vt.VectorTile {
  VectorTileVtzero({required super.layers});

  /// Create from bytes using vtzero decoder
  static VectorTileVtzero fromBytes({required Uint8List bytes}) {
    final vtzTile = VtzTile.fromBytes(bytes);
    final layers = <vt.VectorTileLayer>[];

    try {
      final vtzLayers = vtzTile.getLayers();

      for (final vtzLayer in vtzLayers) {
        final features = <vt.VectorTileFeature>[];
        final keys = <String>[];
        final values = <vt.VectorTileValue>[];

        final vtzFeatures = vtzLayer.getFeatures();

        for (final vtzFeature in vtzFeatures) {
          // Get properties and build keys/values tables
          final props = vtzFeature.getProperties();
          final tags = <int>[];

          props.forEach((key, value) {
            // Add key to keys table if not exists
            int keyIndex = keys.indexOf(key);
            if (keyIndex == -1) {
              keyIndex = keys.length;
              keys.add(key);
            }

            // Add value to values table if not exists
            final vtValue = _convertValue(value);
            int valueIndex = values.indexWhere((v) => _valuesEqual(v, vtValue));
            if (valueIndex == -1) {
              valueIndex = values.length;
              values.add(vtValue);
            }

            // Add key-value pair as tags
            tags.add(keyIndex);
            tags.add(valueIndex);
          });

          // Convert geometry type
          vt.VectorTileGeomType? vtType;
          switch (vtzFeature.geometryType) {
            case VtzGeometryType.point:
              vtType = vt.VectorTileGeomType.POINT;
              break;
            case VtzGeometryType.linestring:
              vtType = vt.VectorTileGeomType.LINESTRING;
              break;
            case VtzGeometryType.polygon:
              vtType = vt.VectorTileGeomType.POLYGON;
              break;
            default:
              vtType = vt.VectorTileGeomType.UNKNOWN;
          }

          // Create closure that captures feature for lazy geometry decoding
          final layerExtent = vtzLayer.extent;
          final geomType = vtzFeature.geometryType;

          // Create optimized feature with geometry decoder closure
          features.add(
            VectorTileFeatureVtzero(
              geometryDecoder: (int x, int y, int z) {
                return vtzFeature.toGeoJson(
                  extent: layerExtent,
                  tileX: x,
                  tileY: y,
                  tileZ: z,
                );
              },
              geometryTypeVtz: geomType,
              extent: vtzLayer.extent,
              id: vtzFeature.id != null ? Int64(vtzFeature.id!) : Int64.ZERO,
              tags: tags,
              type: vtType,
              geometryList: [], // Not needed - we use native toGeoJson
              keys: keys,
              values: values,
            ),
          );
        }

        layers.add(
          VectorTileLayerVtzero(
            name: vtzLayer.name,
            extent: vtzLayer.extent,
            version: vtzLayer.version,
            keys: keys,
            values: values,
            features: features,
          ),
        );

        // DON'T dispose features or layers - they're kept alive via closures
        // vtzLayer.dispose();
      }

      // DON'T dispose tile - features still reference it via closures
      // Note: The native objects stay in memory until VectorTileVtzero is garbage collected
      // vtzTile.dispose();
      return VectorTileVtzero(layers: layers);
    } catch (e) {
      // Only dispose tile on error - features/layers are already consumed
      vtzTile.dispose();
      rethrow;
    }
  }
}

// Helper functions
vt.VectorTileValue _convertValue(dynamic value) {
  if (value is String) {
    return vt.VectorTileValue(stringValue: value);
  } else if (value is int) {
    return vt.VectorTileValue(intValue: Int64(value));
  } else if (value is double) {
    return vt.VectorTileValue(doubleValue: value);
  } else if (value is bool) {
    return vt.VectorTileValue(boolValue: value);
  } else {
    return vt.VectorTileValue(stringValue: value.toString());
  }
}

bool _valuesEqual(vt.VectorTileValue a, vt.VectorTileValue b) {
  if (a.stringValue != null && b.stringValue != null) {
    return a.stringValue == b.stringValue;
  }
  if (a.intValue != null && b.intValue != null) {
    return a.intValue == b.intValue;
  }
  if (a.doubleValue != null && b.doubleValue != null) {
    return a.doubleValue == b.doubleValue;
  }
  if (a.boolValue != null && b.boolValue != null) {
    return a.boolValue == b.boolValue;
  }
  return false;
}
