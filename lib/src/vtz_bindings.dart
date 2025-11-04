import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../vtzero_dart_bindings_generated.dart';
import 'vtz_exceptions.dart';

const String _libName = 'vtzero_dart';

/// The dynamic library in which the symbols for vtzero can be found.
final DynamicLibrary _dylib = () {
  // Try to find the library in common locations
  final possiblePaths = <String>[];

  // Get architecture (for pre-built binaries)
  final architecture = _getArchitecture();
  final platform = Platform.operatingSystem;

  if (Platform.isMacOS || Platform.isIOS) {
    // Try pre-built binaries first (for published packages)
    possiblePaths.add('lib/native/$platform/$architecture/lib$_libName.dylib');
    possiblePaths.add(
      '../lib/native/$platform/$architecture/lib$_libName.dylib',
    );
    possiblePaths.add(
      '../../lib/native/$platform/$architecture/lib$_libName.dylib',
    );
    // Try framework (for iOS/App bundles)
    possiblePaths.add('$_libName.framework/$_libName');
    // Try dylib in build directory (for tests/development)
    possiblePaths.add('build/lib$_libName.dylib');
    possiblePaths.add('../build/lib$_libName.dylib');
    possiblePaths.add('../../build/lib$_libName.dylib');
  } else if (Platform.isAndroid || Platform.isLinux) {
    // Try pre-built binaries first (for published packages)
    possiblePaths.add('lib/native/$platform/$architecture/lib$_libName.so');
    possiblePaths.add('../lib/native/$platform/$architecture/lib$_libName.so');
    possiblePaths.add(
      '../../lib/native/$platform/$architecture/lib$_libName.so',
    );
    // Try standard library paths
    possiblePaths.add('lib$_libName.so');
    // Try build directory (for tests/development)
    possiblePaths.add('build/lib$_libName.so');
    possiblePaths.add('../build/lib$_libName.so');
  } else if (Platform.isWindows) {
    // Try pre-built binaries first (for published packages)
    possiblePaths.add('lib/native/$platform/$architecture/$_libName.dll');
    possiblePaths.add('../lib/native/$platform/$architecture/$_libName.dll');
    possiblePaths.add('../../lib/native/$platform/$architecture/$_libName.dll');
    // Try standard library paths
    possiblePaths.add('$_libName.dll');
    // Try build directory (for tests/development)
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
    'Make sure the library is built and available. '
    'Run "dart scripts/build_native.dart" to build native libraries.',
  );
}();

/// Get the current architecture identifier
/// This should match the architecture names used in the build script
String _getArchitecture() {
  if (Platform.isMacOS || Platform.isIOS) {
    // Try to detect architecture - common values: arm64, x86_64
    // For macOS, we can check the system architecture
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      // Map common architecture names
      if (arch == 'arm64' || arch == 'aarch64') {
        return 'arm64';
      } else if (arch == 'x86_64' || arch == 'amd64') {
        return 'x86_64';
      }
      return arch; // Return as-is if unrecognized
    } catch (e) {
      // Fallback to arm64 for modern Macs
      return 'arm64';
    }
  } else if (Platform.isLinux) {
    try {
      final result = Process.runSync('uname', ['-m']);
      final arch = result.stdout.toString().trim();
      // Map common architecture names
      if (arch == 'x86_64' || arch == 'amd64') {
        return 'x86_64';
      } else if (arch == 'arm64' || arch == 'aarch64') {
        return 'arm64';
      } else if (arch.startsWith('arm')) {
        return 'arm';
      }
      return arch; // Return as-is if unrecognized
    } catch (e) {
      return 'x86_64'; // Default fallback
    }
  } else if (Platform.isWindows) {
    return 'x64';
  } else if (Platform.isAndroid) {
    // Android architectures: arm64-v8a, armeabi-v7a, x86, x86_64
    // This is a simplified detection - in practice you'd check the ABI
    return 'arm64-v8a'; // Common default
  } else {
    return 'unknown';
  }
}

/// The bindings to the native vtzero functions.
final VtzeroDartBindings bindings = VtzeroDartBindings(_dylib);

/// Check for exceptions and throw appropriate Dart exception if one occurred
void checkException() {
  final exceptionType = VtzExceptionType.fromInt(
    bindings.vtz_get_last_exception_type(),
  );
  if (exceptionType == VtzExceptionType.none) {
    return;
  }

  final messagePtr = bindings.vtz_get_last_exception_message();
  String message = '';
  if (messagePtr != nullptr) {
    message = messagePtr.cast<Utf8>().toDartString();
  }

  bindings.vtz_clear_exception();

  switch (exceptionType) {
    case VtzExceptionType.format:
      throw VtzFormatException(message);
    case VtzExceptionType.geometry:
      throw VtzGeometryException(message);
    case VtzExceptionType.type:
      throw VtzTypeException();
    case VtzExceptionType.version:
      throw VtzVersionException(message);
    case VtzExceptionType.outOfRange:
      throw VtzOutOfRangeException(message);
    case VtzExceptionType.none:
      break;
  }
}
