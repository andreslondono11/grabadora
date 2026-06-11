// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// //UI
// import 'package:grabadora/screens/UI/storage.dart';

// //SCREEN
// import 'package:grabadora/screens/configuracion.dart';
// import 'package:grabadora/screens/tema.dart';
// // import 'package:path_provider/path_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:record/record.dart';

// // PAQUETES EXTERNOS
// import 'package:share_plus/share_plus.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:wakelock_plus/wakelock_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// // IMPORTANTE PARA LA NOTIFICACIÓN
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// class RecorderScreen extends StatefulWidget {
//   const RecorderScreen({super.key});

//   @override
//   State<RecorderScreen> createState() => _RecorderScreenState();
// }

// class _RecorderScreenState extends State<RecorderScreen>
//     with WidgetsBindingObserver {
//   // --- Grabadora ---
//   final AudioRecorder _audioRecorder = AudioRecorder();
//   bool _isRecording = false;
//   bool _isPaused = false;

//   // --- Reproductor ---
//   final AudioPlayer _player = AudioPlayer();
//   String? _currentlyPlayingPath;
//   bool _isSliderDragging = false;
//   double _currentSliderValue = 0.0;
//   Duration? _currentAudioDuration;

//   // --- Configuración ---
//   AudioEncoder _selectedEncoder = AudioEncoder.aacLc;
//   String _selectedExtension = 'm4a';

//   // --- Timer ---
//   Timer? _timer;
//   int _recordDuration = 0;

//   // --- Notificaciones (NUEVO) ---
//   final FlutterLocalNotificationsPlugin _notificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//   final _RecordingNotification _recordingNotification =
//       _RecordingNotification();

//   // --- FileManager ---
//   final FileManager _fileManager = FileManager();

//   @override
//   void initState() {
//     super.initState();
//     // IMPORTANTE: Escuchar cambios de ciclo de vida (AppMinimize/Resume)
//     WidgetsBinding.instance.addObserver(this);
//     _initNotifications(); // Inicializar notificaciones
//     _initPlayer();
//     _fileManager.initializeRootDirectory(() {
//       if (mounted) setState(() {});
//     });
//     _checkDisclaimer();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this); // Dejar de escuchar
//     _stopNotificationService();
//     _audioRecorder.dispose();
//     _timer?.cancel();
//     _player.dispose();
//     WakelockPlus.disable();
//     super.dispose();
//   }

//   // -------------------------------------------------------------------------
//   // DETECTAR CUANDO LA APP SE VA O VUELVE (Cambios visuales de notificación)
//   // -------------------------------------------------------------------------
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     // Si la app pasa a segundo plano o inactiva, actualizamos la notificación
//     if (state == AppLifecycleState.paused ||
//         state == AppLifecycleState.inactive) {
//       if (_isRecording) {
//         _showRecordingNotification();
//       }
//     } else if (state == AppLifecycleState.resumed) {
//       // Si volvemos a la app, la notificación ya no es necesaria visualmente,
//       // pero la mantenemos viva para los controles si el usuario baja la barra.
//       // Si quieres eliminarla al volver, descomenta la siguiente línea:
//       // _stopNotificationService();
//     }
//   }

//   // --------------------------------------------------------------------------
//   // GESTIÓN DE NOTIFICACIONES
//   // --------------------------------------------------------------------------
//   Future<void> _initNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');

//     const IOSInitializationSettings initializationSettingsIOS =
//         IOSInitializationSettings();

//     const InitializationSettings initializationSettings =
//         InitializationSettings(
//           android: initializationSettingsAndroid,
//           iOS: initializationSettingsIOS,
//         );

//     await _notificationsPlugin.initialize(
//       settings: initializationSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) async {
//         final payload = response.payload;

//         if (payload == 'pause') {
//           _pauseRecording();
//         }
//         if (payload == 'stop') {
//           _stopRecording();
//         }
//       },
//     );
//   }

//   Future<void> _showRecordingNotification() async {
//     // NUEVO: Solo mostrar si la app está en segundo plano
//     final state = WidgetsBinding.instance.lifecycleState;
//     if (state != AppLifecycleState.resumed) {
//       await _recordingNotification.show(
//         plugin: _notificationsPlugin,
//         duration: _recordDuration,
//         isPaused: _isPaused,
//       );
//     }
//   }

//   Future<void> _stopNotificationService() async {
//     await _notificationsPlugin.cancel(id: 100);
//   }

//   // --------------------------------------------------------------------------
//   // REPRODUCTOR
//   // --------------------------------------------------------------------------
//   void _initPlayer() {
//     _player.positionStream.listen((position) {
//       if (mounted && !_isSliderDragging && _currentlyPlayingPath != null) {
//         final duration = _player.duration;
//         if (duration != null && duration.inMilliseconds > 0) {
//           setState(
//             () => _currentSliderValue =
//                 position.inMilliseconds / duration.inMilliseconds,
//           );
//         }
//       }
//     });
//     _player.playerStateStream.listen((state) {
//       if (state.processingState == ProcessingState.completed) {
//         setState(() {
//           _currentSliderValue = 0.0;
//           _currentlyPlayingPath = null;
//         });
//         _player.stop();
//         _player.seek(Duration.zero);
//       }
//     });
//   }

//   void _onSliderChangeStart() {
//     setState(() => _isSliderDragging = true);
//   }

//   void _onSliderChangeEnd(double value) async {
//     setState(() => _isSliderDragging = false);
//     final duration = _player.duration;
//     if (duration != null) {
//       final position = duration * value;
//       await _player.seek(position);
//     }
//   }

//   Future<void> _togglePlay(File entity) async {
//     String path = entity.path;
//     if (_currentlyPlayingPath == path) {
//       if (_player.playing) {
//         await _player.pause();
//       } else {
//         await _player.play();
//       }
//       return;
//     }
//     try {
//       await _player.setFilePath(path);
//       final duration = _player.duration;
//       setState(() {
//         _currentlyPlayingPath = path;
//         _currentSliderValue = 0.0;
//         _currentAudioDuration = duration;
//       });
//       await _player.play();
//     } catch (e) {
//       debugPrint("Error reproduciendo: $e");
//     }
//   }

//   String _formatDuration(Duration? duration) {
//     if (duration == null) return "00:00";
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     String minutes = twoDigits(duration.inMinutes.remainder(60));
//     String seconds = twoDigits(duration.inSeconds.remainder(60));
//     return "$minutes:$seconds";
//   }

//   // --------------------------------------------------------------------------
//   // GRABACIÓN
//   // --------------------------------------------------------------------------
//   Future<void> _startRecording() async {
//     if (_player.playing) {
//       await _player.stop();
//       setState(() {
//         _currentlyPlayingPath = null;
//         _currentSliderValue = 0.0;
//       });
//     }
//     try {
//       final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
//       String dirPath = _fileManager.currentDirectory!.path;
//       if (!dirPath.endsWith(Platform.pathSeparator))
//         dirPath += Platform.pathSeparator;
//       final String filePath = '${dirPath}rec_$timestamp.$_selectedExtension';

//       // await _audioRecorder.start(
//       //   RecordConfig(encoder: _selectedEncoder, bitRate: 128000),
//       //   path: filePath,
//       // );

//       // Configuración de grabación
//       var config = RecordConfig(encoder: _selectedEncoder, bitRate: 128000);

//       // CORRECCIÓN: Si es WAV (pcm16bits), forzamos sampleRate a 44100
//       // porque just_audio tiene problemas reproduciendo WAVs de otros rates.
//       if (_selectedEncoder == AudioEncoder.pcm16bits) {
//         config = RecordConfig(
//           encoder: AudioEncoder.pcm16bits,
//           sampleRate: 44100, // Clave para la compatibilidad
//           numChannels: 1, // Mono es suficiente para voz
//           bitRate: 128000,
//         );
//       }

//       await _audioRecorder.start(config, path: filePath);

//       setState(() {
//         _isRecording = true;
//         _isPaused = false;
//         _recordDuration = 0;
//       });

//       _startTimer();
//       // Nota: No llamamos a _showRecordingNotification aquí directamente.
//       // didChangeAppLifecycleState lo hará si sales de la app.
//       await WakelockPlus.enable();
//     } catch (e) {
//       debugPrint("Error iniciando grabación: $e");
//       if (mounted)
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Error al grabar. Revisa permisos.")),
//         );
//     }
//   }

//   Future<void> _pauseRecording() async {
//     await _audioRecorder.pause();
//     _timer?.cancel();
//     setState(() => _isPaused = true);
//     _showRecordingNotification(); // Actualizar si estás en segundo plano
//   }

//   Future<void> _resumeRecording() async {
//     await _audioRecorder.resume();
//     _startTimer();
//     setState(() => _isPaused = false);
//     _showRecordingNotification(); // Actualizar si estás en segundo plano
//   }

//   Future<void> _stopRecording() async {
//     await _audioRecorder.stop();
//     _timer?.cancel();
//     setState(() {
//       _isRecording = false;
//       _isPaused = false;
//       _recordDuration = 0;
//     });
//     _stopNotificationService();
//     await WakelockPlus.disable();
//     await _fileManager.loadDirectoryContents();
//     setState(() {});
//   }

//   void _startTimer() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
//       setState(() => _recordDuration++);
//       _showRecordingNotification(); // Intenta actualizar (solo se ve si está en background)
//     });
//   }

//   String _formatRecordDuration(int seconds) {
//     final int minutes = seconds ~/ 60;
//     final int remainingSeconds = seconds % 60;
//     return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
//   }

//   // --------------------------------------------------------------------------
//   // DISCLAIMER
//   // --------------------------------------------------------------------------
//   Future<void> _checkDisclaimer() async {
//     final prefs = await SharedPreferences.getInstance();
//     if (prefs.getBool('has_seen_disclaimer') ?? false) return;
//     await Future.delayed(const Duration(milliseconds: 500));
//     if (!mounted) return;

//     final theme = Theme.of(context);
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         backgroundColor: theme.cardColor,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
//             SizedBox(width: 10),
//             Text("Aviso Legal"),
//           ],
//         ),
//         content: const Text(
//           "Esta aplicación es una herramienta de grabación de audio personal.\n\nEl usuario es el único responsable del contenido que grabe, almacene y comparta. Los desarrolladores no se hacen responsables del uso indebido de esta aplicación.\n\nAl continuar, aceptas estos términos.",
//         ),
//         actions: [
//           TextButton(
//             child: const Text(
//               "Aceptar",
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             onPressed: () async {
//               await prefs.setBool('has_seen_disclaimer', true);
//               if (mounted) Navigator.of(context).pop();
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // --------------------------------------------------------------------------
//   // UI BUILD
//   // --------------------------------------------------------------------------
//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = Provider.of<ThemeProvider>(context);
//     final theme = themeProvider.currentTheme;

//     return PopScope(
//       canPop: false,
//       onPopInvoked: (bool didPop) async {
//         if (didPop) return;
//         if (_fileManager.navigationHistory.length > 1) {
//           _fileManager.navigateBack(() => setState(() {}));
//         } else {
//           if (context.mounted) SystemNavigator.pop();
//         }
//       },
//       child: Scaffold(
//         backgroundColor: theme.scaffoldBackgroundColor,
//         appBar: AppBar(
//           title: const Text(
//             'Grabadora Pro PZ',
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           centerTitle: true,
//           elevation: 0,
//           iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
//           actions: [
//             IconButton(
//               icon: Icon(
//                 Icons.info_outline,
//                 color: theme.colorScheme.onSurface,
//               ),
//               onPressed: () => showDialog(
//                 context: context,
//                 builder: (context) => AlertDialog(
//                   backgroundColor: theme.cardColor,
//                   title: const Text("Versión 12"),
//                   content: const Text(
//                     "Grabadora Pro PZ",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(fontSize: 18, color: Colors.blueGrey),
//                   ),
//                   actions: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: const Text(
//                         "OK",
//                         style: TextStyle(color: Colors.blueGrey),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//         drawer: _buildDrawer(theme, themeProvider),
//         body: _buildBodyContent(theme),
//       ),
//     );
//   }

//   Widget _buildDrawer(ThemeData theme, ThemeProvider themeProvider) {
//     return Drawer(
//       backgroundColor: theme.colorScheme.surface,
//       elevation: 0,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: theme.colorScheme.surfaceContainerHighest.withOpacity(
//                     0.5,
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 52,
//                       height: 52,
//                       decoration: BoxDecoration(
//                         color: theme.colorScheme.primary.withOpacity(0.1),
//                         shape: BoxShape.circle,
//                         border: Border.all(
//                           color: theme.colorScheme.primary.withOpacity(0.15),
//                           width: 1.5,
//                         ),
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(50),
//                         child: Image.asset(
//                           'assets/logo.png',
//                           fit: BoxFit.cover,
//                           errorBuilder: (context, error, stackTrace) =>
//                               const Icon(
//                                 Icons.mic_rounded,
//                                 color: Colors.blueGrey,
//                                 size: 26,
//                               ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 14),
//                     Expanded(
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Grabadora Pro PZ',
//                             style: theme.textTheme.titleMedium?.copyWith(
//                               color: theme.colorScheme.onSurface,
//                               fontWeight: FontWeight.bold,
//                               letterSpacing: 0.3,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           const SizedBox(height: 2),
//                           Text(
//                             'Menú Principal',
//                             style: theme.textTheme.bodySmall?.copyWith(
//                               color: theme.colorScheme.onSurfaceVariant
//                                   .withOpacity(0.7),
//                               fontWeight: FontWeight.w500,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Padding(
//                 padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
//                 child: Text(
//                   'NAVEGACIÓN',
//                   style: theme.textTheme.labelSmall?.copyWith(
//                     color: Colors.blueGrey,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 1.5,
//                   ),
//                 ),
//               ),
//               Expanded(
//                 child: ListView(
//                   padding: EdgeInsets.zero,
//                   children: [
//                     const SizedBox(height: 8),
//                     _buildNavigationTile(
//                       context,
//                       icon: Icons.settings_suggest_rounded,
//                       title: 'Configuración',
//                       theme: theme,
//                       onTap: () async {
//                         Navigator.pop(context);
//                         await Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => SettingsScreen(
//                               currentEncoder: _selectedEncoder,
//                               currentBitRate: 128000,
//                               onConfigChanged: (encoder, bitrate) {
//                                 setState(() {
//                                   _selectedEncoder = encoder;
//                                   if (encoder == AudioEncoder.pcm16bits) {
//                                     _selectedExtension = 'wav';
//                                   } else if (encoder == AudioEncoder.flac) {
//                                     _selectedExtension = 'flac';
//                                   } else {
//                                     _selectedExtension = 'm4a';
//                                   }
//                                 });
//                               },
//                               themeProvider: themeProvider,
//                             ),
//                           ),
//                         );
//                         await _fileManager.initializeRootDirectory(
//                           () => setState(() {}),
//                         );
//                       },
//                     ),
//                   ],
//                 ),
//               ),
//               Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
//               const SizedBox(height: 8),
//               _buildNavigationTile(
//                 context,
//                 icon: Icons.logout_rounded,
//                 title: 'Cerrar App',
//                 theme: theme,
//                 isDestructive: true,
//                 onTap: () {
//                   Navigator.pop(context);
//                   if (Platform.isAndroid) SystemNavigator.pop();
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildNavigationTile(
//     BuildContext context, {
//     required IconData icon,
//     required String title,
//     required ThemeData theme,
//     required VoidCallback onTap,
//     bool isDestructive = false,
//   }) {
//     final colorScheme = theme.colorScheme;
//     final finalColor = isDestructive
//         ? colorScheme.error
//         : colorScheme.onSurface;
//     final iconColor = isDestructive ? colorScheme.error : Colors.blueGrey;

//     return Material(
//       color: Colors.transparent,
//       child: ListTile(
//         onTap: onTap,
//         dense: true,
//         horizontalTitleGap: 12,
//         hoverColor: (isDestructive ? colorScheme.error : Colors.blueGrey)
//             .withOpacity(0.08),
//         splashColor: (isDestructive ? colorScheme.error : Colors.blueGrey)
//             .withOpacity(0.12),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
//         leading: Icon(icon, color: iconColor, size: 22),
//         title: Text(
//           title,
//           style: theme.textTheme.bodyLarge?.copyWith(
//             color: finalColor,
//             fontWeight: isDestructive ? FontWeight.w500 : FontWeight.w600,
//             fontSize: 15,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBodyContent(ThemeData theme) {
//     String timeText = _formatRecordDuration(_recordDuration);
//     List<Directory> folders = _fileManager.currentEntities
//         .whereType<Directory>()
//         .toList();
//     List<File> files = _fileManager.currentEntities
//         .whereType<File>()
//         .where(
//           (f) =>
//               f.path.endsWith('.m4a') ||
//               f.path.endsWith('.wav') ||
//               f.path.endsWith('.flac'),
//         )
//         .toList();

//     return Column(
//       children: [
//         const SizedBox(height: 10),
//         Card(
//           margin: const EdgeInsets.symmetric(horizontal: 20),
//           color: theme.cardColor,
//           child: ListTile(
//             title: Text(
//               "Formato",
//               style: TextStyle(color: theme.colorScheme.onSurface),
//             ),
//             trailing: DropdownButton<AudioEncoder>(
//               value: _selectedEncoder,
//               dropdownColor: theme.cardColor,
//               items: const [
//                 DropdownMenuItem(value: AudioEncoder.aacLc, child: Text("AAC")),
//                 DropdownMenuItem(
//                   value: AudioEncoder.pcm16bits,
//                   child: Text("WAV"),
//                 ),
//                 DropdownMenuItem(value: AudioEncoder.flac, child: Text("FLAC")),
//               ],
//               onChanged: (v) {
//                 if (v != null) {
//                   setState(() {
//                     _selectedEncoder = v;
//                     _selectedExtension = v == AudioEncoder.pcm16bits
//                         ? 'wav'
//                         : (v == AudioEncoder.flac ? 'flac' : 'm4a');
//                   });
//                 }
//               },
//             ),
//           ),
//         ),
//         const SizedBox(height: 20),
//         Text(
//           timeText,
//           style: TextStyle(
//             fontSize: 60,
//             fontWeight: FontWeight.w300,
//             color: _isRecording
//                 ? Colors.redAccent
//                 : theme.colorScheme.onSurface,
//           ),
//         ),
//         const SizedBox(height: 10),
//         Text(
//           _isRecording ? "GRABANDO..." : "LISTO",
//           style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
//         ),
//         const SizedBox(height: 30),
//         if (!_isRecording)
//           GestureDetector(
//             onTap: _startRecording,
//             child: Container(
//               padding: const EdgeInsets.all(30),
//               decoration: BoxDecoration(
//                 color: Colors.blueGrey,
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.blueGrey.withOpacity(0.4),
//                     blurRadius: 20,
//                     spreadRadius: 5,
//                   ),
//                 ],
//               ),
//               child: const Icon(Icons.mic, size: 50, color: Colors.white),
//             ),
//           )
//         else
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               IconButton(
//                 iconSize: 40,
//                 onPressed: _isPaused ? _resumeRecording : _pauseRecording,
//                 icon: Icon(
//                   _isPaused ? Icons.play_arrow : Icons.pause,
//                   color: _isPaused ? Colors.blueGrey : Colors.orangeAccent,
//                 ),
//               ),
//               const SizedBox(width: 20),
//               IconButton(
//                 iconSize: 40,
//                 onPressed: _stopRecording,
//                 icon: const Icon(Icons.stop, color: Colors.redAccent),
//               ),
//             ],
//           ),
//         const SizedBox(height: 30),
//         Container(
//           color: theme.cardColor,
//           padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
//           child: Row(
//             children: [
//               if (_fileManager.navigationHistory.length > 1)
//                 IconButton(
//                   icon: const Icon(Icons.arrow_back_ios, size: 15),
//                   color: Colors.blueGrey,
//                   onPressed: () =>
//                       _fileManager.navigateBack(() => setState(() {})),
//                 ),
//               Expanded(
//                 child: Text(
//                   _fileManager.currentDirectory?.path
//                           .split(Platform.pathSeparator)
//                           .last ??
//                       "Cargando...",
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: theme.colorScheme.onSurface,
//                   ),
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               IconButton(
//                 icon: const Icon(
//                   Icons.create_new_folder,
//                   color: Colors.blueGrey,
//                 ),
//                 onPressed: () => _showCreateFolderDialog(theme),
//               ),
//             ],
//           ),
//         ),
//         const Divider(height: 1),
//         Expanded(
//           child: (folders.isEmpty && files.isEmpty)
//               ? Center(
//                   child: Text(
//                     "No hay grabaciones",
//                     style: TextStyle(
//                       color: theme.colorScheme.onSurface.withOpacity(0.5),
//                     ),
//                   ),
//                 )
//               : ListView.builder(
//                   padding: const EdgeInsets.symmetric(vertical: 10),
//                   itemCount: folders.length + files.length,
//                   itemBuilder: (context, index) {
//                     if (index < folders.length) {
//                       Directory folder = folders[index];
//                       return _buildFileTile(theme, folder, null);
//                     } else {
//                       File file = files[index - folders.length];
//                       bool isPlaying = _currentlyPlayingPath == file.path;
//                       return _buildFileTile(theme, file, isPlaying);
//                     }
//                   },
//                 ),
//         ),
//       ],
//     );
//   }

//   Widget _buildFileTile(
//     ThemeData theme,
//     FileSystemEntity entity,
//     bool? isPlaying,
//   ) {
//     bool isFolder = entity is Directory;
//     String name = entity.path.split(Platform.pathSeparator).last;

//     bool isThisPlaying = (isPlaying ?? false) && _player.playing;

//     Duration? duration = _currentAudioDuration;
//     String positionText = "00:00";
//     String totalText = "00:00";

//     if (!isFolder && duration != null) {
//       final currentPosition = duration * _currentSliderValue;
//       positionText = _formatDuration(currentPosition);
//       totalText = _formatDuration(duration);
//     }

//     return Card(
//       margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//       color: theme.cardColor,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: ListTile(
//         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         leading: Icon(
//           isFolder
//               ? Icons.folder
//               : (isThisPlaying ? Icons.graphic_eq : Icons.mic_none),
//           color: isFolder
//               ? Colors.blueGrey
//               : (isThisPlaying ? Colors.redAccent : Colors.grey),
//           size: 28,
//         ),
//         title: Text(
//           name,
//           style: TextStyle(
//             color: theme.colorScheme.onSurface,
//             fontWeight: FontWeight.w500,
//             fontSize: 15,
//           ),
//         ),
//         subtitle: (isFolder || !isThisPlaying)
//             ? null
//             : Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 8),
//                   SliderTheme(
//                     data: SliderTheme.of(context).copyWith(
//                       trackHeight: 2,
//                       thumbShape: const RoundSliderThumbShape(
//                         enabledThumbRadius: 6,
//                       ),
//                       overlayShape: const RoundSliderOverlayShape(
//                         overlayRadius: 10,
//                       ),
//                       activeTrackColor: Colors.blueGrey,
//                       inactiveTrackColor: Colors.grey.withOpacity(0.3),
//                       thumbColor: Colors.blueGrey,
//                     ),
//                     child: Slider(
//                       value: _currentSliderValue,
//                       min: 0.0,
//                       max: 1.0,
//                       onChanged: (value) {
//                         setState(() => _currentSliderValue = value);
//                       },
//                       onChangeStart: (_) => _onSliderChangeStart(),
//                       onChangeEnd: (value) => _onSliderChangeEnd(value),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 4.0),
//                     child: Text(
//                       "$positionText / $totalText",
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: theme.colorScheme.onSurface.withOpacity(0.6),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (!isFolder)
//               IconButton(
//                 icon: Icon(isThisPlaying ? Icons.pause : Icons.play_arrow),
//                 color: Colors.blueGrey,
//                 iconSize: 28,
//                 onPressed: () => _togglePlay(entity as File),
//               ),
//             PopupMenuButton<String>(
//               icon: const Icon(Icons.more_vert, color: Colors.grey),
//               onSelected: (value) async {
//                 if (value == 'rename') await _showRenameDialog(theme, entity);
//                 if (value == 'delete') await _showDeleteDialog(entity);
//                 if (value == 'move')
//                   await _fileManager.moveItem(
//                     entity,
//                     context,
//                     () => setState(() {}),
//                   );
//                 if (value == 'share')
//                   await Share.shareXFiles([
//                     XFile(entity.path),
//                   ], text: 'Audio grabado');
//               },
//               itemBuilder: (context) {
//                 List<PopupMenuEntry<String>> items = [];
//                 items.add(
//                   const PopupMenuItem(
//                     value: 'rename',
//                     child: Text('Renombrar'),
//                   ),
//                 );
//                 if (!isFolder) {
//                   items.add(
//                     const PopupMenuItem(value: 'move', child: Text('Mover')),
//                   );
//                   items.add(
//                     const PopupMenuItem(
//                       value: 'share',
//                       child: Text('Compartir'),
//                     ),
//                   );
//                 }
//                 items.add(
//                   const PopupMenuItem(
//                     value: 'delete',
//                     child: Text(
//                       'Eliminar',
//                       style: TextStyle(color: Colors.red),
//                     ),
//                   ),
//                 );
//                 return items;
//               },
//             ),
//           ],
//         ),
//         onTap: isFolder
//             ? () => _fileManager.navigateIntoDirectory(
//                 entity as Directory,
//                 () => setState(() {}),
//               )
//             : () => _togglePlay(entity as File),
//       ),
//     );
//   }

//   // --------------------------------------------------------------------------
//   // DIALOGS
//   // --------------------------------------------------------------------------
//   Future<void> _showCreateFolderDialog(ThemeData theme) async {
//     final controller = TextEditingController();
//     if (!mounted) return;
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Nueva Carpeta"),
//         content: TextField(
//           controller: controller,
//           decoration: const InputDecoration(hintText: "Nombre de la carpeta"),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text(
//               "Cancelar",
//               style: TextStyle(color: Colors.blueGrey),
//             ),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blueGrey,
//               foregroundColor: Colors.white,
//             ),
//             onPressed: () {
//               if (controller.text.isNotEmpty) {
//                 _fileManager.createFolder(
//                   controller.text,
//                   context,
//                   () => setState(() {}),
//                 );
//                 Navigator.pop(context);
//               }
//             },
//             child: const Text("Crear"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showRenameDialog(
//     ThemeData theme,
//     FileSystemEntity entity,
//   ) async {
//     String initialName = entity.path.split(Platform.pathSeparator).last;
//     if (entity is File && initialName.contains(".")) {
//       initialName = initialName.substring(0, initialName.lastIndexOf("."));
//     }
//     final controller = TextEditingController(text: initialName);
//     if (!mounted) return;
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Renombrar"),
//         content: TextField(controller: controller),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Cancelar"),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
//             onPressed: () {
//               if (controller.text.isNotEmpty) {
//                 if (entity is File && _currentlyPlayingPath == entity.path) {
//                   _player.stop();
//                   setState(() => _currentlyPlayingPath = null);
//                 }
//                 _fileManager.renameItem(
//                   entity,
//                   controller.text,
//                   () => setState(() {}),
//                 );
//                 Navigator.pop(context);
//               }
//             },
//             child: const Text("Guardar"),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _showDeleteDialog(FileSystemEntity entity) async {
//     bool? confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Eliminar"),
//         content: Text(
//           "¿Estás seguro de eliminar ${entity.path.split(Platform.pathSeparator).last}?",
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text("Cancelar"),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
//           ),
//         ],
//       ),
//     );
//     if (confirm == true) {
//       if (entity is File && _currentlyPlayingPath == entity.path) {
//         await _player.stop();
//         setState(() => _currentlyPlayingPath = null);
//       }
//       _fileManager.deleteItem(entity, () => setState(() {}));
//     }
//   }
// }

// // --------------------------------------------------------------------------
// // --------------------------------------------------------------------------
// // CLASE AUXILIAR PARA DISEÑO DE NOTIFICACIÓN
// // --------------------------------------------------------------------------
// class _RecordingNotification {
//   Future<void> show({
//     required FlutterLocalNotificationsPlugin plugin,
//     required int duration,
//     required bool isPaused,
//   }) async {
//     String time = _formatDuration(duration);

//     final AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//           'grabadora_channel_id',
//           'Grabadora',
//           channelDescription:
//               'Canal para control de grabación en segundo plano',
//           importance: Importance.max,
//           priority: Priority.high,
//           ongoing: true,
//           autoCancel: false,
//           icon: '@mipmap/ic_launcher',
//           playSound: false,

//           // --- BOTONES ---
//           actions: <AndroidNotificationAction>[
//             AndroidNotificationAction(
//               'pause',
//               isPaused ? 'Reanudar' : 'Pausar',
//               icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
//               showsUserInterface: true,
//             ),
//             AndroidNotificationAction(
//               'stop',
//               'Detener',
//               icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
//               showsUserInterface: true,
//             ),
//           ],
//         );

//     final NotificationDetails platformChannelSpecifics = NotificationDetails(
//       android: androidPlatformChannelSpecifics,
//     );

//     try {
//       // Se mantiene la sintaxis antigua por si tu versión lo requiere
//       await plugin.show(
//         id: 100,
//         title: 'Grabando Audio',
//         body: time,
//         notificationDetails: platformChannelSpecifics,
//         payload: 'open_app',
//       );
//     } catch (e) {
//       debugPrint("Error mostrando notificación: $e");
//     }
//   }

//   String _formatDuration(int seconds) {
//     final int minutes = seconds ~/ 60;
//     final int remainingSeconds = seconds % 60;
//     return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
//   }
// }

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

//UI
import 'package:grabadora/screens/UI/storage.dart';

//SCREEN
import 'package:grabadora/screens/configuracion.dart';
import 'package:grabadora/screens/tema.dart';
// import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

// PAQUETES EXTERNOS
import 'package:share_plus/share_plus.dart';
// SE HA ELIMINADO JUST_AUDIO PARA EVITAR CONFLICTOS
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// IMPORTANTE PARA LA NOTIFICACIÓN
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key});

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen>
    with WidgetsBindingObserver {
  // --- Grabadora ---
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;

  // --- Reproductor ---
  final AudioPlayer _player = AudioPlayer();
  String? _currentlyPlayingPath;
  bool _isSliderDragging = false;
  double _currentSliderValue = 0.0;
  Duration? _currentAudioDuration;

  // --- Configuración ---
  // CAMBIO: El encoder por defecto o para la selección de OGG
  AudioEncoder _selectedEncoder = AudioEncoder.aacLc;
  String _selectedExtension = 'm4a';

  // --- Timer ---
  Timer? _timer;
  int _recordDuration = 0;

  // --- Notificaciones ---
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _RecordingNotification _recordingNotification =
      _RecordingNotification();

  // --- FileManager ---
  final FileManager _fileManager = FileManager();

  @override
  void initState() {
    super.initState();
    // IMPORTANTE: Escuchar cambios de ciclo de vida (AppMinimize/Resume)
    WidgetsBinding.instance.addObserver(this);
    _initNotifications(); // Inicializar notificaciones
    _initPlayer();
    _fileManager.initializeRootDirectory(() {
      if (mounted) setState(() {});
    });
    _checkDisclaimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Dejar de escuchar
    _stopNotificationService();
    _audioRecorder.dispose();
    _timer?.cancel();
    _player.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // DETECTAR CUANDO LA APP SE VA O VUELVE (Cambios visuales de notificación)
  // -------------------------------------------------------------------------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Si la app pasa a segundo plano o inactiva, actualizamos la notificación
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRecording) {
        _showRecordingNotification();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Si volvemos a la app, la notificación ya no es necesaria visualmente,
      // pero la mantenemos viva para los controles si el usuario baja la barra.
      // Si quieres eliminarla al volver, descomenta la siguiente línea:
      // _stopNotificationService();
    }
  }

  // --------------------------------------------------------------------------
  // GESTIÓN DE NOTIFICACIONES
  // --------------------------------------------------------------------------
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const IOSInitializationSettings initializationSettingsIOS =
        IOSInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      // CORRECCIÓN: Lógica corregida para leer el actionId correctamente
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId == 'pause') {
          // Si se pulsa el botón de pausa/reanudar de la notificación
          _pauseRecording();
        } else if (response.actionId == 'stop') {
          _stopRecording();
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  static void notificationTapBackground(NotificationResponse response) {
    // Manejo en segundo plano
  }

  Future<void> _showRecordingNotification() async {
    // NUEVO: Solo mostrar si la app está en segundo plano
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != AppLifecycleState.resumed) {
      await _recordingNotification.show(
        plugin: _notificationsPlugin,
        duration: _recordDuration,
        isPaused: _isPaused,
      );
    }
  }

  Future<void> _stopNotificationService() async {
    await _notificationsPlugin.cancel(id: 100);
  }

  // --------------------------------------------------------------------------
  // REPRODUCTOR (CORREGIDO PARA AUDIOPLAYERS)
  // --------------------------------------------------------------------------
  void _initPlayer() {
    // Listener para posición
    _player.onPositionChanged.listen((Duration position) {
      if (mounted && !_isSliderDragging && _currentlyPlayingPath != null) {
        // Usamos getDuration() porque es async en audioplayers
        _player.getDuration().then((duration) {
          if (duration != null && mounted) {
            setState(() {
              _currentSliderValue =
                  position.inMilliseconds / duration.inMilliseconds;
            });
          }
        });
      }
    });

    // Listener para cuando termina
    _player.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _currentSliderValue = 0.0;
          _currentlyPlayingPath = null;
        });
      }
    });
  }

  void _onSliderChangeStart() {
    setState(() => _isSliderDragging = true);
  }

  void _onSliderChangeEnd(double value) async {
    setState(() => _isSliderDragging = false);
    final duration = await _player.getDuration();
    if (duration != null) {
      final position = Duration(
        milliseconds: (duration.inMilliseconds * value).toInt(),
      );
      await _player.seek(position);
    }
  }

  Future<void> _togglePlay(File entity) async {
    String path = entity.path;

    // Si ya está sonando este archivo
    if (_currentlyPlayingPath == path) {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    try {
      // Detener anterior si existe
      await _player.stop();

      // Cargar archivo OGG (u otros)
      await _player.setSourceDeviceFile(entity.path);

      // Pequeño delay para asegurar que cargue la duración
      await Future.delayed(const Duration(milliseconds: 300));

      // Reproducir
      await _player.resume();

      // Obtener duración con getDuration()
      Duration? d = await _player.getDuration();

      setState(() {
        _currentlyPlayingPath = path;
        _currentSliderValue = 0.0;
        _currentAudioDuration = d;
      });
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
    if (_player.state == PlayerState.playing) {
      await _player.stop();
      setState(() {
        _currentlyPlayingPath = null;
        _currentSliderValue = 0.0;
      });
    }
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String dirPath = _fileManager.currentDirectory!.path;
      if (!dirPath.endsWith(Platform.pathSeparator))
        dirPath += Platform.pathSeparator;
      final String filePath = '${dirPath}rec_$timestamp.$_selectedExtension';

      // Configuración LIMPIA
      RecordConfig config;

      // Si es AAC (M4A)
      if (_selectedEncoder == AudioEncoder.aacLc) {
        config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1, // Mono
        );
      }
      // CAMBIO: Si es OGG (OPUS)
      // Reemplaza la lógica anterior de WAV (PCM)
      else if (_selectedEncoder == AudioEncoder.opus) {
        config = RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 64000, // Tasa de bits típica para opus
          sampleRate: 48000, // Sample rate típico para opus
          numChannels: 1, // Mono
        );
      }
      // FLAC
      else {
        config = RecordConfig(encoder: AudioEncoder.flac);
      }

      await _audioRecorder.start(config, path: filePath);

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
          const SnackBar(
            content: Text("Error al grabar. Revisa permisos o formato."),
          ),
        );
    }
  }

  // --------------------------------------------------------------------------
  // CAMBIO CLAVE AQUÍ: Lógica toggle (Pausar/Reanudar) unificada
  // --------------------------------------------------------------------------
  Future<void> _pauseRecording() async {
    if (_isPaused) {
      // Si está pausado, reanudamos
      await _audioRecorder.resume();
      _startTimer();
      setState(() => _isPaused = false);
    } else {
      // Si está grabando, pausamos
      await _audioRecorder.pause();
      _timer?.cancel();
      setState(() => _isPaused = true);
    }
    // IMPORTANTE: Actualizar la notificación para que cambie el icono/texto
    _showRecordingNotification();
  }

  Future<void> _resumeRecording() async {
    // Esta función se mantiene por si se usa internamente en la UI
    await _audioRecorder.resume();
    _startTimer();
    setState(() => _isPaused = false);
    _showRecordingNotification();
  }

  Future<void> _stopRecording() async {
    await _audioRecorder.stop();
    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = 0;
    });
    _stopNotificationService();
    await WakelockPlus.disable();
    await _fileManager.loadDirectoryContents();
    setState(() {});
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
      _showRecordingNotification(); // Intenta actualizar (solo se ve si está en background)
    });
  }

  String _formatRecordDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text("Aviso Legal"),
          ],
        ),
        content: const Text(
          "Esta aplicación es una herramienta de grabación de audio personal.\n\nEl usuario es el único responsable del contenido que grabe, almacene y comparta. Los desarrolladores no se hacen responsables del uso indebido de esta aplicación.\n\nAl continuar, aceptas estos términos.",
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
  // UI BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = themeProvider.currentTheme;

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        if (_fileManager.navigationHistory.length > 1) {
          _fileManager.navigateBack(() => setState(() {}));
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
                  title: const Text("Versión 12"),
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
        drawer: _buildDrawer(theme, themeProvider),
        body: _buildBodyContent(theme),
      ),
    );
  }

  Widget _buildDrawer(ThemeData theme, ThemeProvider themeProvider) {
    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(
                    0.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.mic_rounded,
                                color: Colors.blueGrey,
                                size: 26,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
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
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 8),
                    _buildNavigationTile(
                      context,
                      icon: Icons.settings_suggest_rounded,
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
                                  // CAMBIO: Lógica actualizada para OGG
                                  if (encoder == AudioEncoder.opus) {
                                    _selectedExtension = 'ogg';
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
                        await _fileManager.initializeRootDirectory(
                          () => setState(() {}),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
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
    final finalColor = isDestructive
        ? colorScheme.error
        : colorScheme.onSurface;
    final iconColor = isDestructive ? colorScheme.error : Colors.blueGrey;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        dense: true,
        horizontalTitleGap: 12,
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
    List<Directory> folders = _fileManager.currentEntities
        .whereType<Directory>()
        .toList();
    List<File> files = _fileManager.currentEntities
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.m4a') ||
              f.path.endsWith('.ogg') || // CAMBIO: Filtro OGG añadido
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
                // CAMBIO: Dropdown item actualizado a OGG
                DropdownMenuItem(value: AudioEncoder.opus, child: Text("OGG")),
                DropdownMenuItem(value: AudioEncoder.flac, child: Text("FLAC")),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedEncoder = v;
                    // CAMBIO: Lógica de extensión actualizada
                    _selectedExtension = v == AudioEncoder.opus
                        ? 'ogg'
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
                color: Colors.blueGrey,
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
              if (_fileManager.navigationHistory.length > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 15),
                  color: Colors.blueGrey,
                  onPressed: () =>
                      _fileManager.navigateBack(() => setState(() {})),
                ),
              Expanded(
                child: Text(
                  _fileManager.currentDirectory?.path
                          .split(Platform.pathSeparator)
                          .last ??
                      "Cargando...",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.create_new_folder,
                  color: Colors.blueGrey,
                ),
                onPressed: () => _showCreateFolderDialog(theme),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: (folders.isEmpty && files.isEmpty)
              ? Center(
                  child: Text(
                    "No hay grabaciones",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: folders.length + files.length,
                  itemBuilder: (context, index) {
                    if (index < folders.length) {
                      Directory folder = folders[index];
                      return _buildFileTile(theme, folder, null);
                    } else {
                      File file = files[index - folders.length];
                      bool isPlaying = _currentlyPlayingPath == file.path;
                      return _buildFileTile(theme, file, isPlaying);
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFileTile(
    ThemeData theme,
    FileSystemEntity entity,
    bool? isPlaying,
  ) {
    bool isFolder = entity is Directory;
    String name = entity.path.split(Platform.pathSeparator).last;

    // Actualizado para usar state de audioplayers
    bool isThisPlaying =
        (isPlaying ?? false) && _player.state == PlayerState.playing;

    Duration? duration = _currentAudioDuration;
    String positionText = "00:00";
    String totalText = "00:00";

    if (!isFolder && duration != null) {
      final currentPosition = duration * _currentSliderValue;
      positionText = _formatDuration(currentPosition);
      totalText = _formatDuration(duration);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          isFolder
              ? Icons.folder
              : (isThisPlaying ? Icons.graphic_eq : Icons.mic_none),
          color: isFolder
              ? Colors.blueGrey
              : (isThisPlaying ? Colors.redAccent : Colors.grey),
          size: 28,
        ),
        title: Text(
          name,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        subtitle: (isFolder || !isThisPlaying)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                      activeTrackColor: Colors.blueGrey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                      thumbColor: Colors.blueGrey,
                    ),
                    child: Slider(
                      value: _currentSliderValue,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (value) {
                        setState(() => _currentSliderValue = value);
                      },
                      onChangeStart: (_) => _onSliderChangeStart(),
                      onChangeEnd: (value) => _onSliderChangeEnd(value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      "$positionText / $totalText",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isFolder)
              IconButton(
                icon: Icon(isThisPlaying ? Icons.pause : Icons.play_arrow),
                color: Colors.blueGrey,
                iconSize: 28,
                onPressed: () => _togglePlay(entity as File),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                if (value == 'rename') await _showRenameDialog(theme, entity);
                if (value == 'delete') await _showDeleteDialog(entity);
                if (value == 'move')
                  await _fileManager.moveItem(
                    entity,
                    context,
                    () => setState(() {}),
                  );
                if (value == 'share')
                  await Share.shareXFiles([
                    XFile(entity.path),
                  ], text: 'Audio grabado');
              },
              itemBuilder: (context) {
                List<PopupMenuEntry<String>> items = [];
                items.add(
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Renombrar'),
                  ),
                );
                if (!isFolder) {
                  items.add(
                    const PopupMenuItem(value: 'move', child: Text('Mover')),
                  );
                  items.add(
                    const PopupMenuItem(
                      value: 'share',
                      child: Text('Compartir'),
                    ),
                  );
                }
                items.add(
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                );
                return items;
              },
            ),
          ],
        ),
        onTap: isFolder
            ? () => _fileManager.navigateIntoDirectory(
                entity as Directory,
                () => setState(() {}),
              )
            : () => _togglePlay(entity as File),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DIALOGS
  // --------------------------------------------------------------------------
  Future<void> _showCreateFolderDialog(ThemeData theme) async {
    final controller = TextEditingController();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Carpeta"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nombre de la carpeta"),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _fileManager.createFolder(
                  controller.text,
                  context,
                  () => setState(() {}),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Crear"),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(
    ThemeData theme,
    FileSystemEntity entity,
  ) async {
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
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (entity is File && _currentlyPlayingPath == entity.path) {
                  _player.stop();
                  setState(() => _currentlyPlayingPath = null);
                }
                _fileManager.renameItem(
                  entity,
                  controller.text,
                  () => setState(() {}),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(FileSystemEntity entity) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar"),
        content: Text(
          "¿Estás seguro de eliminar ${entity.path.split(Platform.pathSeparator).last}?",
        ),
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
      if (entity is File && _currentlyPlayingPath == entity.path) {
        await _player.stop();
        setState(() => _currentlyPlayingPath = null);
      }
      _fileManager.deleteItem(entity, () => setState(() {}));
    }
  }
}

// --------------------------------------------------------------------------
// --------------------------------------------------------------------------
// CLASE AUXILIAR PARA DISEÑO DE NOTIFICACIÓN
// --------------------------------------------------------------------------
class _RecordingNotification {
  Future<void> show({
    required FlutterLocalNotificationsPlugin plugin,
    required int duration,
    required bool isPaused,
  }) async {
    String time = _formatDuration(duration);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'grabadora_channel_id',
          'Grabadora',
          channelDescription:
              'Canal para control de grabación en segundo plano',
          importance: Importance.max,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          icon: '@mipmap/ic_launcher',
          playSound: false,

          // --- BOTONES ---
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'pause',
              isPaused ? 'Reanudar' : 'Pausar',
              icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'stop',
              'Detener',
              icon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              showsUserInterface: true,
            ),
          ],
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await plugin.show(
        id: 100,
        title: 'Grabando Audio',
        body: time,
        notificationDetails: platformChannelSpecifics,
        payload: 'open_app',
      );
    } catch (e) {
      debugPrint("Error mostrando notificación: $e");
    }
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
