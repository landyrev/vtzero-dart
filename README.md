# vtzero_dart

A Dart/Flutter FFI wrapper around the [vtzero](https://github.com/mapbox/vtzero) C++ library for decoding Mapbox Vector Tiles (MVT).

## Overview

`vtzero_dart` provides Dart bindings to the vtzero C++ library, a minimalist and efficient implementation of the [Mapbox Vector Tile Specification 2.x](https://www.mapbox.com/vector-tiles/specification). This enables decoding vector tile data directly in Dart/Flutter applications using native code.

## Features

- **Native Performance**: Direct FFI bindings to C++ for tile decoding
- **Cross-Platform**: Supports Android (API 24+) and iOS (13.0+)
- **Minimal Dependencies**: Leverages the lightweight vtzero library
- **Two API Styles**:
  - **Core API**: Direct vtzero interface with manual memory management
  - **Adapter API**: Drop-in replacement for the `vector_tile` package with native-accelerated `toGeoJson()`
- **Full Tile Access**: Iterate through layers, features, properties, and geometry
- **GeoJSON Support**: Convert features to GeoJSON coordinates with proper Web Mercator projection

## Performance

Benchmark results comparing three implementations:
1. **bare vtzero_dart** - Direct native API (VtzTile)
2. **adapter vtzero_dart** - vector_tile compatibility layer (VectorTileVtzero)
3. **vector_tile** - Pure Dart implementation

### Test Environment

- **Model:** MacBook Air (Mac15,12)
- **Processor:** Apple M3 (8 cores: 4 performance + 4 efficiency)
- **Memory:** 24 GB
- **OS:** macOS 15.6.1
- **Test Dataset:** 130 MapTiler Detailed terrain tiles (various zoom levels)

### Benchmark Results

#### Decoding Performance
- **bare vtzero_dart:** 7μs (mean) - **55.80x faster** than vector_tile
- **adapter vtzero_dart:** 8.21ms (mean) - 20.69x slower than vector_tile
- **vector_tile:** 397μs (mean)

The bare implementation provides the fastest decoding by directly creating native handles without building compatibility structures. The adapter is slower because it builds the full compatibility layer during decoding.

#### End-to-End Performance
(Decode + iterate all layers/features + access properties + convert to GeoJSON)

- **bare vtzero_dart:** 1.17ms (mean) - **1.41x faster** than vector_tile
- **adapter vtzero_dart:** 8.84ms (mean) - 5.37x slower than vector_tile
- **vector_tile:** 1.65ms (mean)

The bare implementation is fastest end-to-end because it avoids the overhead of building compatibility structures. It directly accesses native structures and uses native-optimized GeoJSON conversion.

### Summary

- **For maximum performance:** Use bare vtzero_dart - fastest decoding (55x faster) and fastest end-to-end (1.4x faster)
- **For vector_tile compatibility:** Use adapter vtzero_dart - maintains API compatibility while still benefiting from native GeoJSON conversion
- **For pure Dart solution:** Use vector_tile - good performance with no native dependencies

The bare implementation is ideal when you need maximum performance and can work with the native API. The adapter provides vector_tile compatibility but incurs overhead from building compatibility structures during decoding.

For detailed benchmark results and methodology, see [performance_test/README.md](performance_test/README.md).

## Installation

Run:

```bash
flutter pub add vtzero_dart
```

**Note:** This package includes pre-built native binaries for supported platforms. No additional build steps are required when installing from pub.dev. The native libraries are automatically loaded based on your platform and architecture.

## Usage

### Core API (No External Dependencies)

The core API provides direct access to vtzero functionality:

```dart
import 'package:vtzero_dart/vtzero_dart.dart';

// Load tile bytes
final Uint8List tileBytes = ...; // from network, file, etc.

// Decode tile
final tile = VtzTile.fromBytes(tileBytes);

// Iterate through layers
final layers = tile.getLayers();
for (final layer in layers) {
  print('Layer: ${layer.name}');
  print('Extent: ${layer.extent}');
  print('Version: ${layer.version}');

  // Get features
  final features = layer.getFeatures();
  for (final feature in features) {
    print('Geometry type: ${feature.geometryType}');

    // Access properties
    final properties = feature.getProperties();
    properties.forEach((key, value) {
      print('  $key: $value');
    });

    // Decode geometry to tile coordinates
    final geometry = feature.decodeGeometry();
    // geometry is List<List<List<int>>> - rings/lines of [x,y] points

    // Or convert directly to GeoJSON coordinates (Web Mercator)
    final geoJsonCoords = feature.toGeoJson(
      extent: layer.extent,
      tileX: 0,
      tileY: 0,
      tileZ: 0,
    );

    // Clean up
    feature.dispose();
  }

  layer.dispose();
}

tile.dispose();
```

### Adapter API (vector_tile Compatibility)

Use `vtzero_dart` as a drop-in replacement for the `vector_tile` package with native-accelerated GeoJSON conversion:

```dart
import 'package:vtzero_dart/vector_tile_adapter.dart';
import 'package:vector_tile/util/geojson.dart' as geo;

// Create VectorTile using vtzero backend
final vectorTile = VectorTileVtzero.fromBytes(bytes: tileBytes);

// Use familiar vector_tile API
for (final layer in vectorTile.layers) {
  print('Layer: ${layer.name}');

  for (final feature in layer.features) {
    // This calls native optimized toGeoJson!
    final geoJson = feature.toGeoJson(x: 0, y: 0, z: 0);

    if (geoJson != null) {
      print('Type: ${geoJson.geometry?.type}');
      // Work with GeoJSON as usual...
    }
  }
}
```

## API Reference

### Core Classes

#### `VtzTile`

Represents a decoded vector tile.

- `VtzTile.fromBytes(Uint8List bytes)` - Decode a tile from raw bytes
- `List<VtzLayer> getLayers()` - Get all layers in the tile
- `VtzLayer? getLayer(String name)` - Get a layer by name
- `void dispose()` - Free native resources

#### `VtzLayer`

Represents a layer within a tile.

- `String name` - Layer name
- `int extent` - Tile extent (typically 4096)
- `int version` - MVT version (typically 2)
- `List<VtzFeature> getFeatures()` - Get all features in the layer
- `void dispose()` - Free native resources

#### `VtzFeature`

Represents a feature within a layer.

- `VtzGeometryType geometryType` - Geometry type (point, linestring, polygon, unknown)
- `int? id` - Optional feature ID
- `Map<String, dynamic> getProperties()` - Decode feature properties
- `List<List<List<int>>> decodeGeometry()` - Decode geometry to tile coordinates
- `List<List<List<double>>> toGeoJson({required int extent, required int tileX, required int tileY, required int tileZ})` - Convert to GeoJSON coordinates (Web Mercator projection)
- `void dispose()` - Free native resources

#### `VtzGeometryType`

Enum for geometry types:
- `VtzGeometryType.unknown`
- `VtzGeometryType.point`
- `VtzGeometryType.linestring`
- `VtzGeometryType.polygon`

### Adapter Classes

#### `VectorTileVtzero`

Drop-in replacement for `VectorTile` from the `vector_tile` package.

- `VectorTileVtzero.fromBytes({required Uint8List bytes})` - Create from bytes using vtzero decoder
- `List<VectorTileLayer> layers` - Access layers

#### `VectorTileFeatureVtzero`

Extends `VectorTileFeature` with native-accelerated `toGeoJson()`.

## Memory Management

The core API requires manual memory management. Always call `dispose()` on tiles, layers, and features when done:

```dart
// Good practice
final tile = VtzTile.fromBytes(bytes);
try {
  final layers = tile.getLayers();
  for (final layer in layers) {
    try {
      final features = layer.getFeatures();
      for (final feature in features) {
        try {
          // Use feature...
        } finally {
          feature.dispose();
        }
      }
    } finally {
      layer.dispose();
    }
  }
} finally {
  tile.dispose();
}
```

The adapter API handles memory management internally through closures, but native objects remain in memory until the `VectorTileVtzero` instance is garbage collected.

## Platform Support

- **Android**: API level 24+ (Android 7.0+)
- **iOS**: 13.0+
- **Architecture**: ARM64, ARMv7 (Android), x86_64 simulators

## Building from Source

### Prerequisites

- Flutter SDK
- C++14 compatible compiler
- CMake 3.10+
- Git (for submodules)

### Setup

```bash
# Clone with submodules
git clone --recursive https://github.com/yourusername/vtzero_dart.git
cd vtzero_dart

# Or if already cloned, initialize submodules
git submodule update --init --recursive

# Get Dart dependencies
flutter pub get

# Regenerate FFI bindings (if needed)
dart run ffigen --config ffigen.yaml
```

### Building Native Libraries for Distribution

This package includes pre-built binaries for supported platforms. For Android and iOS, Flutter's plugin system automatically builds the native code. For desktop platforms (macOS, Linux, Windows), you can build binaries locally:

```bash
# Build for current platform only (default)
dart scripts/build_native.dart

# Build for all supported platforms (macOS, Linux, Windows, iOS, Android)
dart scripts/build_native.dart --all
# or
dart scripts/build_native.dart -a

# Build for specific platform(s)
dart scripts/build_native.dart --platform macos
dart scripts/build_native.dart --platform ios
dart scripts/build_native.dart --platform android
dart scripts/build_native.dart --platform linux --platform windows
# or
dart scripts/build_native.dart -p macos -p ios -p android
```

## Example App

See the [example](example/) directory for a complete Flutter app demonstrating usage:

```bash
cd example
flutter run
```

The example app loads a sample vector tile and displays information about its layers, features, and geometry.

## Dependencies

- [ffi](https://pub.dev/packages/ffi) - Dart FFI utilities
- [fixnum](https://pub.dev/packages/fixnum) - Fixed-width integers
- [vector_tile](https://pub.dev/packages/vector_tile) - For adapter API compatibility

### Native Dependencies (included as submodules)

- [vtzero](https://github.com/mapbox/vtzero) - Vector tile decoder (BSD-2-Clause)
- [protozero](https://github.com/mapbox/protozero) - Protobuf decoder (BSD-2-Clause)

## Architecture

```
┌─────────────────────────────────────┐
│         Dart Application            │
├─────────────────────────────────────┤
│  vtzero_dart API (Core or Adapter)  │
├─────────────────────────────────────┤
│         Dart FFI Bindings           │
├─────────────────────────────────────┤
│      C++ Wrapper (vtzero_dart.h)    │
├─────────────────────────────────────┤
│     vtzero C++ Library (header-only)│
├─────────────────────────────────────┤
│    protozero C++ Library (header-only)│
└─────────────────────────────────────┘
```

The library consists of:
1. **C++ wrapper** (`src/vtzero_wrapper.cpp`) - Provides C-compatible FFI interface
2. **FFI bindings** (`lib/vtzero_dart_bindings_generated.dart`) - Auto-generated with ffigen
3. **Dart wrapper** (`lib/src/`) - Provides idiomatic Dart API
4. **Adapter layer** (`lib/vector_tile_adapter.dart`) - Optional compatibility with vector_tile package

## License

MIT License - see [LICENSE](LICENSE) file for details.

### Third-Party Licenses

This project includes the following third-party components:

- **vtzero** - Copyright (c) 2017, Mapbox (BSD-2-Clause License)
- **protozero** - Copyright (c) 2022, Mapbox (BSD-3-Clause License)

See [third_party/](third_party/) directory for complete license texts.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Troubleshooting

### iOS Build Issues

If you encounter build errors on iOS:

```bash
cd example/ios
pod install
```

### Android Build Issues

Ensure you have NDK installed and `ndkVersion` is set in your app's `build.gradle`.

### Binding Generation

If FFI bindings are out of sync:

```bash
dart run ffigen --config ffigen.yaml
```

## Acknowledgments

- [Mapbox](https://www.mapbox.com/) for the vtzero and protozero libraries
- The Mapbox Vector Tile specification maintainers

## See Also

- [vtzero C++ library](https://github.com/mapbox/vtzero)
- [Mapbox Vector Tile Specification](https://github.com/mapbox/vector-tile-spec)
- [vector_tile package](https://pub.dev/packages/vector_tile)

