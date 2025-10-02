import 'dart:ffi';
import 'vtz_feature.dart';
import 'vtz_bindings.dart';
import '../vtzero_dart_bindings_generated.dart';

/// Core vtzero layer wrapper - no external dependencies
class VtzLayer {
  final Pointer<VtzLayerHandle> _handle;
  final String name;
  final int extent;
  final int version;

  VtzLayer(
    this._handle, {
    required this.name,
    required this.extent,
    required this.version,
  });

  /// Get all features in this layer
  List<VtzFeature> getFeatures() {
    final features = <VtzFeature>[];

    while (true) {
      final featureHandle = bindings.vtz_layer_next_feature(_handle);
      if (featureHandle == nullptr) break;

      features.add(VtzFeature(featureHandle));
    }

    return features;
  }

  /// Get feature count without allocating feature objects
  int get featureCount {
    // Count features without creating Dart objects
    int count = 0;
    while (true) {
      final featureHandle = bindings.vtz_layer_next_feature(_handle);
      if (featureHandle == nullptr) break;
      bindings.vtz_feature_free(featureHandle);
      count++;
    }
    return count;
  }

  /// Free native resources
  void dispose() {
    bindings.vtz_layer_free(_handle);
  }

  Pointer<VtzLayerHandle> get handle => _handle;
}
