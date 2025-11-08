# Performance Benchmark Tests

This directory contains performance benchmarks comparing `vtzero_dart` adapter with the `vector_tile` package.

## Setup

1. Install dependencies:
   ```bash
   dart pub get
   ```

## Usage

### Step 1: Download Heavy Test Tiles

Download heavy vector tiles with depth/elevation data:

```bash
# Without API key (uses VersaTiles - no key needed)
dart run performance_test/download_tiles.dart

# With MapTiler API key (for additional tile sources)
export MAPTILER_API_KEY=your_free_api_key_here
dart run performance_test/download_tiles.dart
```

**Free tile sources available:**

1. **VersaTiles** (no API key required):
   - Bathymetry tiles: Underwater depth data from GEBCO 2021
   - Hillshade tiles: Terrain elevation shading
   - URL: https://tiles.versatiles.org/

2. **MapTiler** (free API key required):
   - Get free API key: https://www.maptiler.com/cloud/
   - Provides detailed terrain tiles with elevation data
   - Set environment variable: `export MAPTILER_API_KEY=your_key`

3. **Natural Earth Tiles**:
   - Self-hosted option: https://github.com/lukasmartinelli/naturalearthtiles

The script will:
- Copy existing test fixtures first
- Download heavier tiles from available sources
- Save tiles to `performance_test/tiles/` directory
- Handle errors gracefully (some tiles may not exist)

### Step 2: Run Benchmark

Run the performance benchmark:

```bash
dart run performance_test/benchmark_test.dart
```

This will:
- Load all downloaded tiles
- Measure decoding time for both implementations
- Measure GeoJSON conversion time for both implementations
- Calculate statistics (min, max, mean, median, P95, P99)
- Display comparison results

## Benchmark Metrics

The benchmark measures two key operations:

1. **Decoding Time**: Time to parse tile bytes into tile object
   - `VtzTile.fromBytes()` (bare vtzero_dart)
   - `VectorTileVtzero.fromBytes()` (vtzero_dart adapter)
   - `VectorTile.fromBytes()` (vector_tile package)

2. **End-to-End Time**: Complete workflow from decoding to GeoJSON conversion
   - Includes: decode + iterate all layers/features + access properties + convert to GeoJSON
   - This represents real-world usage where you decode a tile and process all its features

## Output

The benchmark outputs:
- Individual statistics for each implementation (min, max, mean, median, P95, P99)
- Comparison showing speedup/slowdown ratios between implementations
- All times in microseconds, milliseconds, or seconds as appropriate

## Benchmark Results

### Test Environment

**Computer Details:**
- **Model:** MacBook Air (Mac15,12)
- **Processor:** Apple M3
- **Cores:** 8 (4 performance + 4 efficiency)
- **Memory:** 24 GB
- **OS:** macOS 15.6.1

**Test Dataset:**
- **Tiles:** 130 MapTiler Detailed terrain tiles
- **Source:** MapTiler Detailed terrain dataset
- **Description:** Detailed terrain tiles with elevation data (various zoom levels)

### Results

#### Bare vtzero_dart (VtzTile)

**Decoding Time:**
- Samples: 130
- Min: 1μs
- Max: 66μs
- Mean: 7μs
- Median: 3μs
- P95: 31μs
- P99: 48μs

**End-to-End Time:**
- Samples: 130
- Min: 16μs
- Max: 5.94ms
- Mean: 1.17ms
- Median: 918μs
- P95: 3.63ms
- P99: 5.93ms

#### vtzero_dart Adapter (VectorTileVtzero)

**Decoding Time:**
- Samples: 130
- Min: 13μs
- Max: 151.25ms
- Mean: 8.21ms
- Median: 1.85ms
- P95: 29.64ms
- P99: 127.91ms

**End-to-End Time:**
- Samples: 130
- Min: 25μs
- Max: 154.45ms
- Mean: 8.84ms
- Median: 2.40ms
- P95: 31.21ms
- P99: 132.58ms

#### vector_tile Package (VectorTile)

**Decoding Time:**
- Samples: 130
- Min: 12μs
- Max: 2.45ms
- Mean: 397μs
- Median: 293μs
- P95: 1.35ms
- P99: 2.36ms

**End-to-End Time:**
- Samples: 130
- Min: 28μs
- Max: 8.52ms
- Mean: 1.65ms
- Median: 907μs
- P95: 6.14ms
- P99: 8.51ms

### Performance Comparison

#### Decoding Performance
- **bare vtzero_dart:** 7μs (mean) - **55.80x faster** than vector_tile
- **adapter vtzero_dart:** 8.21ms (mean) - 20.69x slower than vector_tile
- **vector_tile:** 397μs (mean)

The bare implementation provides the fastest decoding by directly creating native handles without building compatibility structures. The adapter is slower because it builds the full compatibility layer during decoding.

#### End-to-End Performance
- **bare vtzero_dart:** 1.17ms (mean) - **1.41x faster** than vector_tile
- **adapter vtzero_dart:** 8.84ms (mean) - 5.37x slower than vector_tile
- **vector_tile:** 1.65ms (mean)

The bare implementation is fastest end-to-end because it avoids the overhead of building compatibility structures. It directly accesses native structures and uses native-optimized GeoJSON conversion.

### Summary

- **For maximum performance:** Use bare vtzero_dart - fastest decoding (55x faster) and fastest end-to-end (1.4x faster)
- **For vector_tile compatibility:** Use adapter vtzero_dart - maintains API compatibility but incurs overhead from building compatibility structures
- **For pure Dart solution:** Use vector_tile - good performance with no native dependencies

The bare implementation is ideal when you need maximum performance and can work with the native API. The adapter provides vector_tile compatibility but is slower due to the overhead of building compatibility structures during decoding.

## Files

- `download_tiles.dart` - Script to download random OSM tiles
- `benchmark_test.dart` - Performance benchmark comparing both implementations
- `tiles/` - Directory containing downloaded tiles (gitignored)

