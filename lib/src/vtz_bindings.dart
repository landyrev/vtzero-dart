import 'dart:ffi';
import 'dart:io';
import '../vtzero_dart_bindings_generated.dart';

const String _libName = 'vtzero_dart';

/// The dynamic library in which the symbols for vtzero can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native vtzero functions.
final VtzeroDartBindings bindings = VtzeroDartBindings(_dylib);
