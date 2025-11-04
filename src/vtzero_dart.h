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

// Exception types
typedef enum {
    VTZ_EXCEPTION_NONE = 0,
    VTZ_EXCEPTION_FORMAT = 1,
    VTZ_EXCEPTION_GEOMETRY = 2,
    VTZ_EXCEPTION_TYPE = 3,
    VTZ_EXCEPTION_VERSION = 4,
    VTZ_EXCEPTION_OUT_OF_RANGE = 5
} VtzExceptionType;

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

// Value table operations
FFI_PLUGIN_EXPORT size_t vtz_layer_value_table_size(VtzLayerHandle* layer_handle);
typedef struct VtzPropertyValueHandle VtzPropertyValueHandle;
FFI_PLUGIN_EXPORT VtzPropertyValueHandle* vtz_layer_value(VtzLayerHandle* layer_handle, uint32_t index);
FFI_PLUGIN_EXPORT void vtz_property_value_free(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT int32_t vtz_property_value_type(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT const char* vtz_property_value_string(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT float vtz_property_value_float(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT double vtz_property_value_double(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT int64_t vtz_property_value_int(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT uint64_t vtz_property_value_uint(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT int64_t vtz_property_value_sint(VtzPropertyValueHandle* handle);
FFI_PLUGIN_EXPORT bool vtz_property_value_bool(VtzPropertyValueHandle* handle);

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

// Property index operations
typedef struct {
    uint32_t key_index;
    uint32_t value_index;
    bool valid;
} VtzPropertyIndexPair;

FFI_PLUGIN_EXPORT VtzPropertyIndexPair vtz_feature_next_property_indexes(VtzFeatureHandle* feature_handle);
FFI_PLUGIN_EXPORT void vtz_feature_reset_property(VtzFeatureHandle* feature_handle);

typedef void (*PropertyIndexCallback)(void* user_data, uint32_t key_index, uint32_t value_index);

FFI_PLUGIN_EXPORT bool vtz_feature_for_each_property_indexes(VtzFeatureHandle* feature_handle,
                                                              PropertyIndexCallback callback,
                                                              void* user_data);

// Geometry decoding callback
typedef void (*GeometryCallback)(void* user_data, uint32_t command, int32_t x, int32_t y);

FFI_PLUGIN_EXPORT int vtz_feature_decode_geometry(VtzFeatureHandle* feature_handle,
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

// Exception handling
FFI_PLUGIN_EXPORT VtzExceptionType vtz_get_last_exception_type(void);
FFI_PLUGIN_EXPORT const char* vtz_get_last_exception_message(void);
FFI_PLUGIN_EXPORT void vtz_clear_exception(void);

#ifdef __cplusplus
}
#endif
