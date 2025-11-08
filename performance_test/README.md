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

The benchmark measures:

1. **Decoding Time**: Time to parse tile bytes into tile object
   - `VectorTileVtzero.fromBytes()` (vtzero_dart adapter)
   - `VectorTile.fromBytes()` (vector_tile package)

2. **GeoJSON Conversion Time**: Time to convert all features to GeoJSON
   - Includes coordinate transformation from tile space to geographic coordinates

## Output

The benchmark outputs:
- Individual statistics for each implementation
- Comparison showing speedup/slowdown ratios
- All times in microseconds, milliseconds, or seconds as appropriate

## Benchmark Results

### Test Environment

**Computer Details:**
- **Model:** MacBook Air (Mac15,12)
- **Processor:** Apple M3
- **Cores:** 8 (4 performance + 4 efficiency)
- **Memory:** 24 GB
- **OS:** macOS 15.6.1 (Build 24G90)

**Test Dataset:**
- **Tiles:** 10,000 random zoom 10 tiles
- **Source:** VersaTiles bathymetry dataset
- **Description:** Underwater depth data from GEBCO 2021

### Results

**vtzero_dart adapter (VectorTileVtzero):**

Decoding Time:
- Samples: 10,000
- Min: 0μs
- Max: 152μs
- Mean: 3μs
- Median: 2μs
- P95: 9μs
- P99: 18μs

GeoJSON Conversion Time:
- Samples: 10,000
- Min: 0μs
- Max: 2.40ms
- Mean: 18μs
- Median: 8μs
- P95: 72μs
- P99: 135μs

**vector_tile package (VectorTile):**

Decoding Time:
- Samples: 10,000
- Min: 0μs
- Max: 717μs
- Mean: 7μs
- Median: 4μs
- P95: 22μs
- P99: 40μs

GeoJSON Conversion Time:
- Samples: 10,000
- Min: 0μs
- Max: 1.25ms
- Mean: 41μs
- Median: 16μs
- P95: 172μs
- P99: 335μs

### Performance Comparison

- **Decoding Performance:** vtzero_dart is **2.40x faster** than vector_tile (3μs vs 7μs mean)
- **GeoJSON Conversion Performance:** vtzero_dart is **2.24x faster** than vector_tile (18μs vs 41μs mean)

---

### Test Run 2: MapTiler Detailed Terrain Tiles

**Test Dataset:**
- **Tiles:** ~200 random MapTiler Detailed terrain tiles
- **Source:** MapTiler Detailed terrain dataset
- **Description:** Detailed terrain tiles with elevation data

**Results**

**vtzero_dart adapter (VectorTileVtzero):**

Decoding Time:
- Samples: 130
- Min: 21μs
- Max: 170.11ms
- Mean: 9.56ms
- Median: 1.91ms
- P95: 34.61ms
- P99: 146.94ms

GeoJSON Conversion Time:
- Samples: 130
- Min: 5μs
- Max: 4.79ms
- Mean: 854μs
- Median: 532μs
- P95: 2.89ms
- P99: 4.17ms

**vector_tile package (VectorTile):**

Decoding Time:
- Samples: 130
- Min: 11μs
- Max: 2.56ms
- Mean: 397μs
- Median: 278μs
- P95: 1.45ms
- P99: 2.43ms

GeoJSON Conversion Time:
- Samples: 130
- Min: 5μs
- Max: 7.36ms
- Mean: 1.35ms
- Median: 723μs
- P95: 4.63ms
- P99: 6.81ms

**Performance Comparison**

- **Decoding Performance:** vector_tile is **24.09x faster** than vtzero_dart (397μs vs 9.56ms mean)
- **GeoJSON Conversion Performance:** vtzero_dart is **1.59x faster** than vector_tile (854μs vs 1.35ms mean)

## Files

- `download_tiles.dart` - Script to download random OSM tiles
- `benchmark_test.dart` - Performance benchmark comparing both implementations
- `tiles/` - Directory containing downloaded tiles (gitignored)

