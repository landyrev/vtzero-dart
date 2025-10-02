#include "vtzero_dart.h"
#include "../third_party/vtzero/include/vtzero/vector_tile.hpp"
#include "../third_party/vtzero/include/vtzero/geometry.hpp"
#include <string>
#include <vector>
#include <cstring>
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Opaque handles for passing between C and C++
struct VtzTileHandle {
    std::string data;
    vtzero::vector_tile tile;

    VtzTileHandle(const char* bytes, size_t length)
        : data(bytes, length), tile(data) {}
};

struct VtzLayerHandle {
    vtzero::layer layer;
    std::string name_str;  // Store name to return stable pointer

    VtzLayerHandle(vtzero::layer&& l) : layer(std::move(l)) {
        auto name_view = layer.name();
        name_str = std::string(name_view.data(), name_view.size());
    }
};

struct VtzFeatureHandle {
    vtzero::feature feature;

    VtzFeatureHandle(vtzero::feature&& f) : feature(std::move(f)) {}
};

// Tile operations
FFI_PLUGIN_EXPORT VtzTileHandle* vtz_tile_create(const uint8_t* data, size_t length) {
    try {
        return new VtzTileHandle(reinterpret_cast<const char*>(data), length);
    } catch (...) {
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT void vtz_tile_free(VtzTileHandle* handle) {
    delete handle;
}

FFI_PLUGIN_EXPORT VtzLayerHandle* vtz_tile_next_layer(VtzTileHandle* tile_handle) {
    try {
        if (!tile_handle) {
            return nullptr;
        }

        auto layer = tile_handle->tile.next_layer();
        if (layer.valid()) {
            return new VtzLayerHandle(std::move(layer));
        }

        return nullptr;
    } catch (const std::exception& e) {
        // Exception during layer iteration
        return nullptr;
    } catch (...) {
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT VtzLayerHandle* vtz_tile_get_layer_by_name(VtzTileHandle* tile_handle, const char* name) {
    try {
        if (!tile_handle || !name) return nullptr;

        auto layer = tile_handle->tile.get_layer_by_name(name);
        if (!layer) return nullptr;

        return new VtzLayerHandle(std::move(layer));
    } catch (...) {
        return nullptr;
    }
}

// Layer operations
FFI_PLUGIN_EXPORT void vtz_layer_free(VtzLayerHandle* handle) {
    delete handle;
}

FFI_PLUGIN_EXPORT const char* vtz_layer_name(VtzLayerHandle* layer_handle) {
    if (!layer_handle) return nullptr;
    return layer_handle->name_str.c_str();
}

FFI_PLUGIN_EXPORT uint32_t vtz_layer_extent(VtzLayerHandle* layer_handle) {
    if (!layer_handle) return 4096;
    return layer_handle->layer.extent();
}

FFI_PLUGIN_EXPORT uint32_t vtz_layer_version(VtzLayerHandle* layer_handle) {
    if (!layer_handle) return 0;
    return layer_handle->layer.version();
}

FFI_PLUGIN_EXPORT VtzFeatureHandle* vtz_layer_next_feature(VtzLayerHandle* layer_handle) {
    try {
        if (!layer_handle) return nullptr;

        auto feature = layer_handle->layer.next_feature();
        if (!feature) return nullptr;

        return new VtzFeatureHandle(std::move(feature));
    } catch (...) {
        return nullptr;
    }
}

// Feature operations
FFI_PLUGIN_EXPORT void vtz_feature_free(VtzFeatureHandle* handle) {
    delete handle;
}

FFI_PLUGIN_EXPORT uint32_t vtz_feature_geometry_type(VtzFeatureHandle* feature_handle) {
    if (!feature_handle) return 0;
    return static_cast<uint32_t>(feature_handle->feature.geometry_type());
}

FFI_PLUGIN_EXPORT bool vtz_feature_has_id(VtzFeatureHandle* feature_handle) {
    if (!feature_handle) return false;
    return feature_handle->feature.has_id();
}

FFI_PLUGIN_EXPORT uint64_t vtz_feature_id(VtzFeatureHandle* feature_handle) {
    if (!feature_handle) return 0;
    return feature_handle->feature.id();
}

// Property iteration callback
typedef void (*PropertyCallback)(void* user_data, const char* key, int32_t value_type,
                                  const char* string_value, double double_value,
                                  int64_t int_value, uint64_t uint_value, bool bool_value);

FFI_PLUGIN_EXPORT void vtz_feature_for_each_property(VtzFeatureHandle* feature_handle,
                                                       PropertyCallback callback,
                                                       void* user_data) {
    if (!feature_handle || !callback) return;

    try {
        feature_handle->feature.for_each_property([&](const vtzero::property& prop) {
            auto key_view = prop.key();
            std::string key_str(key_view.data(), key_view.size());
            auto value = prop.value();

            if (value.type() == vtzero::property_value_type::string_value) {
                auto val_view = value.string_value();
                std::string val_str(val_view.data(), val_view.size());
                callback(user_data, key_str.c_str(), 1, val_str.c_str(), 0, 0, 0, false);
            } else if (value.type() == vtzero::property_value_type::float_value) {
                callback(user_data, key_str.c_str(), 2, nullptr, value.float_value(), 0, 0, false);
            } else if (value.type() == vtzero::property_value_type::double_value) {
                callback(user_data, key_str.c_str(), 3, nullptr, value.double_value(), 0, 0, false);
            } else if (value.type() == vtzero::property_value_type::int_value) {
                callback(user_data, key_str.c_str(), 4, nullptr, 0, value.int_value(), 0, false);
            } else if (value.type() == vtzero::property_value_type::uint_value) {
                callback(user_data, key_str.c_str(), 5, nullptr, 0, 0, value.uint_value(), false);
            } else if (value.type() == vtzero::property_value_type::sint_value) {
                callback(user_data, key_str.c_str(), 6, nullptr, 0, value.sint_value(), 0, false);
            } else if (value.type() == vtzero::property_value_type::bool_value) {
                callback(user_data, key_str.c_str(), 7, nullptr, 0, 0, 0, value.bool_value());
            }
            return true;
        });
    } catch (...) {
        // Error during property iteration
    }
}

// Geometry decoding callback
typedef void (*GeometryCallback)(void* user_data, uint32_t command, int32_t x, int32_t y);

// Geometry handler that collects points via callback
struct GeometryHandler {
    GeometryCallback callback;
    void* user_data;

    // Point geometry callbacks
    void points_begin(uint32_t count) {
        callback(user_data, 1, count, 0); // Command 1 = points_begin
    }

    void points_point(const vtzero::point& p) {
        callback(user_data, 2, p.x, p.y); // Command 2 = point
    }

    void points_end() {
        callback(user_data, 3, 0, 0); // Command 3 = points_end
    }

    // Linestring geometry callbacks
    void linestring_begin(uint32_t count) {
        callback(user_data, 4, count, 0); // Command 4 = linestring_begin
    }

    void linestring_point(const vtzero::point& p) {
        callback(user_data, 5, p.x, p.y); // Command 5 = linestring_point
    }

    void linestring_end() {
        callback(user_data, 6, 0, 0); // Command 6 = linestring_end
    }

    // Polygon ring callbacks
    void ring_begin(uint32_t count) {
        callback(user_data, 7, count, 0); // Command 7 = ring_begin
    }

    void ring_point(const vtzero::point& p) {
        callback(user_data, 8, p.x, p.y); // Command 8 = ring_point
    }

    void ring_end(bool /*is_outer*/) {
        callback(user_data, 9, 0, 0); // Command 9 = ring_end
    }
};

FFI_PLUGIN_EXPORT void vtz_feature_decode_geometry(VtzFeatureHandle* feature_handle,
                                                     GeometryCallback callback,
                                                     void* user_data) {
    if (!feature_handle || !callback) return;

    try {
        auto geometry = feature_handle->feature.geometry();
        GeometryHandler handler{callback, user_data};

        switch (geometry.type()) {
            case vtzero::GeomType::POINT:
                vtzero::decode_point_geometry(geometry, handler);
                break;
            case vtzero::GeomType::LINESTRING:
                vtzero::decode_linestring_geometry(geometry, handler);
                break;
            case vtzero::GeomType::POLYGON:
                vtzero::decode_polygon_geometry(geometry, handler);
                break;
            default:
                // Unknown geometry type
                break;
        }
    } catch (...) {
        // Error during geometry decoding
    }
}

// GeoJSON handler that projects coordinates to lon/lat
struct GeoJsonHandler {
    GeoJsonCallback callback;
    void* user_data;
    uint32_t extent;
    int32_t tile_x;
    int32_t tile_y;
    uint32_t tile_z;

    double size;
    double x0;
    double y0;

    GeoJsonHandler(GeoJsonCallback cb, void* data, uint32_t ext, int32_t tx, int32_t ty, uint32_t tz)
        : callback(cb), user_data(data), extent(ext), tile_x(tx), tile_y(ty), tile_z(tz) {
        size = static_cast<double>(extent) * (1 << tz); // extent * 2^z
        x0 = static_cast<double>(extent) * tile_x;
        y0 = static_cast<double>(extent) * tile_y;
    }

    // Project point from tile coordinates to lon/lat
    void project_point(int32_t x, int32_t y, double& lon, double& lat) {
        // Convert to lon/lat using Web Mercator projection
        // See: https://wiki.openstreetmap.org/wiki/Slippy_map_tilenames
        double y2 = 180.0 - (y + y0) * 360.0 / size;
        lon = (x + x0) * 360.0 / size - 180.0;
        lat = 360.0 / M_PI * atan(exp(y2 * M_PI / 180.0)) - 90.0;
    }

    // Point geometry handlers
    void points_begin(uint32_t /*count*/) {
        callback(user_data, 0, 0, 0); // BEGIN_RING
    }

    void points_point(const vtzero::point& p) {
        double lon, lat;
        project_point(p.x, p.y, lon, lat);
        callback(user_data, 1, lon, lat); // POINT
    }

    void points_end() {
        callback(user_data, 2, 0, 0); // END_RING
    }

    // Linestring geometry handlers
    void linestring_begin(uint32_t /*count*/) {
        callback(user_data, 0, 0, 0); // BEGIN_RING
    }

    void linestring_point(const vtzero::point& p) {
        double lon, lat;
        project_point(p.x, p.y, lon, lat);
        callback(user_data, 1, lon, lat); // POINT
    }

    void linestring_end() {
        callback(user_data, 2, 0, 0); // END_RING
    }

    // Polygon ring handlers
    void ring_begin(uint32_t /*count*/) {
        callback(user_data, 0, 0, 0); // BEGIN_RING
    }

    void ring_point(const vtzero::point& p) {
        double lon, lat;
        project_point(p.x, p.y, lon, lat);
        callback(user_data, 1, lon, lat); // POINT
    }

    void ring_end(bool /*is_outer*/) {
        callback(user_data, 2, 0, 0); // END_RING
    }
};

FFI_PLUGIN_EXPORT void vtz_feature_to_geojson(VtzFeatureHandle* feature_handle,
                                                uint32_t extent,
                                                int32_t tile_x,
                                                int32_t tile_y,
                                                uint32_t tile_z,
                                                GeoJsonCallback callback,
                                                void* user_data) {
    if (!feature_handle || !callback) return;

    try {
        auto geometry = feature_handle->feature.geometry();
        GeoJsonHandler handler(callback, user_data, extent, tile_x, tile_y, tile_z);

        switch (geometry.type()) {
            case vtzero::GeomType::POINT:
                vtzero::decode_point_geometry(geometry, handler);
                break;
            case vtzero::GeomType::LINESTRING:
                vtzero::decode_linestring_geometry(geometry, handler);
                break;
            case vtzero::GeomType::POLYGON:
                vtzero::decode_polygon_geometry(geometry, handler);
                break;
            default:
                // Unknown geometry type
                break;
        }
    } catch (...) {
        // Error during GeoJSON conversion
    }
}
