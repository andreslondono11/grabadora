import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:external_path/external_path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileManager {
  // Rutas
  static const String _internalRootPath = '/storage/emulated/0/GrabadoraProPZ';
  static const String _sdFolderName = 'GrabadoraProPZ';
  static const MethodChannel _storageChannel = MethodChannel(
    'com.tuapp.grabadora/storage',
  );

  // Estado visible para la UI
  Directory? currentDirectory;
  List<FileSystemEntity> currentEntities = [];
  final List<Directory> navigationHistory = [];

  // Inicialización completa
  Future<void> initializeRootDirectory(VoidCallback onStateChanged) async {
    Directory rootDir = Directory('');
    final prefs = await SharedPreferences.getInstance();
    final String? customPath = prefs.getString('external_custom_path');
    final String? locationType = prefs.getString('storage_location');
    bool useCustom = false;

    // 1. Lógica SD Externa
    if (locationType == 'externalCustom' &&
        customPath != null &&
        customPath.isNotEmpty) {
      try {
        Directory dirCandidate = Directory(customPath);
        if (await dirCandidate.exists()) {
          rootDir = dirCandidate;
          useCustom = true;
        } else {
          // Intento de recuperación si la ruta guardada falla
          Directory? sdRoot = await _findSdCardRoot();
          if (sdRoot != null) {
            Directory newAppDir = Directory('${sdRoot.path}/$_sdFolderName');
            if (!(await newAppDir.exists()))
              await newAppDir.create(recursive: true);
            rootDir = newAppDir;
            useCustom = true;
            await prefs.setString('external_custom_path', newAppDir.path);
          } else {
            useCustom = false;
          }
        }
      } catch (e) {
        debugPrint("Error SD: $e");
        useCustom = false;
      }
    }

    // 2. Si no es SD, usar Interna
    if (!useCustom) {
      rootDir = await _getInternalDirectory();
    }

    // Crear carpeta si falta
    if (!await rootDir.exists()) await rootDir.create(recursive: true);

    // Actualizar estado
    currentDirectory = rootDir;
    navigationHistory.clear();
    navigationHistory.add(rootDir);

    await loadDirectoryContents();
    onStateChanged(); // Notifica a la UI para redibujar
  }

  Future<Directory> _getInternalDirectory() async {
    Directory dir = Directory(_internalRootPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory?> _findSdCardRoot() async {
    try {
      var paths = await ExternalPath.getExternalStorageDirectories();
      if (paths != null && paths.isNotEmpty) {
        for (String path in paths) {
          if (!path.contains("emulated")) return Directory(path);
        }
      }
    } catch (e) {
      debugPrint("Error buscando SD: $e");
    }
    return null;
  }

  Future<void> loadDirectoryContents() async {
    if (currentDirectory == null) return;
    try {
      List<FileSystemEntity> entities = currentDirectory!.listSync();
      entities.sort((a, b) {
        bool aIsDir = a is Directory;
        bool bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      currentEntities = entities;
    } catch (e) {
      debugPrint("Error leyendo dir: $e");
    }
  }

  // Acciones de Navegación
  void navigateIntoDirectory(Directory dir, VoidCallback onStateChanged) {
    currentDirectory = dir;
    navigationHistory.add(dir);
    loadDirectoryContents().then((_) => onStateChanged());
  }

  void navigateBack(VoidCallback onStateChanged) {
    if (navigationHistory.length > 1) {
      navigationHistory.removeLast();
      currentDirectory = navigationHistory.last;
      loadDirectoryContents().then((_) => onStateChanged());
    }
  }

  Future<void> syncLocationWithSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentPath = currentDirectory?.path ?? "";
    if (currentPath.startsWith(_internalRootPath)) {
      await prefs.setString('storage_location', 'appPrivate');
      await prefs.setString('external_custom_path', '');
    } else {
      await prefs.setString('storage_location', 'externalCustom');
      await prefs.setString('external_custom_path', currentPath);
    }
  }

  // --- Acciones de Archivo (CRUD) ---

  Future<void> createFolder(
    String name,
    BuildContext context,
    VoidCallback onUpdate,
  ) async {
    String folderName = name.replaceAll(RegExp(r'[\\/:"*?<>|]'), '');
    if (folderName.isEmpty) return;
    try {
      String currentPath = currentDirectory!.path;
      if (!currentPath.endsWith(Platform.pathSeparator))
        currentPath += Platform.pathSeparator;
      final newPath = "$currentPath$folderName";
      final newDir = Directory(newPath);
      if (await newDir.exists()) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("La carpeta ya existe")));
        return;
      }
      await newDir.create(recursive: true);
      await loadDirectoryContents();
      onUpdate();
    } catch (e) {
      debugPrint("Error creando carpeta: $e");
    }
  }

  Future<void> renameItem(
    FileSystemEntity entity,
    String newName,
    VoidCallback onUpdate,
  ) async {
    try {
      String parentPath = entity.parent.path;
      if (!parentPath.endsWith(Platform.pathSeparator))
        parentPath += Platform.pathSeparator;
      String newPath = "$parentPath$newName";
      if (entity is File) {
        String ext = entity.path.split('.').last;
        newPath = "$newPath.$ext";
      }
      await entity.rename(newPath);
      await loadDirectoryContents();
      onUpdate();
    } catch (e) {
      debugPrint("Error renombrando: $e");
    }
  }

  Future<void> deleteItem(
    FileSystemEntity entity,
    VoidCallback onUpdate,
  ) async {
    try {
      await entity.delete(recursive: true);
      await loadDirectoryContents();
      onUpdate();
    } catch (e) {
      debugPrint("Error eliminando: $e");
    }
  }

  // Lógica compleja de MOVER archivo (Extraída tal cual para que funcione igual)
  Future<void> moveItem(
    FileSystemEntity entity,
    BuildContext context,
    VoidCallback onUpdate,
  ) async {
    List<Directory> availableFolders = [];
    String currentPath = currentDirectory?.path ?? "";
    bool isInternalSource =
        currentPath.startsWith(_internalRootPath) ||
        !currentPath.contains("/storage/");

    if (isInternalSource) {
      try {
        Directory internalRoot = await _getInternalDirectory();
        if (await internalRoot.exists()) {
          availableFolders.add(internalRoot);
          List<FileSystemEntity> entities = internalRoot.listSync();
          for (var e in entities) if (e is Directory) availableFolders.add(e);
        }
      } catch (e) {
        debugPrint("Error interno: $e");
      }
    } else {
      try {
        Directory? sdRoot = await _findSdCardRoot();
        if (sdRoot != null) {
          Directory appSdDir = Directory('${sdRoot.path}/$_sdFolderName');
          if (await appSdDir.exists())
            _getAllSubDirectoriesRecursive(appSdDir, availableFolders);
        }
      } catch (e) {
        debugPrint("Error externo: $e");
      }
    }

    // Filtrar duplicados
    final uniquePaths = <String, Directory>{};
    for (var folder in availableFolders)
      uniquePaths[_normalizePath(folder.path)] = folder;
    List<Directory> finalList = uniquePaths.values.toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isInternalSource ? "Elegir destino (Interna)" : "Elegir destino (SD)",
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: finalList.isEmpty
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No se encontraron carpetas."),
                    ElevatedButton(
                      onPressed: () async {
                        Directory? sdRoot = await _findSdCardRoot();
                        if (sdRoot != null) {
                          Directory newAppDir = Directory(
                            '${sdRoot.path}/$_sdFolderName',
                          );
                          if (!(await newAppDir.exists()))
                            await newAppDir.create(recursive: true);
                          Navigator.pop(context);
                          await _performMove(
                            entity,
                            newAppDir,
                            context,
                            onUpdate,
                          );
                        }
                      },
                      child: const Text("Crear carpeta raíz"),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: finalList.length,
                  itemBuilder: (context, index) {
                    Directory folder = finalList[index];
                    String folderName = folder.path
                        .split(Platform.pathSeparator)
                        .last;
                    if (folderName.isEmpty) folderName = "Raíz";
                    bool isCurrentFolder =
                        _normalizePath(folder.path) ==
                        _normalizePath(entity.parent.path);
                    return ListTile(
                      title: Text(
                        folderName,
                        style: TextStyle(
                          color: isCurrentFolder ? Colors.grey : null,
                        ),
                      ),
                      onTap: isCurrentFolder
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _performMove(
                                entity,
                                folder,
                                context,
                                onUpdate,
                              );
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
  }

  Future<void> _performMove(
    FileSystemEntity entity,
    Directory targetDir,
    BuildContext context,
    VoidCallback onUpdate,
  ) async {
    try {
      final File sourceFile = File(entity.path);
      if (!await sourceFile.exists()) return;
      final String fileName = entity.path.split(Platform.pathSeparator).last;
      String targetPath = targetDir.path;
      if (!targetPath.endsWith(Platform.pathSeparator))
        targetPath += Platform.pathSeparator;
      final String newPath = '$targetPath$fileName';
      final File destFile = File(newPath);
      if (await destFile.exists()) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("El archivo ya existe")));
        return;
      }

      bool success = false;
      try {
        success =
            (await _storageChannel.invokeMethod<bool>('moveFileUniversal', {
              'sourcePath': sourceFile.path,
              'targetPath': newPath,
            })) ??
            false;
      } catch (e) {
        debugPrint("Error canal nativo: $e");
      }

      if (!success) {
        await sourceFile.rename(newPath);
        success = true;
      }

      if (success) {
        if (Platform.isAndroid) {
          try {
            await Process.run('am', [
              'broadcast',
              '-a',
              'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
              '-d',
              'file://$newPath',
            ]);
          } catch (e) {}
        }
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Movido exitosamente"),
              backgroundColor: Colors.green,
            ),
          );
        onUpdate();
      }
    } catch (e) {
      debugPrint("Error moviendo: $e");
    }
  }

  void _getAllSubDirectoriesRecursive(Directory dir, List<Directory> list) {
    list.add(dir);
    try {
      for (var e in dir.listSync()) {
        if (e is Directory) _getAllSubDirectoriesRecursive(e, list);
      }
    } catch (e) {}
  }

  String _normalizePath(String path) {
    String normalized = path.trim();
    while (normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
