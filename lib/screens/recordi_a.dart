import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grabadora/screens/configuracion.dart'; // Asegúrate de que esta ruta existe
import 'package:grabadora/screens/tema.dart'; // Asegúrate de que esta ruta existe
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:external_path/external_path.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  // --- Grabadora ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;

  // Canal Nativo
  static const MethodChannel _storageChannel = MethodChannel(
    'com.tuapp.grabadora/storage',
  );

  AudioEncoder _selectedEncoder = AudioEncoder.aacLc;
  String _selectedExtension = 'm4a';

  Timer? _timer;
  int _recordDuration = 0;

  // --- Reproductor ---
  final AudioPlayer _player = AudioPlayer();

  String? _currentlyPlayingPath;
  bool _isSliderDragging = false;
  double _currentSliderValue = 0.0;
  Duration? _currentAudioDuration;

  // --- Navegación FÍSICA ---
  Directory? _currentDirectory;
  List<FileSystemEntity> _currentEntities = [];
  final List<Directory> _navigationHistory = [];

  // Ruta interna por defecto
  static const String _internalRootPath = '/storage/emulated/0/GrabadoraProPZ';

  // Ruta deseada en la SD
  static const String _sdFolderName = 'GrabadoraProPZ';

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _initializeRootDirectory();
    _checkDisclaimer();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _timer?.cancel();
    _player.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // UTILIDAD: Normalizar Rutas
  // --------------------------------------------------------------------------
  String _normalizePath(String path) {
    String normalized = path.trim();
    while (normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  // --------------------------------------------------------------------------
  // INICIALIZACIÓN Y NAVEGACIÓN
  // --------------------------------------------------------------------------

  Future<void> _initializeRootDirectory() async {
    Directory rootDir = Directory('');

    final prefs = await SharedPreferences.getInstance();
    final String? customPath = prefs.getString('external_custom_path');
    final String? locationType = prefs.getString('storage_location');
    //storage_location

    bool useCustom = false;

    // 1. Lógica para SD Externa
    if (locationType == 'externalCustom' &&
        customPath != null &&
        customPath.isNotEmpty) {
      try {
        Directory dirCandidate = Directory(customPath);

        if (await dirCandidate.exists()) {
          rootDir = dirCandidate;
          useCustom = true;
        } else {
          // Si no existe, buscamos SD y creamos la carpeta App
          Directory? sdRoot = await _findSdCardRoot();
          if (sdRoot != null) {
            Directory newAppDir = Directory('${sdRoot.path}/$_sdFolderName');
            if (!(await newAppDir.exists())) {
              await newAppDir.create(recursive: true);
            }
            rootDir = newAppDir;
            useCustom = true;
            await prefs.setString('external_custom_path', newAppDir.path);
          } else {
            useCustom = false;
          }
        }
      } catch (e) {
        debugPrint("Error accediendo a SD: $e");
        useCustom = false;
      }
    }

    // 2. Si no se usó custom, usar Interna
    if (!useCustom) {
      rootDir = await _getInternalDirectory();
    }

    // Crear carpeta si no existe
    try {
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint("Error creando carpeta raíz: $e");
    }

    if (mounted) {
      setState(() {
        _currentDirectory = rootDir;
        _navigationHistory.clear();
        _navigationHistory.add(rootDir);
      });

      _loadDirectoryContents();
      await _syncLocationWithSettings();

      if (useCustom) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Guardando en SD: GrabadoraProPZ"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --- CORREGIDO: Usar external_path para encontrar SD ---
  Future<Directory?> _findSdCardRoot() async {
    try {
      var externalStorageDirectories =
          await ExternalPath.getExternalStorageDirectories();

      if (externalStorageDirectories!.isNotEmpty) {
        for (String path in externalStorageDirectories!) {
          if (!path.contains("emulated")) {
            return Directory(path);
          }
        }
      }
    } catch (e) {
      debugPrint("Error buscando raíz SD con external_path: $e");
    }
    return null;
  }

  Future<void> _syncLocationWithSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final currentPath = _currentDirectory?.path ?? "";

    if (currentPath.startsWith(_internalRootPath)) {
      await prefs.setString('storage_location', 'appPrivate');
      await prefs.setString('external_custom_path', '');
    } else {
      await prefs.setString('storage_location', 'externalCustom');
      await prefs.setString('external_custom_path', currentPath);
    }
  }

  Future<Directory> _getInternalDirectory() async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = Directory(_internalRootPath);
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      dir = Directory(appDocDir.path);
    }
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _loadDirectoryContents() async {
    if (_currentDirectory == null) return;
    try {
      List<FileSystemEntity> entities = _currentDirectory!.listSync();
      entities.sort((a, b) {
        bool aIsDir = a is Directory;
        bool bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });
      if (mounted) setState(() => _currentEntities = entities);
    } catch (e) {
      debugPrint("Error leyendo directorio: $e");
    }
  }

  void _navigateIntoDirectory(Directory dir) {
    setState(() {
      _currentDirectory = dir;
      _navigationHistory.add(dir);
    });
    _loadDirectoryContents();
    _syncLocationWithSettings();
  }

  void _navigateBack() {
    if (_navigationHistory.length > 1) {
      _navigationHistory.removeLast();
      Directory parentDir = _navigationHistory.last;
      setState(() {
        _currentDirectory = parentDir;
      });
      _loadDirectoryContents();
      _syncLocationWithSettings();
    }
  }

  // --------------------------------------------------------------------------
  // DISCLAIMER
  // --------------------------------------------------------------------------
  Future<void> _checkDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('has_seen_disclaimer') ?? false) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              "Aviso Legal",
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Esta aplicación es una herramienta de grabación de audio personal.\n\n"
          "El usuario es el único responsable del contenido que grabe, almacene y comparta. "
          "Los desarrolladores no se hacen responsables del uso indebido de esta aplicación.\n\n"
          "Al continuar, aceptas estos términos.",
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.8),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              "Aceptar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await prefs.setBool('has_seen_disclaimer', true);
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
  // --------------------------------------------------------------------------
  // ACCIONES DE ARCHIVO
  // --------------------------------------------------------------------------

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text("Nueva Carpeta"),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: Colors.blueGrey, // cursor azul grisáceo
            style: TextStyle(
              color: isDark
                  ? Colors.white
                  : Colors.black, // texto adaptado al tema
            ),
            decoration: const InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.blueGrey,
                ), // borde azul grisáceo
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String inputName = controller.text.trim();
                if (inputName.isEmpty) return;
                String folderName = inputName.replaceAll(
                  RegExp(r'[\\/:"*?<>|]'),
                  '',
                );
                if (folderName.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nombre inválido")),
                    );
                  }
                  return;
                }
                String currentPath = _currentDirectory!.path;
                if (!currentPath.endsWith(Platform.pathSeparator)) {
                  currentPath += Platform.pathSeparator;
                }
                final newPath = "$currentPath$folderName";
                final newDir = Directory(newPath);
                try {
                  if (await newDir.exists()) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("La carpeta '$folderName' ya existe"),
                        ),
                      );
                    }
                    return;
                  }
                  await newDir.create(recursive: true);
                  _loadDirectoryContents();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Carpeta creada")),
                    );
                  }
                } catch (e) {
                  debugPrint("Error creando carpeta: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error de permiso")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey, // fondo azul grisáceo
                foregroundColor: Colors.white, // texto blanco
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Crear",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameItem(FileSystemEntity entity) async {
    String initialName = entity.path.split(Platform.pathSeparator).last;
    if (entity is File && initialName.contains(".")) {
      initialName = initialName.substring(0, initialName.lastIndexOf("."));
    }
    final controller = TextEditingController(text: initialName);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text("Renombrar"),
          content: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: Colors.blueGrey, // cursor azul grisáceo
            style: TextStyle(
              color: isDark
                  ? Colors.white
                  : Colors.black, // texto adaptado al tema
            ),
            decoration: const InputDecoration(
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.blueGrey,
                ), // borde azul grisáceo
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String inputName = controller.text.trim();
                inputName = inputName.replaceAll(RegExp(r'[\\/:"*?<>|]'), '');
                String finalName = inputName.isEmpty
                    ? "Grabación ${DateTime.now().millisecondsSinceEpoch}"
                    : inputName;
                String parentPath = entity.parent.path;
                if (!parentPath.endsWith(Platform.pathSeparator)) {
                  parentPath += Platform.pathSeparator;
                }
                String newPath = "$parentPath$finalName";
                if (entity is File) {
                  String ext = entity.path.split('.').last;
                  newPath = "$newPath.$ext";
                }
                try {
                  if (entity is File && _currentlyPlayingPath == entity.path) {
                    await _player.stop();
                    setState(() {
                      _currentlyPlayingPath = null;
                      _currentSliderValue = 0.0;
                    });
                  }
                  await Future.delayed(const Duration(milliseconds: 200));
                  await entity.rename(newPath);
                  await _loadDirectoryContents();
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  debugPrint("Error renombrando: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Error al renombrar")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey, // fondo azul grisáceo
                foregroundColor: Colors.white, // texto blanco
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Guardar",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteItem(FileSystemEntity entity) async {
    String entityName = entity.path.split(Platform.pathSeparator).last;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar"),
        content: Text("¿Estás seguro de eliminar $entityName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.blueGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        if (entity is File && _currentlyPlayingPath == entity.path) {
          await _player.stop();
          setState(() {
            _currentlyPlayingPath = null;
            _currentSliderValue = 0.0;
          });
        }
        await entity.delete(recursive: true);
        _loadDirectoryContents();
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("$entityName eliminado")));
      } catch (e) {
        debugPrint("Error eliminando: $e");
      }
    }
  }

  Future<void> _moveItem(FileSystemEntity entity) async {
    List<Directory> availableFolders = [];
    String currentPath = _currentDirectory?.path ?? "";

    // DETERMINAR SI ESTAMOS EN INTERNA O EXTERNA
    bool isInternalSource =
        currentPath.startsWith(_internalRootPath) ||
        !currentPath.contains("/storage/");

    if (isInternalSource) {
      // --- ESTAMOS EN INTERNA ---
      try {
        Directory internalRoot = await _getInternalDirectory();
        if (await internalRoot.exists()) {
          availableFolders.add(internalRoot);
          List<FileSystemEntity> entities = internalRoot.listSync();
          for (var e in entities) {
            if (e is Directory) availableFolders.add(e);
          }
        }
      } catch (e) {
        debugPrint("Error escaneando interna: $e");
      }
    } else {
      // --- ESTAMOS EN EXTERNA (SD) ---
      try {
        Directory? sdRoot = await _findSdCardRoot();
        if (sdRoot != null) {
          Directory appSdDir = Directory('${sdRoot.path}/$_sdFolderName');
          if (await appSdDir.exists()) {
            _getAllSubDirectoriesRecursive(appSdDir, availableFolders);
          }
        }
      } catch (e) {
        debugPrint("Error escaneando externa: $e");
      }
    }

    // Eliminar duplicados
    final uniquePaths = <String, Directory>{};
    for (var folder in availableFolders) {
      uniquePaths[_normalizePath(folder.path)] = folder;
    }
    List<Directory> finalList = uniquePaths.values.toList();

    if (!mounted) return;

    // --- DIALOGO ---
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            isInternalSource
                ? "Elegir destino (Interna)"
                : "Elegir destino (SD)",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 450,
            child: finalList.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "No se encontraron carpetas en 'GrabadoraProPZ'.",
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "¿Quieres crear la carpeta raíz 'GrabadoraProPZ' y mover el archivo allí?",
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Directory? sdRoot = await _findSdCardRoot();
                          if (sdRoot != null) {
                            Directory newAppDir = Directory(
                              '${sdRoot.path}/$_sdFolderName',
                            );
                            if (!(await newAppDir.exists())) {
                              await newAppDir.create(recursive: true);
                            }
                            Navigator.pop(context);
                            await _performMove(entity, newAppDir);
                          } else {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Error: No se detectó la tarjeta SD",
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.create_new_folder,
                          color: Colors.white,
                        ),
                        label: const Text("Crear carpeta y Mover"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
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

                      IconData icon = isInternalSource
                          ? Icons.folder
                          : Icons.sd_storage;
                      Color iconColor = isInternalSource
                          ? Colors.yellow[700]!
                          : Colors.blueGrey;

                      return ListTile(
                        leading: Icon(icon, color: iconColor),
                        title: Text(
                          folderName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCurrentFolder
                                ? Colors.grey
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        onTap: () async {
                          if (isCurrentFolder) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Ya está en esta carpeta"),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          await _performMove(entity, folder);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          ],
        );
      },
    );
  }

  // Función recursiva para obtener TODAS las carpetas sin excepción
  void _getAllSubDirectoriesRecursive(Directory dir, List<Directory> list) {
    list.add(dir);
    try {
      List<FileSystemEntity> entities = dir.listSync();
      for (var e in entities) {
        if (e is Directory) {
          _getAllSubDirectoriesRecursive(e, list);
        }
      }
    } catch (e) {
      debugPrint("No se pudo leer subcarpeta de $dir");
    }
  }

  Future<void> _performMove(
    FileSystemEntity entity,
    Directory targetDir,
  ) async {
    try {
      final File sourceFile = File(entity.path);
      if (!await sourceFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El archivo origen ya no existe")),
        );
        return;
      }
      final String fileName = entity.path.split(Platform.pathSeparator).last;
      String targetPath = targetDir.path;
      if (!targetPath.endsWith(Platform.pathSeparator))
        targetPath += Platform.pathSeparator;
      final String newPath = '$targetPath$fileName';
      final File destFile = File(newPath);
      if (await destFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El archivo ya existe en el destino")),
        );
        return;
      }
      if (_currentlyPlayingPath == entity.path) {
        await _player.stop();
        setState(() {
          _currentlyPlayingPath = null;
          _currentSliderValue = 0.0;
        });
        await Future.delayed(const Duration(milliseconds: 200));
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
        debugPrint("Fallo canal nativo, intentando Dart IO: $e");
      }
      if (!success) {
        debugPrint("Moviendo con Dart IO");
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
          } catch (e) {
            debugPrint("Error escaneando media: $e");
          }
        }
        if (!mounted) return;
        _loadDirectoryContents();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Archivo movido exitosamente"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception("Error al mover archivo");
      }
    } catch (e) {
      debugPrint("Error moviendo archivo: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  // --------------------------------------------------------------------------
  // REPRODUCTOR
  // --------------------------------------------------------------------------

  void _initPlayer() {
    _player.positionStream.listen((position) {
      if (mounted && !_isSliderDragging && _currentlyPlayingPath != null) {
        final duration = _player.duration;
        if (duration != null && duration.inMilliseconds > 0) {
          setState(
            () => _currentSliderValue =
                position.inMilliseconds / duration.inMilliseconds,
          );
        }
      }
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _currentSliderValue = 0.0;
          _currentlyPlayingPath = null;
        });
        _player.stop();
        _player.seek(Duration.zero);
      }
    });
  }

  void _onSliderChangeStart() {
    setState(() => _isSliderDragging = true);
  }

  void _onSliderChangeEnd(double value) async {
    setState(() => _isSliderDragging = false);
    final duration = _player.duration;
    if (duration != null) {
      final position = duration * value;
      await _player.seek(position);
    }
  }

  Future<void> _togglePlay(File entity) async {
    String path = entity.path;
    if (_currentlyPlayingPath == path) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    try {
      await _player.setFilePath(path);
      final duration = _player.duration;
      setState(() {
        _currentlyPlayingPath = path;
        _currentSliderValue = 0.0;
        _currentAudioDuration = duration;
      });
      await _player.play();
    } catch (e) {
      debugPrint("Error reproduciendo: $e");
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "00:00";
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // --------------------------------------------------------------------------
  // GRABACIÓN
  // --------------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_player.playing) {
      await _player.stop();
      setState(() {
        _currentlyPlayingPath = null;
        _currentSliderValue = 0.0;
      });
    }
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String dirPath = _currentDirectory!.path;
      if (!dirPath.endsWith(Platform.pathSeparator))
        dirPath += Platform.pathSeparator;
      final String filePath = '${dirPath}rec_$timestamp.$_selectedExtension';
      await _audioRecorder.start(
        RecordConfig(encoder: _selectedEncoder, bitRate: 128000),
        path: filePath,
      );
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordDuration = 0;
      });
      _startTimer();
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint("Error iniciando grabación: $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al grabar. Revisa permisos.")),
        );
    }
  }

  Future<void> _pauseRecording() async {
    await _audioRecorder.pause();
    _timer?.cancel();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await _audioRecorder.resume();
    _startTimer();
    setState(() => _isPaused = false);
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = 0;
    });
    await WakelockPlus.disable();
    _loadDirectoryContents();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatRecordDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        if (_navigationHistory.length > 1) {
          _navigateBack();
        } else {
          if (context.mounted) SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text(
            'Grabadora Pro PZ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: [
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: theme.cardColor,
                  title: const Text("Versión 11"),
                  content: const Text(
                    "Grabadora Pro PZ",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.blueGrey),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "OK",
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0, // Material 3 plano y moderno
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
          ),
          child: SafeArea(
            // Garantiza que respete la barra de estado y "notches" automáticamente
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(
                16.0,
              ), // Margen interno unificado para todo el contenido
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER CON ESTILO DE TARJETA INTEGRADA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // Tonalidad sutil sin degradados agresivos
                      color: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        // Contenedor del Avatar/Logo pulido
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(
                                0.15,
                              ),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.mic_rounded,
                                    color: Colors.blueGrey,
                                    size: 26,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Textos perfectamente alineados y protegidos contra desbordes
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grabadora Pro PZ',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Menú Principal',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ETIQUETA DE SECCIÓN (Detalle muy Pro de Material 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'NAVEGACIÓN',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  // LISTA DE MENÚS (Flexible y limpia)
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildNavigationTile(
                          context,
                          icon: Icons.home_max_rounded, // Icono más moderno
                          title: 'Inicio',
                          theme: theme,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(
                          height: 8,
                        ), // Separación uniforme entre botones
                        _buildNavigationTile(
                          context,
                          icon:
                              Icons.settings_suggest_rounded, // Icono refinado
                          title: 'Configuración',
                          theme: theme,
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  currentEncoder: _selectedEncoder,
                                  currentBitRate: 128000,
                                  onConfigChanged: (encoder, bitrate) {
                                    setState(() {
                                      _selectedEncoder = encoder;
                                      if (encoder == AudioEncoder.pcm16bits) {
                                        _selectedExtension = 'wav';
                                      } else if (encoder == AudioEncoder.flac) {
                                        _selectedExtension = 'flac';
                                      } else {
                                        _selectedExtension = 'm4a';
                                      }
                                    });
                                  },
                                  themeProvider: themeProvider,
                                ),
                              ),
                            );
                            setState(() => _currentEntities = []);
                            await _initializeRootDirectory();
                          },
                        ),
                      ],
                    ),
                  ),

                  // SECCIÓN INFERIOR FIJA (Botón de salir aislado abajo)
                  Divider(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  _buildNavigationTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Cerrar App',
                    theme: theme,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      if (Platform.isAndroid) SystemNavigator.pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _buildBodyContent(theme),
      ),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required ThemeData theme,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colorScheme = theme.colorScheme;

    // El texto mantiene su lógica Material 3
    final finalColor = isDestructive
        ? colorScheme.error
        : colorScheme.onSurface;

    // Modificamos aquí: Si es destructivo usa el error del tema, si no, usa BlueGrey
    final iconColor = isDestructive
        ? colorScheme.error
        : Colors.blueGrey; // <--- Íconos con BlueGrey aplicado aquí

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        dense: true,
        horizontalTitleGap: 12,
        // Adaptamos el splash para que combine con el color del ícono correspondiente
        hoverColor: (isDestructive ? colorScheme.error : Colors.blueGrey)
            .withOpacity(0.08),
        splashColor: (isDestructive ? colorScheme.error : Colors.blueGrey)
            .withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: iconColor, size: 22),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: finalColor,
            fontWeight: isDestructive ? FontWeight.w500 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    String timeText = _formatRecordDuration(_recordDuration);
    List<Directory> folders = _currentEntities.whereType<Directory>().toList();
    List<File> files = _currentEntities
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.m4a') ||
              f.path.endsWith('.wav') ||
              f.path.endsWith('.flac'),
        )
        .toList();
    return Column(
      children: [
        const SizedBox(height: 10),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          color: theme.cardColor,
          child: ListTile(
            title: Text(
              "Formato",
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            trailing: DropdownButton<AudioEncoder>(
              value: _selectedEncoder,
              dropdownColor: theme.cardColor,
              items: const [
                DropdownMenuItem(value: AudioEncoder.aacLc, child: Text("AAC")),
                DropdownMenuItem(
                  value: AudioEncoder.pcm16bits,
                  child: Text("WAV"),
                ),
                DropdownMenuItem(value: AudioEncoder.flac, child: Text("FLAC")),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedEncoder = v;
                    _selectedExtension = v == AudioEncoder.pcm16bits
                        ? 'wav'
                        : (v == AudioEncoder.flac ? 'flac' : 'm4a');
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          timeText,
          style: TextStyle(
            fontSize: 60,
            fontWeight: FontWeight.w300,
            color: _isRecording
                ? Colors.redAccent
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isRecording ? "GRABANDO..." : "LISTO",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
        ),
        const SizedBox(height: 30),
        if (!_isRecording)
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.blueGrey, // 👈 botón principal en BlueGrey
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, size: 50, color: Colors.white),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 40,
                onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  color: _isPaused ? Colors.blueGrey : Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 20),
              IconButton(
                iconSize: 40,
                onPressed: _stopRecording,
                icon: const Icon(Icons.stop, color: Colors.redAccent),
              ),
            ],
          ),
        const SizedBox(height: 30),
        Container(
          color: theme.cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            children: [
              if (_navigationHistory.length > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 15),
                  color: Colors.blueGrey, // 👈 flecha en BlueGrey
                  onPressed: _navigateBack,
                  tooltip: "Atrás",
                ),
              Expanded(
                child: Text(
                  _currentDirectory?.path.split(Platform.pathSeparator).last ??
                      "Root",
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.blueGrey,
                ), // 👈 refresh en BlueGrey
                onPressed: () {
                  _loadDirectoryContents();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lista actualizada")),
                  );
                },
                tooltip: "Actualizar",
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.create_new_folder,
                  color: Colors.blueGrey,
                ), // 👈 new folder en BlueGrey
                onPressed: _createNewFolder,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildFileList(folders, files, theme)),
      ],
    );
  }

  Widget _buildFileList(
    List<Directory> folders,
    List<File> files,
    ThemeData theme,
  ) {
    if (folders.isEmpty && files.isEmpty) {
      return Center(
        child: Text(
          "Carpeta vacía",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      );
    }
    return ListView.builder(
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return ListTile(
            leading: const Icon(
              Icons.folder,
              color: Colors.blueGrey,
            ), // 👈 Folder en BlueGrey
            title: Text(
              folders[index].path.split(Platform.pathSeparator).last,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 20,
                    color: Colors.blueGrey,
                  ), // 👈 Edit en BlueGrey
                  onPressed: () => _renameItem(folders[index]),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _deleteItem(folders[index]),
                ),
              ],
            ),
            onTap: () => _navigateIntoDirectory(folders[index]),
          );
        } else {
          File file = files[index - folders.length];
          String fileName = file.path.split(Platform.pathSeparator).last;
          bool isPlayingItem =
              _currentlyPlayingPath != null &&
              _currentlyPlayingPath == file.path;
          bool isActuallyPlaying = isPlayingItem && _player.playing;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Card(
              color: theme.cardColor,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.audio_file,
                          color: Colors.blueGrey,
                        ), // 👈 Audio en BlueGrey
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            fileName,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isActuallyPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.blueGrey, // 👈 Play/Pause en BlueGrey
                          ),
                          onPressed: () => _togglePlay(file),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.share,
                            size: 20,
                            color: Colors.blueGrey,
                          ), // 👈 Share en BlueGrey
                          onPressed: () =>
                              Share.shareXFiles([XFile(file.path)]),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.drive_file_move_outline,
                            size: 20,
                            color: Colors.blueGrey,
                          ), // 👈 Move en BlueGrey
                          onPressed: () => _moveItem(file),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.blueGrey,
                          ), // 👈 Edit en BlueGrey
                          onPressed: () => _renameItem(file),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _deleteItem(file),
                        ),
                      ],
                    ),
                    if (isPlayingItem) ...[
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6.0,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12.0,
                              ),
                            ),
                            child: Slider(
                              value: _currentSliderValue,
                              min: 0.0,
                              max: 1.0,
                              activeColor: Colors
                                  .blueGrey, // 👈 Slider activo en BlueGrey
                              inactiveColor: theme.colorScheme.onSurface
                                  .withOpacity(0.2),
                              onChanged: (value) {
                                setState(() => _currentSliderValue = value);
                              },
                              onChangeStart: (_) => _onSliderChangeStart(),
                              onChangeEnd: (value) => _onSliderChangeEnd(value),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(
                                    _currentAudioDuration != null
                                        ? Duration(
                                            milliseconds:
                                                (_currentAudioDuration!
                                                            .inMilliseconds *
                                                        _currentSliderValue)
                                                    .toInt(),
                                          )
                                        : Duration.zero,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_currentAudioDuration),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
