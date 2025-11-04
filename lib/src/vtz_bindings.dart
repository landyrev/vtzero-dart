import 'dart:ffi';
import 'dart:io';
import '../vtzero_dart_bindings_generated.dart';

const String _libName = 'vtzero_dart';

/// The dynamic library in which the symbols for vtzero can be found.
final DynamicLibrary _dylib = () {
  // Try to find the library in common locations
  final possiblePaths = <String>[];

  if (Platform.isMacOS || Platform.isIOS) {
    // Try framework first (for iOS/App bundles)
    possiblePaths.add('$_libName.framework/$_libName');
    // Try dylib in build directory (for tests/development)
    possiblePaths.add('build/lib$_libName.dylib');
    possiblePaths.add('../build/lib$_libName.dylib');
    possiblePaths.add('../../build/lib$_libName.dylib');
  } else if (Platform.isAndroid || Platform.isLinux) {
    possiblePaths.add('lib$_libName.so');
    possiblePaths.add('build/lib$_libName.so');
    possiblePaths.add('../build/lib$_libName.so');
  } else if (Platform.isWindows) {
    possiblePaths.add('$_libName.dll');
    possiblePaths.add('build/$_libName.dll');
    possiblePaths.add('../build/$_libName.dll');
  } else {
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }

  // Try each path until one works
  for (final path in possiblePaths) {
    try {
      return DynamicLibrary.open(path);
    } catch (e) {
      // Continue to next path
    }
  }

  // If all paths failed, try the first one to get a better error message
  throw Exception(
    'Failed to load dynamic library $_libName. '
    'Tried paths: ${possiblePaths.join(", ")}. '
    'Make sure the library is built and available.',
  );
}();

/// The bindings to the native vtzero functions.
final VtzeroDartBindings bindings = VtzeroDartBindings(_dylib);
