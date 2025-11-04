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

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  vtzero_dart: ^0.0.1
```

Then run:

```bash
flutter pub get
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

### Building Native Assets for pub.dev Distribution

This package includes pre-built binaries for supported platforms. To build native assets locally:

```bash
# Build for current platform only (default)
dart hook/build.dart

# Build for all supported platforms (macOS, Linux, Windows, iOS, Android)
dart hook/build.dart --all
# or
dart hook/build.dart -a

# Build for specific platform(s)
dart hook/build.dart --platform macos
dart hook/build.dart --platform ios
dart hook/build.dart --platform android
dart hook/build.dart --platform linux --platform windows
# or
dart hook/build.dart -p macos -p ios -p android
```

**Platform-Specific Notes:**

**iOS:**
- Can only be built on macOS (requires Xcode)
- Builds for both `arm64` (device) and `x86_64` (simulator) architectures
- Uses CMake with iOS toolchain configuration

**Android:**
- Can be built on macOS, Linux, or Windows
- Requires Android NDK (set `ANDROID_NDK_HOME` environment variable)
- Builds for: `arm64-v8a`, `armeabi-v7a`, `x86`, `x86_64`
- Minimum API level: 24 (Android 7.0+)

**Cross-Compilation:**
- macOS can build for: macOS, iOS
- Linux can build for: Linux (and Android if NDK is available)
- Windows can build for: Windows (and Android if NDK is available)
- On macOS with Apple Silicon, you can build for both `arm64` and `x86_64` architectures
- For true multi-platform builds, use CI/CD pipelines with multiple runners

This will:
1. Detect your platform and architecture (macOS, Linux, Windows, etc.)
2. Build the native library using CMake
3. Place the built library in `native_assets/{platform}/{architecture}/`

The built binaries will be automatically used by the package when published to pub.dev.

**Supported Platforms:**
- macOS (arm64, x86_64)
- Linux (x86_64, arm64, arm)
- Windows (x64)
- Android (arm64-v8a, armeabi-v7a, x86, x86_64)
- iOS (arm64, x86_64 for simulator)

**Note:** The native assets feature requires Dart SDK 3.5+ with the `--enable-experiment=native-assets` flag (currently experimental). When published to pub.dev, the package will automatically include pre-built binaries for all supported platforms.

### Build Native Code (Legacy/Development)

For development and testing, you can also build using Flutter's build system:

#### iOS
```bash
cd example
flutter build ios
```

#### Android
```bash
cd example
flutter build apk
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

