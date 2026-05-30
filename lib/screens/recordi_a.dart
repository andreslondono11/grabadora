import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grabadora/screens/configuracion.dart'; // Verifica ruta
import 'package:grabadora/screens/tema.dart'; // Verifica ruta
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:just_audio/just_audio.dart';

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
  // INICIALIZACIÓN Y NAVEGACIÓN (CORREGIDO: AUTO-CREACIÓN SD)
  // --------------------------------------------------------------------------

  Future<void> _initializeRootDirectory() async {
    Directory rootDir = Directory('');

    // 1. Leemos preferencias guardadas
    final prefs = await SharedPreferences.getInstance();
    final String? customPath = prefs.getString('external_custom_path');
    final String? locationType = prefs.getString('storage_location');

    bool useCustom = false;

    // 2. Si había una ruta SD guardada, intentamos usarla
    if (locationType == 'externalCustom' &&
        customPath != null &&
        customPath.isNotEmpty) {
      Directory potentialDir = Directory(customPath);

      // --- NUEVA LÓGICA: INTENTAR ABRIR Y SI FALLA, CREAR ---
      try {
        // Intentamos listar para ver si existe
        potentialDir.listSync();
        rootDir = potentialDir;
        useCustom = true;
        debugPrint("SD detectada y carpeta encontrada.");
      } catch (e) {
        debugPrint("La carpeta en la SD no existe ($e). Intentando crearla...");

        try {
          // Intentamos crear la carpeta recursivamente
          await potentialDir.create(recursive: true);
          // Si creó con éxito, la usamos
          rootDir = potentialDir;
          useCustom = true;
          debugPrint("Carpeta en SD creada exitosamente.");

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Carpeta creada en Memoria Externa")),
            );
          }
        } catch (createError) {
          // Si falla la creación (error de permiso o SD protegida), caemos a interna
          debugPrint(
            "No se pudo crear carpeta en SD ($createError). Usando interna.",
          );
          useCustom = false;
        }
      }
    }

    // 3. Si no usamos SD (o falló lo anterior), usamos interna
    if (!useCustom) {
      rootDir = await _getInternalDirectory();
    }

    // 4. Crear carpeta interna si no existe (seguridad)
    try {
      if (!await rootDir.exists()) {
        await rootDir.create(recursive: true);
      }
    } catch (e) {
      debugPrint("Error creando carpeta interna: $e");
    }

    // 5. Establecer estado
    if (mounted) {
      setState(() {
        _currentDirectory = rootDir;
        _navigationHistory.clear();
        _navigationHistory.add(rootDir);
      });

      _loadDirectoryContents();

      // Importante: Sincronizamos con Settings al iniciar
      await _syncLocationWithSettings();

      if (useCustom) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guardando en Memoria Externa"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // --------------------------------------------------------------------------
  // SINCRONIZACIÓN (ACTUALIZA LA VISTA AL VOLVER DE CONFIG)
  // --------------------------------------------------------------------------

  // Método para guardar dónde estamos
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

      if (mounted) {
        setState(() => _currentEntities = entities);
      }
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
      builder: (context) => AlertDialog(
        title: const Text("Nueva Carpeta"),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
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
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Nombre inválido")),
                  );
                return;
              }

              String currentPath = _currentDirectory!.path;
              if (!currentPath.endsWith(Platform.pathSeparator))
                currentPath += Platform.pathSeparator;

              final newPath = "$currentPath$folderName";
              final newDir = Directory(newPath);

              try {
                if (await newDir.exists()) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("La carpeta '$folderName' ya existe"),
                      ),
                    );
                  return;
                }
                await newDir.create(recursive: true);
                _loadDirectoryContents();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Carpeta creada")));
                }
              } catch (e) {
                debugPrint("Error creando carpeta: $e");
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error de permiso")),
                  );
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
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
      builder: (context) => AlertDialog(
        title: const Text("Renombrar"),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              String inputName = controller.text.trim();
              inputName = inputName.replaceAll(RegExp(r'[\\/:"*?<>|]'), '');

              String finalName = inputName.isEmpty
                  ? "Grabación ${DateTime.now().millisecondsSinceEpoch}"
                  : inputName;

              String parentPath = entity.parent.path;
              if (!parentPath.endsWith(Platform.pathSeparator))
                parentPath += Platform.pathSeparator;

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
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Error al renombrar")),
                  );
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
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
            child: const Text("Cancelar"),
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
    Directory baseDir = _currentDirectory!;
    List<Directory> availableFolders = [];

    try {
      if (await baseDir.exists()) {
        availableFolders.add(baseDir);
        List<FileSystemEntity> entities = baseDir.listSync();
        for (var e in entities) {
          if (e is Directory) availableFolders.add(e);
        }
      }
    } catch (e) {
      debugPrint("Error escaneando carpetas: $e");
    }

    if (!mounted) return;
    availableFolders.removeWhere((folder) => folder.path == entity.parent.path);

    if (availableFolders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay subcarpetas disponibles")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Mover a..."),
        children: availableFolders.map((folder) {
          String displayName = folder.path == baseDir.path
              ? "📂 Carpeta Actual"
              : "📁 ${folder.path.split(Platform.pathSeparator).last}";
          bool isCurrentLocation = folder.path == entity.parent.path;
          return SimpleDialogOption(
            onPressed: isCurrentLocation
                ? null
                : () async {
                    Navigator.pop(context);
                    await _performMove(entity, folder);
                  },
            child: Text(
              displayName,
              style: TextStyle(
                color: isCurrentLocation
                    ? Colors.grey
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface, // <--- SE ADAPTA AL TEMA
                fontWeight: isCurrentLocation
                    ? FontWeight.normal
                    : FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _performMove(
    FileSystemEntity entity,
    Directory targetDir,
  ) async {
    try {
      if (entity is File && _currentlyPlayingPath == entity.path) {
        await _player.stop();
        setState(() => _currentlyPlayingPath = null);
      }
      await Future.delayed(const Duration(milliseconds: 100));
      String fileName = entity.path.split(Platform.pathSeparator).last;
      String newPath = "${targetDir.path}${Platform.pathSeparator}$fileName";
      await entity.rename(newPath);
      _loadDirectoryContents();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Movido a ${targetDir.path.split(Platform.pathSeparator).last}",
            ),
          ),
        );
    } catch (e) {
      debugPrint("Error moviendo: $e");
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
          SnackBar(content: Text("Error al grabar. Revisa permisos de la SD.")),
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

    return Scaffold(
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
            icon: Icon(Icons.info_outline, color: theme.colorScheme.onSurface),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: theme.cardColor,
                title: const Text("Versión 8"),
                content: const Text(
                  "Grabadora Pro PZ",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.blueGrey),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grabadora Pro PZ',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Menú Principal',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.home, color: theme.colorScheme.onSurface),
              title: Text(
                'Inicio',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: Icon(Icons.settings, color: theme.colorScheme.onSurface),
              title: Text(
                'Configuración',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () async {
                Navigator.pop(context); // Cerramos el menú lateral primero

                // ESPERAMOS a que el usuario termine en Configuración y vuelva
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      currentEncoder: _selectedEncoder,
                      currentBitRate: 128000,
                      onConfigChanged: (encoder, bitrate) {
                        setState(() {
                          _selectedEncoder = encoder;
                          if (encoder == AudioEncoder.pcm16bits)
                            _selectedExtension = 'wav';
                          else if (encoder == AudioEncoder.flac)
                            _selectedExtension = 'flac';
                          else
                            _selectedExtension = 'm4a';
                        });
                      },
                      themeProvider: themeProvider,
                    ),
                  ),
                );

                // --- CLAVE: AL VOLVER, REINICIAMOS EL DIRECTORIO RAÍZ ---
                // Esto fuerza a leer de nuevo 'storage_location' desde SharedPreferences
                setState(() {
                  _currentEntities = []; // Limpiamos lista visualmente
                });

                // Volvemos a ejecutar la lógica de inicio:
                // Si en Configuración pusiste "SD", esto cargará la SD.
                // Si pusiste "Interna", esto cargará la Interna.
                await _initializeRootDirectory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.redAccent),
              title: Text(
                'Cerrar App',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                if (Platform.isAndroid) SystemNavigator.pop();
              },
            ),
          ],
        ),
      ),
      body: _buildBodyContent(theme),
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
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.4),
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
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
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

        // --- BARRA DE HERRAMIENTAS CORREGIDA ---
        Container(
          color: theme.cardColor, // Fondo blanco o gris oscuro
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          child: Row(
            children: [
              // 1. Flecha Atrás
              if (_navigationHistory.length > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 15),
                  // Color dinámico: Blanco en oscuro, Púrpura Oscuro en claro (visibilidad garantizada)
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.deepPurple,
                  onPressed: _navigateBack,
                  tooltip: "Atrás",
                ),

              // 2. Nombre de Carpeta
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

              // 3. Botones
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.refresh,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
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
                icon: Icon(
                  Icons.create_new_folder,
                  color: theme.colorScheme.primary,
                ),
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
    if (folders.isEmpty && files.isEmpty)
      return Center(
        child: Text(
          "Carpeta vacía",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      );

    return ListView.builder(
      itemCount: folders.length + files.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return ListTile(
            leading: Icon(Icons.folder, color: theme.colorScheme.primary),
            title: Text(
              folders[index].path.split(Platform.pathSeparator).last,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 20),
                  onPressed: () => _renameItem(folders[index]),
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 20, color: Colors.redAccent),
                  onPressed: () => _deleteItem(folders[index]),
                ),
              ],
            ),
            onTap: () => _navigateIntoDirectory(folders[index]),
          );
        } else {
          File file = files[index - folders.length];
          String fileName = file.path.split(Platform.pathSeparator).last;
          bool isPlayingItem = _currentlyPlayingPath == file.path;
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
                        Icon(
                          Icons.audio_file,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
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
                          ),
                          onPressed: () => _togglePlay(file),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.share, size: 20),
                          onPressed: () =>
                              Share.shareXFiles([XFile(file.path)]),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.drive_file_move_outline,
                            size: 20,
                          ),
                          onPressed: () => _moveItem(file),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit, size: 20),
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
                              activeColor: theme.colorScheme.primary,
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
