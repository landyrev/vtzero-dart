import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'vtz_bindings.dart';
import '../vtzero_dart_bindings_generated.dart';

/// Property value type enum
enum VtzPropertyValueType {
  string,
  float,
  double,
  intValue,
  uint,
  sint,
  boolValue;

  int get value {
    switch (this) {
      case VtzPropertyValueType.string:
        return 1;
      case VtzPropertyValueType.float:
        return 2;
      case VtzPropertyValueType.double:
        return 3;
      case VtzPropertyValueType.intValue:
        return 4;
      case VtzPropertyValueType.uint:
        return 5;
      case VtzPropertyValueType.sint:
        return 6;
      case VtzPropertyValueType.boolValue:
        return 7;
    }
  }

  static VtzPropertyValueType? fromInt(int value) {
    switch (value) {
      case 1:
        return VtzPropertyValueType.string;
      case 2:
        return VtzPropertyValueType.float;
      case 3:
        return VtzPropertyValueType.double;
      case 4:
        return VtzPropertyValueType.intValue;
      case 5:
        return VtzPropertyValueType.uint;
      case 6:
        return VtzPropertyValueType.sint;
      case 7:
        return VtzPropertyValueType.boolValue;
      default:
        return null;
    }
  }
}

/// Wrapper for property value from layer value table
class VtzPropertyValue {
  final Pointer<VtzPropertyValueHandle> _handle;
  bool _disposed = false;

  VtzPropertyValue(this._handle);

  /// Get the type of this property value
  VtzPropertyValueType? get type {
    if (_disposed) return null;
    final typeValue = bindings.vtz_property_value_type(_handle);
    checkException(); // Check for exceptions after type
    if (typeValue == -1) return null;
    return VtzPropertyValueType.fromInt(typeValue);
  }

  /// Get string value (throws if not string type)
  String get stringValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final ptr = bindings.vtz_property_value_string(_handle);
    checkException(); // Check for type_exception - this will throw if wrong type
    if (ptr == nullptr) {
      // If no exception was thrown but ptr is null, it's not a string type
      throw StateError('Property value is not a string');
    }
    return ptr.cast<Utf8>().toDartString();
  }

  /// Get float value (throws if not float type)
  double get floatValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final value = bindings.vtz_property_value_float(_handle);
    checkException(); // Check for type_exception
    return value;
  }

  /// Get double value (throws if not double type)
  double get doubleValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final value = bindings.vtz_property_value_double(_handle);
    checkException(); // Check for type_exception
    return value;
  }

  /// Get int value (throws if not int type)
  int get intValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final value = bindings.vtz_property_value_int(_handle);
    checkException(); // Check for type_exception
    return value;
  }

  /// Get uint value (throws if not uint type)
  int get uintValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final value = bindings.vtz_property_value_uint(_handle);
    checkException(); // Check for type_exception
    return value;
  }

  /// Get sint value (throws if not sint type)
  int get sintValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final value = bindings.vtz_property_value_sint(_handle);
    checkException(); // Check for type_exception
    return value;
  }

  /// Get bool value (throws if not bool type)
  bool get boolValue {
    if (_disposed) throw StateError('VtzPropertyValue has been disposed');
    final value = bindings.vtz_property_value_bool(_handle);
    checkException(); // Check for type_exception
    return value;
  }

  /// Get the value as a Dart dynamic value
  dynamic get value {
    if (_disposed) return null;
    final t = type;
    if (t == null) return null;

    switch (t) {
      case VtzPropertyValueType.string:
        return stringValue;
      case VtzPropertyValueType.float:
        return floatValue;
      case VtzPropertyValueType.double:
        return doubleValue;
      case VtzPropertyValueType.intValue:
        return intValue;
      case VtzPropertyValueType.uint:
        return uintValue;
      case VtzPropertyValueType.sint:
        return sintValue;
      case VtzPropertyValueType.boolValue:
        return boolValue;
    }
  }

  /// Free native resources
  void dispose() {
    if (!_disposed) {
      bindings.vtz_property_value_free(_handle);
      _disposed = true;
    }
  }

  Pointer<VtzPropertyValueHandle> get handle => _handle;
}

