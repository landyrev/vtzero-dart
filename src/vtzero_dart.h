#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle types (implemented in C++)
typedef struct VtzTileHandle VtzTileHandle;
typedef struct VtzLayerHandle VtzLayerHandle;
typedef struct VtzFeatureHandle VtzFeatureHandle;

// Tile operations
FFI_PLUGIN_EXPORT VtzTileHandle* vtz_tile_create(const uint8_t* data, size_t length);
FFI_PLUGIN_EXPORT void vtz_tile_free(VtzTileHandle* handle);
FFI_PLUGIN_EXPORT VtzLayerHandle* vtz_tile_next_layer(VtzTileHandle* tile_handle);
FFI_PLUGIN_EXPORT VtzLayerHandle* vtz_tile_get_layer_by_name(VtzTileHandle* tile_handle, const char* name);

// Layer operations
FFI_PLUGIN_EXPORT void vtz_layer_free(VtzLayerHandle* handle);
FFI_PLUGIN_EXPORT const char* vtz_layer_name(VtzLayerHandle* layer_handle);
FFI_PLUGIN_EXPORT uint32_t vtz_layer_extent(VtzLayerHandle* layer_handle);
FFI_PLUGIN_EXPORT uint32_t vtz_layer_version(VtzLayerHandle* layer_handle);
FFI_PLUGIN_EXPORT VtzFeatureHandle* vtz_layer_next_feature(VtzLayerHandle* layer_handle);

// Feature operations
FFI_PLUGIN_EXPORT void vtz_feature_free(VtzFeatureHandle* handle);
FFI_PLUGIN_EXPORT uint32_t vtz_feature_geometry_type(VtzFeatureHandle* feature_handle);
FFI_PLUGIN_EXPORT bool vtz_feature_has_id(VtzFeatureHandle* feature_handle);
FFI_PLUGIN_EXPORT uint64_t vtz_feature_id(VtzFeatureHandle* feature_handle);

// Property iteration callback
typedef void (*PropertyCallback)(void* user_data, const char* key, int32_t value_type,
                                  const char* string_value, double double_value,
                                  int64_t int_value, uint64_t uint_value, bool bool_value);

FFI_PLUGIN_EXPORT void vtz_feature_for_each_property(VtzFeatureHandle* feature_handle,
                                                       PropertyCallback callback,
                                                       void* user_data);

// Geometry decoding callback
typedef void (*GeometryCallback)(void* user_data, uint32_t command, int32_t x, int32_t y);

FFI_PLUGIN_EXPORT void vtz_feature_decode_geometry(VtzFeatureHandle* feature_handle,
                                                     GeometryCallback callback,
                                                     void* user_data);

// GeoJSON projection callback
// ring_type: 0=begin_ring, 1=point, 2=end_ring
typedef void (*GeoJsonCallback)(void* user_data, uint32_t ring_type, double lon, double lat);

FFI_PLUGIN_EXPORT void vtz_feature_to_geojson(VtzFeatureHandle* feature_handle,
                                                uint32_t extent,
                                                int32_t tile_x,
                                                int32_t tile_y,
                                                uint32_t tile_z,
                                                GeoJsonCallback callback,
                                                void* user_data);

#ifdef __cplusplus
}
#endif
