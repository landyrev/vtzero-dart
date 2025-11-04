import 'dart:io';

void main(List<String> args) async {
  // Determine package root - if running from hook/ directory, go up one level
  // If running from package root, use current directory
  final currentDir = Directory.current.absolute;
  final packageRoot = currentDir.path.endsWith('hook')
      ? currentDir.parent
      : currentDir;
  final packageRootPath = packageRoot.path;
  final packageRootUri = packageRoot.uri;
  final srcDir = packageRootUri.resolve('src/').toFilePath();
  final buildDir = packageRootUri
      .resolve('build/native_assets_build/')
      .toFilePath();

  // Detect platform and architecture
  final platform = Platform.operatingSystem;
  final architecture = await _getArchitecture();

  print('Building native assets for $platform ($architecture)...');

  // Create build directory
  await Directory(buildDir).create(recursive: true);

  // Run CMake build
  final cmakeResult = await Process.run('cmake', [
    '-B',
    buildDir,
    '-S',
    srcDir,
    '-DCMAKE_BUILD_TYPE=Release',
  ], workingDirectory: packageRootPath);

  if (cmakeResult.exitCode != 0) {
    print('CMake configuration failed:');
    print(cmakeResult.stderr);
    exit(1);
  }

  final buildResult = await Process.run('cmake', [
    '--build',
    buildDir,
    '--config',
    'Release',
  ], workingDirectory: packageRootPath);

  if (buildResult.exitCode != 0) {
    print('CMake build failed:');
    print(buildResult.stderr);
    exit(1);
  }

  // Find the built library
  String libraryName;
  String libraryPath;

  if (platform == 'macos' || platform == 'ios') {
    libraryName = 'libvtzero_dart.dylib';
    libraryPath = '$buildDir/$libraryName';
  } else if (platform == 'linux' || platform == 'android') {
    libraryName = 'libvtzero_dart.so';
    libraryPath = '$buildDir/$libraryName';
  } else if (platform == 'windows') {
    libraryName = 'vtzero_dart.dll';
    libraryPath = '$buildDir/Release/$libraryName';
    if (!await File(libraryPath).exists()) {
      libraryPath = '$buildDir/$libraryName';
    }
  } else {
    print('Unsupported platform: $platform');
    exit(1);
  }

  final builtLibrary = File(libraryPath);
  if (!await builtLibrary.exists()) {
    print('Built library not found at: $libraryPath');
    print('Build directory contents:');
    await _listDirectory(buildDir);
    exit(1);
  }

  // Create native_assets directory structure
  final nativeAssetsDir = packageRootUri
      .resolve('native_assets/$platform/$architecture/')
      .toFilePath();
  await Directory(nativeAssetsDir).create(recursive: true);

  // Copy library to native_assets directory
  final targetPath = '$nativeAssetsDir$libraryName';
  await builtLibrary.copy(targetPath);

  print('Native asset built successfully: $targetPath');
}

Future<String> _getArchitecture() async {
  if (Platform.isMacOS || Platform.isIOS) {
    final result = await Process.run('uname', ['-m']);
    return result.stdout.toString().trim();
  } else if (Platform.isLinux) {
    final result = await Process.run('uname', ['-m']);
    return result.stdout.toString().trim();
  } else if (Platform.isWindows) {
    // Default to x64 for Windows
    return 'x64';
  } else {
    return 'unknown';
  }
}

Future<void> _listDirectory(String dir) async {
  try {
    final contents = await Directory(dir).list(recursive: true).toList();
    for (final entity in contents) {
      print('  ${entity.path}');
    }
  } catch (e) {
    print('  Error listing directory: $e');
  }
}
