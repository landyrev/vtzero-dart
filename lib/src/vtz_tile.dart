import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'vtz_layer.dart';
import 'vtz_bindings.dart';
import '../vtzero_dart_bindings_generated.dart';

/// Core vtzero tile wrapper - no external dependencies
class VtzTile {
  final Pointer<VtzTileHandle> _handle;
  bool _disposed = false;

  VtzTile._(this._handle);

  /// Decode vector tile from raw bytes
  static VtzTile fromBytes(Uint8List bytes) {
    final dataPtr = malloc<Uint8>(bytes.length);
    final nativeBytes = dataPtr.asTypedList(bytes.length);
    nativeBytes.setAll(0, bytes);

    final handle = bindings.vtz_tile_create(dataPtr, bytes.length);

    malloc.free(dataPtr);

    if (handle == nullptr) {
      throw Exception('Failed to create tile from bytes');
    }

    return VtzTile._(handle);
  }

  /// Get all layers in this tile
  List<VtzLayer> getLayers() {
    _checkDisposed();
    final layers = <VtzLayer>[];

    while (true) {
      final layerHandle = bindings.vtz_tile_next_layer(_handle);
      if (layerHandle == nullptr) break;

      final namePtr = bindings.vtz_layer_name(layerHandle);
      final name = namePtr.cast<Utf8>().toDartString();
      final extent = bindings.vtz_layer_extent(layerHandle);
      final version = bindings.vtz_layer_version(layerHandle);

      layers.add(VtzLayer(
        layerHandle,
        name: name,
        extent: extent,
        version: version,
      ));
    }

    return layers;
  }

  /// Get layer by name
  VtzLayer? getLayer(String name) {
    _checkDisposed();
    final namePtr = name.toNativeUtf8();
    final layerHandle = bindings.vtz_tile_get_layer_by_name(_handle, namePtr.cast());
    malloc.free(namePtr);

    if (layerHandle == nullptr) {
      return null;
    }

    final layerNamePtr = bindings.vtz_layer_name(layerHandle);
    final layerName = layerNamePtr.cast<Utf8>().toDartString();
    final extent = bindings.vtz_layer_extent(layerHandle);
    final version = bindings.vtz_layer_version(layerHandle);

    return VtzLayer(
      layerHandle,
      name: layerName,
      extent: extent,
      version: version,
    );
  }

  /// Free native resources
  void dispose() {
    if (!_disposed) {
      bindings.vtz_tile_free(_handle);
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('VtzTile has been disposed');
    }
  }

  Pointer<VtzTileHandle> get handle => _handle;
}
