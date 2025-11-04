import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'vtz_geometry_type.dart';
import 'vtz_bindings.dart';
import '../vtzero_dart_bindings_generated.dart';

/// Core vtzero feature wrapper - no external dependencies
class VtzFeature {
  final Pointer<VtzFeatureHandle> _handle;

  VtzFeature(this._handle);

  VtzGeometryType get geometryType {
    final geomType = bindings.vtz_feature_geometry_type(_handle);
    switch (geomType) {
      case 1:
        return VtzGeometryType.point;
      case 2:
        return VtzGeometryType.linestring;
      case 3:
        return VtzGeometryType.polygon;
      default:
        return VtzGeometryType.unknown;
    }
  }

  int? get id {
    if (bindings.vtz_feature_has_id(_handle)) {
      return bindings.vtz_feature_id(_handle);
    }
    return null;
  }

  /// Get the number of properties
  int get numProperties {
    int count = 0;
    final statePtr = malloc<IntPtr>();
    statePtr.value = count.hashCode;

    final callback = Pointer.fromFunction<PropertyIndexCallbackFunction>(
      _propertyIndexCallbackStatic,
    );

    _propertyIndexCountMap[count.hashCode] = 0;

    bindings.vtz_feature_for_each_property_indexes(_handle, callback, statePtr.cast());

    final result = _propertyIndexCountMap.remove(count.hashCode) ?? 0;
    malloc.free(statePtr);
    return result;
  }

  static final Map<int, int> _propertyIndexCountMap = {};

  static void _propertyIndexCallbackStatic(
    Pointer<Void> userData,
    int keyIndex,
    int valueIndex,
  ) {
    final hashCode = userData.cast<IntPtr>().value;
    final count = _propertyIndexCountMap[hashCode] ?? 0;
    _propertyIndexCountMap[hashCode] = count + 1;
  }

  /// Get feature properties as a map
  Map<String, dynamic> getProperties() {
    final properties = <String, dynamic>{};
    final propertiesPtr = malloc<IntPtr>();
    propertiesPtr.value = properties.hashCode;

    final callback = Pointer.fromFunction<PropertyCallbackFunction>(
      _propertyCallbackStatic,
    );

    // Store properties in a global map temporarily
    _propertiesMap[properties.hashCode] = properties;

    bindings.vtz_feature_for_each_property(_handle, callback, propertiesPtr.cast());
    checkException(); // Check for exceptions during property iteration

    _propertiesMap.remove(properties.hashCode);
    malloc.free(propertiesPtr);

    return properties;
  }

  static final Map<int, Map<String, dynamic>> _propertiesMap = {};

  static void _propertyCallbackStatic(
    Pointer<Void> userData,
    Pointer<Char> keyPtr,
    int valueType,
    Pointer<Char> stringValue,
    double doubleValue,
    int intValue,
    int uintValue,
    bool boolValue,
  ) {
    final hashCode = userData.cast<IntPtr>().value;
    final properties = _propertiesMap[hashCode];
    if (properties == null) return;

    final key = keyPtr.cast<Utf8>().toDartString();

    switch (valueType) {
      case 1: // string
        properties[key] = stringValue.cast<Utf8>().toDartString();
        break;
      case 2: // float
      case 3: // double
        properties[key] = doubleValue;
        break;
      case 4: // int
      case 6: // sint
        properties[key] = intValue;
        break;
      case 5: // uint
        properties[key] = uintValue;
        break;
      case 7: // bool
        properties[key] = boolValue;
        break;
    }
  }

  /// Decode geometry as list of rings/lines
  /// For points: returns [[point1], [point2], ...]
  /// For linestrings: returns [line1_points, line2_points, ...]
  /// For polygons: returns [ring1_points, ring2_points, ...] (first is outer, rest are holes)
  List<List<List<double>>> decodeGeometry() {
    final state = _GeometryState();
    final statePtr = malloc<IntPtr>();
    statePtr.value = state.hashCode;

    final callback = Pointer.fromFunction<GeometryCallbackFunction>(
      _geometryCallbackStatic,
    );

    // Store state in a global map temporarily
    _geometryStateMap[state.hashCode] = state;

    final result = bindings.vtz_feature_decode_geometry(_handle, callback, statePtr.cast());
    checkException(); // Check for exceptions and get message

    _geometryStateMap.remove(state.hashCode);
    malloc.free(statePtr);

    // Check for errors
    if (result != 0) {
      // Exception was already thrown by checkException() with proper message
      // This should not be reached, but keep as fallback
      throw Exception('Error decoding geometry');
    }

    return state.result;
  }

  static final Map<int, _GeometryState> _geometryStateMap = {};

  static void _geometryCallbackStatic(
    Pointer<Void> userData,
    int command,
    int x,
    int y,
  ) {
    final hashCode = userData.cast<IntPtr>().value;
    final state = _geometryStateMap[hashCode];
    if (state == null) return;

    switch (command) {
      case 1: // points_begin
        state.currentRing = [];
        break;
      case 2: // point
        state.currentRing.add([x.toDouble(), y.toDouble()]);
        break;
      case 3: // points_end
        if (state.currentRing.isNotEmpty) {
          state.result.add(state.currentRing);
        }
        break;
      case 4: // linestring_begin
        state.currentRing = [];
        break;
      case 5: // linestring_point
        state.currentRing.add([x.toDouble(), y.toDouble()]);
        break;
      case 6: // linestring_end
        if (state.currentRing.isNotEmpty) {
          state.result.add(state.currentRing);
        }
        break;
      case 7: // ring_begin
        state.currentRing = [];
        break;
      case 8: // ring_point
        state.currentRing.add([x.toDouble(), y.toDouble()]);
        break;
      case 9: // ring_end
        if (state.currentRing.isNotEmpty) {
          state.result.add(state.currentRing);
        }
        break;
    }
  }

  /// Convert to GeoJSON with lon/lat coordinates
  /// This is optimized - geometry is decoded and projected in native code
  List<List<List<double>>> toGeoJson({
    required int extent,
    required int tileX,
    required int tileY,
    required int tileZ,
  }) {
    final state = _GeometryState();
    final statePtr = malloc<IntPtr>();
    statePtr.value = state.hashCode;

    final callback = Pointer.fromFunction<GeoJsonCallbackFunction>(
      _geoJsonCallbackStatic,
    );

    // Store state in a global map temporarily
    _geoJsonStateMap[state.hashCode] = state;

    bindings.vtz_feature_to_geojson(
      _handle,
      extent,
      tileX,
      tileY,
      tileZ,
      callback,
      statePtr.cast(),
    );

    _geoJsonStateMap.remove(state.hashCode);
    malloc.free(statePtr);

    return state.result;
  }

  static final Map<int, _GeometryState> _geoJsonStateMap = {};

  static void _geoJsonCallbackStatic(
    Pointer<Void> userData,
    int ringType,
    double lon,
    double lat,
  ) {
    final hashCode = userData.cast<IntPtr>().value;
    final state = _geoJsonStateMap[hashCode];
    if (state == null) return;

    switch (ringType) {
      case 0: // BEGIN_RING
        state.currentRing = [];
        break;
      case 1: // POINT
        state.currentRing.add([lon, lat]);
        break;
      case 2: // END_RING
        if (state.currentRing.isNotEmpty) {
          state.result.add(state.currentRing);
        }
        break;
    }
  }

  /// Reset the property iterator to the beginning
  void resetProperty() {
    bindings.vtz_feature_reset_property(_handle);
  }

  /// Get the next property as index pair (key index, value index)
  /// Returns null if no more properties
  ({int keyIndex, int valueIndex})? nextPropertyIndexes() {
    final result = bindings.vtz_feature_next_property_indexes(_handle);
    checkException(); // Check for exceptions during property index access
    if (!result.valid) return null;
    return (keyIndex: result.key_index, valueIndex: result.value_index);
  }

  /// Call a function for each property index pair
  /// Returns true if iteration completed, false if stopped early
  bool forEachPropertyIndexes(bool Function(int keyIndex, int valueIndex) callback) {
    final statePtr = malloc<IntPtr>();
    statePtr.value = callback.hashCode;
    
    final callbackWrapper = Pointer.fromFunction<PropertyIndexCallbackFunction>(
      _forEachPropertyIndexCallbackStatic,
    );

    _propertyIndexCallbackMap[callback.hashCode] = callback;
    _propertyIndexStopMap[callback.hashCode] = false;

    final result = bindings.vtz_feature_for_each_property_indexes(
      _handle,
      callbackWrapper,
      statePtr.cast(),
    );
    checkException(); // Check for exceptions during property index iteration

    final stopped = _propertyIndexStopMap.remove(callback.hashCode) ?? false;
    _propertyIndexCallbackMap.remove(callback.hashCode);
    malloc.free(statePtr);

    return result && !stopped;
  }

  static void _forEachPropertyIndexCallbackStatic(
    Pointer<Void> userData,
    int keyIndex,
    int valueIndex,
  ) {
    final hashCode = userData.cast<IntPtr>().value;
    final cb = _propertyIndexCallbackMap[hashCode];
    if (cb != null) {
      if (!cb(keyIndex, valueIndex)) {
        _propertyIndexStopMap[hashCode] = true;
      }
    }
  }

  static final Map<int, bool Function(int, int)> _propertyIndexCallbackMap = {};
  static final Map<int, bool> _propertyIndexStopMap = {};

  void dispose() {
    bindings.vtz_feature_free(_handle);
  }

  Pointer<VtzFeatureHandle> get handle => _handle;
}

class _GeometryState {
  final List<List<List<double>>> result = [];
  List<List<double>> currentRing = [];
}
