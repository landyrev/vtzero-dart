import 'dart:io';

void main(List<String> args) async {
  // Parse command line arguments
  final buildAll = args.contains('--all') || args.contains('-a');
  final platforms = <String>[];

  if (buildAll) {
    // Build for all supported platforms
    platforms.addAll(['macos', 'linux', 'windows', 'ios', 'android']);
  } else {
    // Parse specific platforms from args
    for (int i = 0; i < args.length; i++) {
      if (args[i] == '--platform' || args[i] == '-p') {
        if (i + 1 < args.length) {
          platforms.add(args[i + 1]);
        }
      }
    }

    // If no platforms specified, build for current platform
    if (platforms.isEmpty) {
      platforms.add(Platform.operatingSystem);
    }
  }

  // Determine package root - if running from hook/ directory, go up one level
  // If running from package root, use current directory
  final currentDir = Directory.current.absolute;
  final packageRoot = currentDir.path.endsWith('hook')
      ? currentDir.parent
      : currentDir;
  final packageRootPath = packageRoot.path;
  final packageRootUri = packageRoot.uri;

  // Build for each requested platform
  bool allSucceeded = true;
  for (final platform in platforms) {
    try {
      final success = await _buildForPlatform(
        platform: platform,
        packageRoot: packageRoot,
        packageRootPath: packageRootPath,
        packageRootUri: packageRootUri,
      );
      if (!success) {
        allSucceeded = false;
        print('Failed to build for $platform');
      }
    } catch (e) {
      print('Error building for $platform: $e');
      allSucceeded = false;
    }
  }

  if (!allSucceeded) {
    exit(1);
  }
}

Future<bool> _buildForPlatform({
  required String platform,
  required Directory packageRoot,
  required String packageRootPath,
  required Uri packageRootUri,
}) async {
  // Get architectures for this platform
  final architectures = await _getArchitecturesForPlatform(platform);

  if (architectures.isEmpty) {
    print('No architectures found for platform: $platform');
    return false;
  }

  final srcDir = packageRootUri.resolve('src/').toFilePath();
  bool allSucceeded = true;

  for (final architecture in architectures) {
    print('Building native library for $platform ($architecture)...');

    final buildDir = packageRootUri
        .resolve('build/native_assets_build/$platform/$architecture/')
        .toFilePath();

    // Create build directory
    await Directory(buildDir).create(recursive: true);

    // Run CMake build with platform-specific settings
    final cmakeArgs = [
      '-B',
      buildDir,
      '-S',
      srcDir,
      '-DCMAKE_BUILD_TYPE=Release',
    ];

    // Add platform-specific CMake configuration
    if (platform == 'ios') {
      // iOS requires special toolchain - use Xcode
      if (Platform.operatingSystem != 'macos') {
        print('  iOS can only be built on macOS');
        allSucceeded = false;
        continue;
      }
      // iOS builds typically use Xcode, but we can try with CMake
      // Note: This is a simplified approach - production builds should use Xcode
      cmakeArgs.addAll([
        '-DCMAKE_SYSTEM_NAME=iOS',
        '-DCMAKE_OSX_ARCHITECTURES=$architecture',
      ]);
      if (architecture == 'x86_64') {
        // iOS Simulator
        cmakeArgs.addAll(['-DCMAKE_OSX_SYSROOT=iphonesimulator']);
      } else {
        // iOS Device
        cmakeArgs.addAll(['-DCMAKE_OSX_SYSROOT=iphoneos']);
      }
    } else if (platform == 'android') {
      // Android requires NDK
      final ndkPath =
          Platform.environment['ANDROID_NDK_HOME'] ??
          Platform.environment['ANDROID_NDK_ROOT'] ??
          Platform.environment['ANDROID_NDK'];
      if (ndkPath == null || !await Directory(ndkPath).exists()) {
        print(
          '  Android NDK not found. Set ANDROID_NDK_HOME environment variable.',
        );
        print('  Skipping Android build for $architecture');
        allSucceeded = false;
        continue;
      }
      // Android CMake toolchain
      final toolchainFile = '$ndkPath/build/cmake/android.toolchain.cmake';
      if (!await File(toolchainFile).exists()) {
        print('  Android toolchain file not found at: $toolchainFile');
        print('  Skipping Android build for $architecture');
        allSucceeded = false;
        continue;
      }

      // Map architecture to Android ABI
      String androidAbi;
      switch (architecture) {
        case 'arm64-v8a':
          androidAbi = 'arm64-v8a';
          break;
        case 'armeabi-v7a':
          androidAbi = 'armeabi-v7a';
          break;
        case 'x86':
          androidAbi = 'x86';
          break;
        case 'x86_64':
          androidAbi = 'x86_64';
          break;
        default:
          print('  Unsupported Android architecture: $architecture');
          allSucceeded = false;
          continue;
      }

      cmakeArgs.addAll([
        '-DCMAKE_TOOLCHAIN_FILE=$toolchainFile',
        '-DANDROID_ABI=$androidAbi',
        '-DANDROID_PLATFORM=android-24', // Minimum API level
        '-DANDROID_STL=c++_shared',
      ]);
    } else if (platform == 'windows' && Platform.operatingSystem != 'windows') {
      print('  Warning: Windows cross-compilation may not be supported');
      print('  Skipping Windows build on non-Windows platform');
      allSucceeded = false;
      continue;
    }

    final cmakeResult = await Process.run(
      'cmake',
      cmakeArgs,
      workingDirectory: packageRootPath,
    );

    if (cmakeResult.exitCode != 0) {
      print('  CMake configuration failed for $platform ($architecture):');
      print('  ${cmakeResult.stderr}');
      allSucceeded = false;
      continue;
    }

    final buildResult = await Process.run('cmake', [
      '--build',
      buildDir,
      '--config',
      'Release',
    ], workingDirectory: packageRootPath);

    if (buildResult.exitCode != 0) {
      print('  CMake build failed for $platform ($architecture):');
      print('  ${buildResult.stderr}');
      allSucceeded = false;
      continue;
    }

    // Find the built library
    String libraryName;
    String libraryPath;

    if (platform == 'macos') {
      libraryName = 'libvtzero_dart.dylib';
      libraryPath = '$buildDir/$libraryName';
    } else if (platform == 'ios') {
      // iOS builds as a framework or dylib depending on setup
      // For simplicity, we'll look for dylib (or framework structure)
      libraryName = 'libvtzero_dart.dylib';
      libraryPath = '$buildDir/$libraryName';
      // iOS might also build as a framework
      if (!await File(libraryPath).exists()) {
        final frameworkPath = '$buildDir/vtzero_dart.framework/vtzero_dart';
        if (await File(frameworkPath).exists()) {
          libraryPath = frameworkPath;
          libraryName = 'vtzero_dart.framework/vtzero_dart';
        }
      }
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
      print('  Unsupported platform: $platform');
      allSucceeded = false;
      continue;
    }

    final builtLibrary = File(libraryPath);
    if (!await builtLibrary.exists()) {
      print('  Built library not found at: $libraryPath');
      print('  Build directory contents:');
      await _listDirectory(buildDir);
      allSucceeded = false;
      continue;
    }

    // Create lib/native directory structure
    final nativeLibDir = packageRootUri
        .resolve('lib/native/$platform/$architecture/')
        .toFilePath();
    await Directory(nativeLibDir).create(recursive: true);

    // Copy library to lib/native directory
    final targetPath = '$nativeLibDir$libraryName';
    await builtLibrary.copy(targetPath);

    print('  Native library built successfully: $targetPath');
  }

  return allSucceeded;
}

Future<List<String>> _getArchitecturesForPlatform(String platform) async {
  if (platform == 'macos') {
    // On macOS, we can build for both arm64 and x86_64
    if (Platform.operatingSystem == 'macos') {
      final currentArch = await _getArchitecture();
      // Try to build for current architecture and potentially others
      final archs = <String>[currentArch];
      // If on Apple Silicon, also try x86_64 (if Rosetta is available)
      if (currentArch == 'arm64') {
        // Check if we can build for x86_64 via Rosetta
        archs.add('x86_64');
      }
      return archs;
    } else {
      // On non-macOS, can't build macOS binaries
      return [];
    }
  } else if (platform == 'ios') {
    // iOS can only be built on macOS
    if (Platform.operatingSystem == 'macos') {
      // iOS architectures: arm64 (device), x86_64 (simulator)
      // For now, build for both - in production you might want to use Xcode
      return ['arm64', 'x86_64'];
    } else {
      return [];
    }
  } else if (platform == 'android') {
    // Android can be built on macOS, Linux, or Windows with NDK
    // Common Android ABIs
    return ['arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64'];
  } else if (platform == 'linux') {
    if (Platform.operatingSystem == 'linux') {
      final currentArch = await _getArchitecture();
      return [currentArch];
    } else {
      // Cross-compilation for Linux would require additional setup
      return [];
    }
  } else if (platform == 'windows') {
    if (Platform.operatingSystem == 'windows') {
      return ['x64'];
    } else {
      // Cross-compilation for Windows requires mingw-w64 or similar
      return [];
    }
  } else {
    return [];
  }
}

Future<String> _getArchitecture() async {
  if (Platform.isMacOS || Platform.isIOS) {
    final result = await Process.run('uname', ['-m']);
    final arch = result.stdout.toString().trim();
    // Normalize architecture names
    if (arch == 'arm64' || arch == 'aarch64') {
      return 'arm64';
    } else if (arch == 'x86_64' || arch == 'amd64') {
      return 'x86_64';
    }
    return arch;
  } else if (Platform.isLinux) {
    final result = await Process.run('uname', ['-m']);
    final arch = result.stdout.toString().trim();
    // Normalize architecture names
    if (arch == 'x86_64' || arch == 'amd64') {
      return 'x86_64';
    } else if (arch == 'arm64' || arch == 'aarch64') {
      return 'arm64';
    } else if (arch.startsWith('arm')) {
      return 'arm';
    }
    return arch;
  } else if (Platform.isWindows) {
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
