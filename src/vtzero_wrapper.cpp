#include "vtzero_dart.h"
#include "../third_party/vtzero/include/vtzero/vector_tile.hpp"
#include "../third_party/vtzero/include/vtzero/geometry.hpp"
#include "../third_party/vtzero/include/vtzero/exception.hpp"
#include <string>
#include <vector>
#include <cstring>
#include <cmath>
#include <mutex>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Thread-safe exception storage
namespace {
    struct ExceptionStorage {
        VtzExceptionType type = VTZ_EXCEPTION_NONE;
        std::string message;
    };

    static ExceptionStorage g_exception_storage;
    static std::mutex g_exception_mutex;

    void set_exception(VtzExceptionType type, const std::string& msg) {
        std::lock_guard<std::mutex> lock(g_exception_mutex);
        g_exception_storage.type = type;
        g_exception_storage.message = msg;
    }

    void clear_exception() {
        std::lock_guard<std::mutex> lock(g_exception_mutex);
        g_exception_storage.type = VTZ_EXCEPTION_NONE;
        g_exception_storage.message.clear();
    }
}

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
    clear_exception();
    try {
        if (!tile_handle) {
            return nullptr;
        }

        auto layer = tile_handle->tile.next_layer();
        if (layer.valid()) {
            return new VtzLayerHandle(std::move(layer));
        }

        return nullptr;
    } catch (const vtzero::version_exception& e) {
        set_exception(VTZ_EXCEPTION_VERSION, e.what());
        return nullptr;
    } catch (const vtzero::format_exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_FORMAT, "Unknown exception");
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT VtzLayerHandle* vtz_tile_get_layer_by_name(VtzTileHandle* tile_handle, const char* name) {
    clear_exception();
    try {
        if (!tile_handle || !name) return nullptr;

        auto layer = tile_handle->tile.get_layer_by_name(name);
        if (!layer) return nullptr;

        return new VtzLayerHandle(std::move(layer));
    } catch (const vtzero::format_exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_FORMAT, "Unknown exception");
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
    clear_exception();
    try {
        if (!layer_handle) return nullptr;

        auto feature = layer_handle->layer.next_feature();
        if (!feature) return nullptr;

        return new VtzFeatureHandle(std::move(feature));
    } catch (const vtzero::format_exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_FORMAT, "Unknown exception");
        return nullptr;
    }
}

// Value table operations
FFI_PLUGIN_EXPORT size_t vtz_layer_value_table_size(VtzLayerHandle* layer_handle) {
    if (!layer_handle) return 0;
    try {
        // value_table_size() doesn't throw, but accessing value_table() might
        // if it needs to initialize and encounters malformed data
        return layer_handle->layer.value_table_size();
    } catch (...) {
        return 0;
    }
}

// Property value handle - stores the data_view from layer
struct VtzPropertyValueHandle {
    vtzero::property_value value;
    std::string string_storage; // For string values

    VtzPropertyValueHandle(const vtzero::property_value& pv) : value(pv) {
        // Store string value if needed
        if (pv.type() == vtzero::property_value_type::string_value) {
            auto view = pv.string_value();
            string_storage = std::string(view.data(), view.size());
        }
    }
};

FFI_PLUGIN_EXPORT VtzPropertyValueHandle* vtz_layer_value(VtzLayerHandle* layer_handle, uint32_t index) {
    clear_exception();
    if (!layer_handle) return nullptr;
    try {
        vtzero::index_value idx(index);
        // value() may call value_table() which may initialize the table
        // This should not throw for malformed values - only accessing type() throws
        auto pv = layer_handle->layer.value(idx);
        return new VtzPropertyValueHandle(pv);
    } catch (const vtzero::out_of_range_exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
        return nullptr;
    } catch (const vtzero::format_exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return nullptr;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_FORMAT, "Unknown exception");
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT void vtz_property_value_free(VtzPropertyValueHandle* handle) {
    delete handle;
}

FFI_PLUGIN_EXPORT int32_t vtz_property_value_type(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return -1;
    try {
        auto type = handle->value.type();
        switch (type) {
            case vtzero::property_value_type::string_value: return 1;
            case vtzero::property_value_type::float_value: return 2;
            case vtzero::property_value_type::double_value: return 3;
            case vtzero::property_value_type::int_value: return 4;
            case vtzero::property_value_type::uint_value: return 5;
            case vtzero::property_value_type::sint_value: return 6;
            case vtzero::property_value_type::bool_value: return 7;
            default: return -1;
        }
    } catch (const vtzero::format_exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return -1;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_FORMAT, e.what());
        return -1;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_FORMAT, "Unknown exception");
        return -1;
    }
}

FFI_PLUGIN_EXPORT const char* vtz_property_value_string(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return nullptr;
    try {
        auto type = handle->value.type();
        if (type == vtzero::property_value_type::string_value) {
            return handle->string_storage.c_str();
        }
        // Wrong type - throw type_exception to match C++ behavior
        throw vtzero::type_exception{};
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return nullptr;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return nullptr;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return nullptr;
    }
}

FFI_PLUGIN_EXPORT float vtz_property_value_float(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return 0.0f;
    try {
        return handle->value.float_value();
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0.0f;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0.0f;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return 0.0f;
    }
}

FFI_PLUGIN_EXPORT double vtz_property_value_double(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return 0.0;
    try {
        return handle->value.double_value();
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0.0;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0.0;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return 0.0;
    }
}

FFI_PLUGIN_EXPORT int64_t vtz_property_value_int(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return 0;
    try {
        return handle->value.int_value();
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return 0;
    }
}

FFI_PLUGIN_EXPORT uint64_t vtz_property_value_uint(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return 0;
    try {
        return handle->value.uint_value();
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return 0;
    }
}

FFI_PLUGIN_EXPORT int64_t vtz_property_value_sint(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return 0;
    try {
        return handle->value.sint_value();
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return 0;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return 0;
    }
}

FFI_PLUGIN_EXPORT bool vtz_property_value_bool(VtzPropertyValueHandle* handle) {
    clear_exception();
    if (!handle) return false;
    try {
        return handle->value.bool_value();
    } catch (const vtzero::type_exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return false;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_TYPE, e.what());
        return false;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_TYPE, "Unknown exception");
        return false;
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
    clear_exception();
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
    } catch (const vtzero::out_of_range_exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
    } catch (...) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, "Unknown exception");
    }
}

// Property index operations
FFI_PLUGIN_EXPORT VtzPropertyIndexPair vtz_feature_next_property_indexes(VtzFeatureHandle* feature_handle) {
    clear_exception();
    VtzPropertyIndexPair result = {0, 0, false};
    if (!feature_handle) return result;

    try {
        auto idxs = feature_handle->feature.next_property_indexes();
        if (idxs) {
            result.key_index = idxs.key().value();
            result.value_index = idxs.value().value();
            result.valid = true;
        }
    } catch (const vtzero::out_of_range_exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
    } catch (...) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, "Unknown exception");
    }
    return result;
}

FFI_PLUGIN_EXPORT void vtz_feature_reset_property(VtzFeatureHandle* feature_handle) {
    if (!feature_handle) return;
    try {
        feature_handle->feature.reset_property();
    } catch (...) {
        // Error resetting property
    }
}

typedef void (*PropertyIndexCallback)(void* user_data, uint32_t key_index, uint32_t value_index);

FFI_PLUGIN_EXPORT bool vtz_feature_for_each_property_indexes(VtzFeatureHandle* feature_handle,
                                                              PropertyIndexCallback callback,
                                                              void* user_data) {
    clear_exception();
    if (!feature_handle || !callback) return false;

    try {
        return feature_handle->feature.for_each_property_indexes([&](vtzero::index_value_pair&& idxs) {
            callback(user_data, idxs.key().value(), idxs.value().value());
            return true;
        });
    } catch (const vtzero::out_of_range_exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
        return false;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, e.what());
        return false;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_OUT_OF_RANGE, "Unknown exception");
        return false;
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

    void ring_end(vtzero::ring_type /*rt*/) {
        callback(user_data, 9, 0, 0); // Command 9 = ring_end
    }
};

FFI_PLUGIN_EXPORT int vtz_feature_decode_geometry(VtzFeatureHandle* feature_handle,
                                                     GeometryCallback callback,
                                                     void* user_data) {
    clear_exception();
    if (!feature_handle || !callback) return -1;

    try {
        auto geometry = feature_handle->feature.geometry();
        GeometryHandler handler{callback, user_data};

        // Check geometry type and use appropriate decode function
        // For unknown types, throw geometry_exception to match C++ behavior
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
                // Unknown geometry type - throw geometry_exception to match C++ behavior
                throw vtzero::geometry_exception{"unknown geometry type"};
        }
        return 0; // Success
    } catch (const vtzero::geometry_exception& e) {
        set_exception(VTZ_EXCEPTION_GEOMETRY, e.what());
        return 1;
    } catch (const std::exception& e) {
        set_exception(VTZ_EXCEPTION_GEOMETRY, e.what());
        return -1;
    } catch (...) {
        set_exception(VTZ_EXCEPTION_GEOMETRY, "Unknown exception");
        return -1;
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

    // For polygon rings: collect points and fix winding order
    std::vector<std::pair<double, double>> current_ring;
    bool is_polygon_ring;

    GeoJsonHandler(GeoJsonCallback cb, void* data, uint32_t ext, int32_t tx, int32_t ty, uint32_t tz)
        : callback(cb), user_data(data), extent(ext), tile_x(tx), tile_y(ty), tile_z(tz), is_polygon_ring(false) {
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

    // Calculate if ring is counter-clockwise using shoelace formula
    // Implements https://en.wikipedia.org/wiki/Shoelace_formula
    // Matches vector_tile package implementation:
    // for (var i = 0, j = ringLength - 1; i < ringLength; j = i++) {
    //   sum += (ring[i][0] - ring[j][0]) * (ring[i][1] + ring[j][1]);
    // }
    // Returns true if counter-clockwise (sum < 0), false if clockwise (sum >= 0)
    bool is_counter_clockwise(const std::vector<std::pair<double, double>>& ring) {
        if (ring.size() < 3) return true; // Default to counter-clockwise for invalid rings
        
        double sum = 0.0;
        size_t n = ring.size();
        size_t effective_n = n;
        
        // Check if ring is closed (first point == last point)
        // Use epsilon comparison for floating point coordinates
        const double epsilon = 1e-10;
        if (n > 3 && 
            std::abs(ring[0].first - ring[n-1].first) < epsilon &&
            std::abs(ring[0].second - ring[n-1].second) < epsilon) {
            effective_n = n - 1; // Skip duplicate closing point
        }
        
        // Match vector_tile implementation: j starts at last index, then j = i, i increments
        // This means: j is previous index, i is current index
        // Formula: (current.x - previous.x) * (current.y + previous.y)
        for (size_t i = 0, j = effective_n - 1; i < effective_n; j = i++) {
            const double& current_x = ring[i].first;
            const double& current_y = ring[i].second;
            const double& previous_x = ring[j].first;
            const double& previous_y = ring[j].second;
            
            sum += (current_x - previous_x) * (current_y + previous_y);
        }
        
        // Counter-clockwise if sum < 0 (matches vector_tile)
        return sum < 0.0;
    }

    // Emit ring points, reversing if needed to follow GeoJSON right-hand rule
    void emit_ring(bool is_outer) {
        if (current_ring.size() < 3) {
            // Invalid ring, skip it
            current_ring.clear();
            return;
        }

        // Check if ring is closed (first point == last point)
        // Use epsilon comparison for floating point coordinates
        const double epsilon = 1e-10;
        bool is_closed = (current_ring.size() > 3 &&
                         std::abs(current_ring[0].first - current_ring[current_ring.size()-1].first) < epsilon &&
                         std::abs(current_ring[0].second - current_ring[current_ring.size()-1].second) < epsilon);
        
        // Ensure ring is closed for GeoJSON (first point == last point)
        // GeoJSON spec requires all rings to be closed
        if (!is_closed && current_ring.size() >= 2) {
            // Add closing point if not already closed
            current_ring.push_back(current_ring[0]);
            is_closed = true;
        }
        
        // Check if ring is counter-clockwise using the validation library's formula
        // sum += (next.x - current.x) * (next.y + current.y)
        // Counter-clockwise if sum < 0
        bool is_ccw = is_counter_clockwise(current_ring);
        
        // All rings must be counter-clockwise according to the validation library
        // If the ring is not counter-clockwise, reverse it
        bool should_reverse = !is_ccw;

        // Emit ring
        callback(user_data, 0, 0, 0); // BEGIN_RING
        
        if (should_reverse) {
            // Reverse the ring to fix winding order
            // For a closed ring [A, B, C, A], we want [A, C, B, A]
            // We need to reverse all points except keep the first point as both start and end
            if (is_closed && current_ring.size() > 1) {
                // Emit first point (which will be both start and end)
                callback(user_data, 1, current_ring[0].first, current_ring[0].second);
                // Reverse and emit all points except the first and last (duplicate)
                // Go from second-to-last down to second
                for (size_t i = current_ring.size() - 2; i >= 1; --i) {
                    callback(user_data, 1, current_ring[i].first, current_ring[i].second);
                    if (i == 1) break; // Prevent underflow
                }
                // Close the ring with first point again
                callback(user_data, 1, current_ring[0].first, current_ring[0].second);
            } else {
                // Ring not closed, reverse all points
                for (auto it = current_ring.rbegin(); it != current_ring.rend(); ++it) {
                    callback(user_data, 1, it->first, it->second);
                }
            }
        } else {
            // Emit points in original order
            // GeoJSON requires closed rings, so we always emit all points including closing duplicate
            for (const auto& point : current_ring) {
                callback(user_data, 1, point.first, point.second);
            }
        }
        
        callback(user_data, 2, 0, 0); // END_RING
        current_ring.clear();
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
        is_polygon_ring = true;
        current_ring.clear();
    }

    void ring_point(const vtzero::point& p) {
        double lon, lat;
        project_point(p.x, p.y, lon, lat);
        current_ring.push_back(std::make_pair(lon, lat));
    }

    void ring_end(vtzero::ring_type rt) {
        is_polygon_ring = false;
        // Skip invalid rings (zero area)
        if (rt == vtzero::ring_type::invalid) {
            current_ring.clear();
            return;
        }
        bool is_outer = (rt == vtzero::ring_type::outer);
        emit_ring(is_outer);
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

// Exception handling API
FFI_PLUGIN_EXPORT VtzExceptionType vtz_get_last_exception_type(void) {
    std::lock_guard<std::mutex> lock(g_exception_mutex);
    return g_exception_storage.type;
}

FFI_PLUGIN_EXPORT const char* vtz_get_last_exception_message(void) {
    std::lock_guard<std::mutex> lock(g_exception_mutex);
    if (g_exception_storage.message.empty()) {
        return nullptr;
    }
    // Return a pointer to the stored message
    // Note: This is safe because the message is stored in static storage
    return g_exception_storage.message.c_str();
}

FFI_PLUGIN_EXPORT void vtz_clear_exception(void) {
    clear_exception();
}
