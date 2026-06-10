// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:grabadora/screens/tema.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:record/record.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:external_path/external_path.dart'; // <--- IMPORTANTE AGREGAR ESTO

// enum StorageLocation {
//   appPrivate,
//   externalRoot,
//   externalCustom, // Para SD o USB
// }

// class SettingsScreen extends StatefulWidget {
//   final AudioEncoder currentEncoder;
//   final int currentBitRate;
//   final Function(AudioEncoder, int)? onConfigChanged;
//   final ThemeProvider themeProvider;

//   const SettingsScreen({
//     super.key,
//     required this.currentEncoder,
//     required this.currentBitRate,
//     this.onConfigChanged,
//     required this.themeProvider,
//   });

//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends State<SettingsScreen> {
//   // =========================================================================
//   // ESTADO DE LA PANTALLA
//   // =========================================================================

//   late AudioEncoder _selectedEncoder;
//   late int _selectedBitRate;
//   late StorageLocation _storageLocation;
//   String? _customExternalPath; // Ruta completa donde se guardarán los archivos

//   bool _darkMode = true;
//   bool _isScanningStorage = false; // Para mostrar carga al escanear

//   @override
//   void initState() {
//     super.initState();
//     _selectedEncoder = widget.currentEncoder;
//     _selectedBitRate = widget.currentBitRate;

//     // Por defecto es INTERNA
//     _storageLocation = StorageLocation.appPrivate;

//     _loadPreferences();
//   }

//   // =========================================================================
//   // LÓGICA DE DATOS Y PREFERENCIAS
//   // =========================================================================

//   Future<void> _loadPreferences() async {
//     final prefs = await SharedPreferences.getInstance();

//     final savedLocation = prefs.getString('storage_location');
//     final savedCustomPath = prefs.getString('external_custom_path');
//     final bool savedDarkMode = prefs.getBool('dark_mode') ?? true;

//     setState(() {
//       if (savedLocation == 'appPrivate') {
//         _storageLocation = StorageLocation.appPrivate;
//       } else if (savedLocation == 'externalRoot') {
//         _storageLocation = StorageLocation.externalRoot;
//       } else if (savedLocation == 'externalCustom') {
//         _storageLocation = StorageLocation.externalCustom;
//         _customExternalPath = savedCustomPath;
//       } else {
//         _storageLocation = StorageLocation.appPrivate;
//       }
//       _darkMode = savedDarkMode;
//     });
//   }

//   Future<void> _savePreferences() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('storage_location', _storageLocation.name);
//     await prefs.setString('external_custom_path', _customExternalPath ?? '');
//     await prefs.setBool('dark_mode', _darkMode);
//     await widget.themeProvider.toggleTheme(_darkMode);
//   }

//   Future<void> _launchPrivacyPolicy() async {
//     final Uri url = Uri.parse(
//       'https://sites.google.com/view/grabadorapz/p%C3%A1gina-principal',
//     );
//     if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('No se pudo abrir el enlace')),
//         );
//       }
//     }
//   }

//   void _notifyChanges() {
//     if (widget.onConfigChanged != null) {
//       widget.onConfigChanged!(_selectedEncoder, _selectedBitRate);
//     }
//   }

//   // --------------------------------------------------------------------------
//   // DIÁLOGO INFORMATIVO
//   // --------------------------------------------------------------------------
//   void _showAppInfoDialog() {
//     final isDark = widget.themeProvider.isDarkMode;
//     final dialogBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
//     final textColor = isDark ? Colors.white : Colors.black87;

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: dialogBgColor,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: Row(
//           children: [
//             Icon(Icons.info_outline, color: Colors.deepPurpleAccent),
//             const SizedBox(width: 10),
//             Text("Acerca de la App", style: TextStyle(color: textColor)),
//           ],
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 "Grabadora Pro PZ",
//                 style: TextStyle(
//                   color: textColor,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 "Versión 9.0.0 - Lanzada en Junio 2024",
//                 style: TextStyle(
//                   color: textColor.withOpacity(0.7),
//                   fontSize: 14,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 "Funciones Principales:",
//                 style: TextStyle(
//                   color: textColor,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               _buildBulletPoint(
//                 "🎤 Grabación de voz de alta calidad.",
//                 textColor,
//               ),
//               const SizedBox(height: 4),
//               _buildBulletPoint(
//                 "📁 Organización de archivos en carpetas personalizadas.",
//                 textColor,
//               ),
//               const SizedBox(height: 4),
//               _buildBulletPoint(
//                 "🎧 Reproductor de audio integrado con control deslizante.",
//                 textColor,
//               ),
//               const SizedBox(height: 4),
//               _buildBulletPoint(
//                 "📤 Compartir grabaciones fácilmente.",
//                 textColor,
//               ),
//               const SizedBox(height: 4),
//               _buildBulletPoint(
//                 "🌓 Interfaz adaptable (Modo Oscuro / Claro).",
//                 textColor,
//               ),
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               "Entendido",
//               style: TextStyle(color: Colors.deepPurpleAccent),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBulletPoint(String text, Color color) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text("• ", style: TextStyle(color: color, fontSize: 14)),
//         Expanded(
//           child: Text(
//             text,
//             style: TextStyle(color: color.withOpacity(0.8), fontSize: 14),
//           ),
//         ),
//       ],
//     );
//   }

//   // =========================================================================
//   // INTERFAZ DE USUARIO (UI)
//   // =========================================================================

//   @override
//   Widget build(BuildContext context) {
//     final isDark = widget.themeProvider.isDarkMode;
//     final bgColor = isDark ? Colors.black : Colors.grey[50];
//     final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
//     final textColor = isDark ? Colors.white : Colors.black87;
//     final subtitleColor = isDark ? Colors.white70 : Colors.black54;
//     final iconColor = isDark ? Colors.deepPurpleAccent : Colors.deepPurple;

//     return Scaffold(
//       backgroundColor: bgColor,
//       appBar: AppBar(
//         title: Text(
//           'Configuración',
//           style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: bgColor,
//         iconTheme: IconThemeData(color: textColor),
//         elevation: 0,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           _buildSectionTitle("Calidad de Audio", iconColor),
//           const SizedBox(height: 10),

//           _buildFormatSelector(cardColor, textColor, subtitleColor, iconColor),

//           if (_selectedEncoder == AudioEncoder.aacLc)
//             _buildBitrateSelector(
//               cardColor,
//               textColor,
//               subtitleColor,
//               iconColor,
//             ),

//           const SizedBox(height: 30),

//           _buildSectionTitle("General", iconColor),
//           const SizedBox(height: 10),

//           if (Platform.isAndroid)
//             _buildStorageSelector(cardColor, textColor, subtitleColor),

//           if (Platform.isAndroid) const SizedBox(height: 10),

//           _buildThemeSwitch(cardColor, textColor, subtitleColor, iconColor),

//           const SizedBox(height: 30),

//           _buildSectionTitle("Información", iconColor),
//           const SizedBox(height: 10),

//           _buildVersionInfo(cardColor, textColor, subtitleColor),
//           const SizedBox(height: 10),

//           _buildPrivacyPolicyButton(
//             cardColor,
//             textColor,
//             subtitleColor,
//             iconColor,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSectionTitle(String title, Color color) {
//     return Padding(
//       padding: const EdgeInsets.only(left: 8.0),
//       child: Text(
//         title.toUpperCase(),
//         style: TextStyle(
//           color: color,
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//           letterSpacing: 1.2,
//         ),
//       ),
//     );
//   }

//   Widget _buildFormatSelector(
//     Color cardColor,
//     Color textColor,
//     Color subtitleColor,
//     Color iconColor,
//   ) {
//     return _buildSettingCard(
//       cardColor: cardColor,
//       textColor: textColor,
//       subtitleColor: subtitleColor,
//       icon: Icons.audiotrack,
//       title: "Formato de Grabación",
//       subtitle: _getEncoderName(_selectedEncoder),
//       trailing: DropdownButton<AudioEncoder>(
//         value: _selectedEncoder,
//         dropdownColor: cardColor,
//         style: TextStyle(color: textColor),
//         iconEnabledColor: iconColor,
//         onChanged: (AudioEncoder? newValue) {
//           if (newValue != null) {
//             setState(() {
//               _selectedEncoder = newValue;
//               _selectedBitRate = (newValue == AudioEncoder.aacLc) ? 128000 : 0;
//             });
//             _notifyChanges();
//           }
//         },
//         items: const [
//           DropdownMenuItem(
//             value: AudioEncoder.aacLc,
//             child: Text("AAC (.m4a)"),
//           ),
//           DropdownMenuItem(
//             value: AudioEncoder.pcm16bits,
//             child: Text("WAV (.wav)"),
//           ),
//           DropdownMenuItem(
//             value: AudioEncoder.flac,
//             child: Text("FLAC (.flac)"),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildBitrateSelector(
//     Color cardColor,
//     Color textColor,
//     Color subtitleColor,
//     Color iconColor,
//   ) {
//     return _buildSettingCard(
//       cardColor: cardColor,
//       textColor: textColor,
//       subtitleColor: subtitleColor,
//       icon: Icons.high_quality,
//       title: "Tasa de Bits (Bitrate)",
//       subtitle: "${_selectedBitRate ~/ 1000} kbps",
//       trailing: DropdownButton<int>(
//         value: _selectedBitRate,
//         dropdownColor: cardColor,
//         style: TextStyle(color: textColor),
//         iconEnabledColor: iconColor,
//         onChanged: (int? newValue) {
//           if (newValue != null) {
//             setState(() => _selectedBitRate = newValue);
//             _notifyChanges();
//           }
//         },
//         items: const [
//           DropdownMenuItem(value: 64000, child: Text("64 kbps")),
//           DropdownMenuItem(value: 128000, child: Text("128 kbps")),
//           DropdownMenuItem(value: 192000, child: Text("192 kbps")),
//           DropdownMenuItem(value: 256000, child: Text("256 kbps")),
//         ],
//       ),
//     );
//   }

//   // =========================================================================
//   // SELECCIONADOR DE UBICACIÓN (ACTUALIZADO)
//   // =========================================================================

//   Widget _buildStorageSelector(
//     Color cardColor,
//     Color textColor,
//     Color subtitleColor,
//   ) {
//     String subtitleText = "Interna de la App";

//     if (_storageLocation == StorageLocation.externalCustom &&
//         _customExternalPath != null) {
//       // Extraemos el nombre de la carpeta final para mostrar
//       var parts = _customExternalPath!.split(Platform.pathSeparator);
//       var folderName = parts.isNotEmpty ? parts.last : "SD";
//       subtitleText = "Personalizado: .../$folderName";
//     } else if (_storageLocation == StorageLocation.externalCustom) {
//       subtitleText = "Personalizado (Sin elegir)";
//     }

//     return _buildSettingCard(
//       cardColor: cardColor,
//       textColor: textColor,
//       subtitleColor: subtitleColor,
//       icon: Icons.folder,
//       title: "Ubicación de Guardado",
//       subtitle: subtitleText,
//       trailing: _isScanningStorage
//           ? const SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//           : Icon(Icons.chevron_right, color: subtitleColor),
//       onTap: () => _showLocationPicker(cardColor, textColor),
//     );
//   }

//   Future<void> _showLocationPicker(Color cardColor, Color textColor) async {
//     showDialog(
//       context: context,
//       builder: (context) => SimpleDialog(
//         title: Text("Elegir Ubicación", style: TextStyle(color: textColor)),
//         backgroundColor: cardColor,
//         children: [
//           // --- OPCIÓN 1: INTERNA (POR DEFECTO Y PRIMERA EN LA LISTA) ---
//           SimpleDialogOption(
//             onPressed: () {
//               Navigator.pop(context);
//               setState(() {
//                 _storageLocation = StorageLocation.appPrivate;
//                 _customExternalPath = null;
//               });
//               _savePreferences();
//             },
//             child: Row(
//               children: [
//                 Icon(Icons.phone_android, color: textColor, size: 20),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Memoria Interna",
//                         style: TextStyle(
//                           color: textColor,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         "(Recomendado - Más rápido)",
//                         style: TextStyle(
//                           color: textColor.withOpacity(0.6),
//                           fontSize: 12,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const Divider(),

//           // --- OPCIÓN 2: TARJETA SD (SEGUNDARIA) ---
//           SimpleDialogOption(
//             onPressed: () {
//               Navigator.pop(context);
//               _scanAndShowRemovableDrives(cardColor, textColor);
//             },
//             child: Row(
//               children: [
//                 Icon(Icons.sd_card, color: Colors.deepPurpleAccent, size: 20),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Tarjeta SD / Memoria USB",
//                         style: TextStyle(
//                           color: Colors.deepPurpleAccent,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       Text(
//                         "Para almacenamiento externo",
//                         style: TextStyle(
//                           color: textColor.withOpacity(0.6),
//                           fontSize: 12,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // --------------------------------------------------------------------------
//   // --------------------------------------------------------------------------
//   // LÓGICA DE ESCANEO MEJORADA (Usando external_path)
//   // --------------------------------------------------------------------------
//   Future<void> _scanAndShowRemovableDrives(
//     Color cardColor,
//     Color textColor,
//   ) async {
//     // Mostrar estado de carga
//     setState(() => _isScanningStorage = true);

//     List<String> paths = [];

//     try {
//       // CORRECCIÓN: Eliminamos 'type' porque tu versión de la librería no lo usa.
//       // Esto devuelve todas las carpetas de almacenamiento detectadas (SD, USB, etc)
//       paths = await ExternalPath.getExternalStorageDirectories() ?? [];
//     } catch (e) {
//       debugPrint("Error obteniendo rutas externas: $e");
//     }

//     setState(() => _isScanningStorage = false);

//     if (!mounted) return;

//     // Filtrar rutas vacías
//     paths = paths.where((p) => p.isNotEmpty).toList();

//     if (paths.isEmpty) {
//       // CORRECCIÓN: Usamos _showErrorDialog (definido abajo)
//       _showErrorDialog(
//         cardColor,
//         "No detectado",
//         "No se encontraron tarjetas SD o memorias USB conectadas. Asegúrate de que estén insertadas y que la app tenga permisos.",
//       );
//       return;
//     }

//     // Mostrar lista de opciones
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: cardColor,
//         title: Text("Seleccionar Memoria", style: TextStyle(color: textColor)),
//         content: SizedBox(
//           width: double.maxFinite,
//           child: ListView.builder(
//             shrinkWrap: true,
//             itemCount: paths.length,
//             itemBuilder: (context, index) {
//               String path = paths[index];

//               // Intentar identificar si es SD o USB basado en el nombre del volumen
//               String volumeId = path.split(Platform.pathSeparator).last;
//               String displayName = "Memoria Externa";
//               if (volumeId.length > 4) {
//                 displayName = "Tarjeta SD ($volumeId)";
//               } else {
//                 displayName = "Almacenamiento ($volumeId)";
//               }

//               return ListTile(
//                 leading: const Icon(
//                   Icons.sd_card,
//                   color: Colors.deepPurpleAccent,
//                 ),
//                 title: Text(
//                   displayName,
//                   style: TextStyle(
//                     color: textColor,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 subtitle: Text(
//                   "Ruta: $path",
//                   style: TextStyle(
//                     color: textColor.withOpacity(0.5),
//                     fontSize: 11,
//                   ),
//                 ),
//                 onTap: () {
//                   Navigator.pop(context);

//                   // IMPORTANTE: Creamos una carpeta específica dentro de la SD
//                   final appFolder = Directory('$path/GrabadoraProPZ');

//                   setState(() {
//                     _storageLocation = StorageLocation.externalCustom;
//                     _customExternalPath = appFolder.path;
//                   });
//                   _savePreferences();

//                   // Feedback visual
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         "Se usarán las grabaciones en: $displayName",
//                       ),
//                       backgroundColor: Colors.deepPurpleAccent,
//                     ),
//                   );
//                 },
//               );
//             },
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showErrorDialog(Color bgColor, String title, String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: bgColor,
//         title: Text(title, style: const TextStyle(color: Colors.redAccent)),
//         content: Text(message, style: const TextStyle(color: Colors.white70)),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text("Aceptar"),
//           ),
//         ],
//       ),
//     );
//   }
//   // =========================================================================
//   // RESTO DE WIDGETS
//   // =========================================================================

//   Widget _buildThemeSwitch(
//     Color cardColor,
//     Color textColor,
//     Color subtitleColor,
//     Color iconColor,
//   ) {
//     return _buildSettingCard(
//       cardColor: cardColor,
//       textColor: textColor,
//       subtitleColor: subtitleColor,
//       icon: _darkMode ? Icons.dark_mode : Icons.light_mode,
//       title: "Modo Oscuro",
//       subtitle: _darkMode ? "Activado" : "Desactivado",
//       trailing: Switch(
//         value: _darkMode,
//         activeColor: iconColor,
//         onChanged: (bool value) {
//           setState(() => _darkMode = value);
//           _savePreferences();
//         },
//       ),
//     );
//   }

//   Widget _buildVersionInfo(
//     Color cardColor,
//     Color textColor,
//     Color subtitleColor,
//   ) {
//     return _buildSettingCard(
//       cardColor: cardColor,
//       textColor: textColor,
//       subtitleColor: subtitleColor,
//       icon: Icons.info,
//       title: "Versión de la App",
//       subtitle: "Versión 9.0.0",
//       trailing: const Icon(Icons.chevron_right, color: Colors.transparent),
//       onTap: _showAppInfoDialog,
//     );
//   }

//   Widget _buildPrivacyPolicyButton(
//     Color cardColor,
//     Color textColor,
//     Color subtitleColor,
//     Color iconColor,
//   ) {
//     return _buildSettingCard(
//       cardColor: cardColor,
//       textColor: textColor,
//       subtitleColor: subtitleColor,
//       icon: Icons.policy,
//       title: "Políticas de Privacidad",
//       subtitle: "Leer términos y condiciones",
//       trailing: Icon(Icons.open_in_new, color: iconColor),
//       onTap: _launchPrivacyPolicy,
//     );
//   }

//   Widget _buildSettingCard({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color cardColor,
//     required Color textColor,
//     required Color subtitleColor,
//     Widget? trailing,
//     VoidCallback? onTap,
//   }) {
//     return Card(
//       color: cardColor,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: ListTile(
//         leading: Icon(icon, color: textColor),
//         title: Text(title, style: TextStyle(color: textColor)),
//         subtitle: Text(
//           subtitle,
//           style: TextStyle(color: subtitleColor, fontSize: 12),
//         ),
//         trailing: trailing,
//         onTap: onTap,
//       ),
//     );
//   }

//   String _getEncoderName(AudioEncoder encoder) {
//     switch (encoder) {
//       case AudioEncoder.aacLc:
//         return "AAC (.m4a)";
//       case AudioEncoder.pcm16bits:
//         return "WAV (.wav)";
//       case AudioEncoder.flac:
//         return "FLAC (.flac)";
//       default:
//         return "Desconocido";
//     }
//   }
// }
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grabadora/screens/tema.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:external_path/external_path.dart';
import 'package:permission_handler/permission_handler.dart'; // <--- IMPORTANTE AGREGADO

enum StorageLocation {
  appPrivate,
  externalRoot,
  externalCustom, // Para SD o USB
}

class SettingsScreen extends StatefulWidget {
  final AudioEncoder currentEncoder;
  final int currentBitRate;
  final Function(AudioEncoder, int)? onConfigChanged;
  final ThemeProvider themeProvider;

  const SettingsScreen({
    super.key,
    required this.currentEncoder,
    required this.currentBitRate,
    this.onConfigChanged,
    required this.themeProvider,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // =========================================================================
  // ESTADO DE LA PANTALLA
  // =========================================================================

  late AudioEncoder _selectedEncoder;
  late int _selectedBitRate;
  late StorageLocation _storageLocation;
  String? _customExternalPath; // Ruta completa donde se guardarán los archivos

  bool _darkMode = true;
  bool _isScanningStorage = false; // Para mostrar carga al escanear

  @override
  void initState() {
    super.initState();
    _selectedEncoder = widget.currentEncoder;
    _selectedBitRate = widget.currentBitRate;

    // Por defecto es INTERNA (appPrivate)
    _storageLocation = StorageLocation.appPrivate;

    _loadPreferences();
  }

  // =========================================================================
  // LÓGICA DE DATOS Y PREFERENCIAS
  // =========================================================================

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final savedLocation = prefs.getString('storage_location');
    final savedCustomPath = prefs.getString('external_custom_path');
    final bool savedDarkMode = prefs.getBool('dark_mode') ?? true;

    setState(() {
      if (savedLocation == 'appPrivate') {
        _storageLocation = StorageLocation.appPrivate;
      } else if (savedLocation == 'externalRoot') {
        _storageLocation = StorageLocation.externalRoot;
      } else if (savedLocation == 'externalCustom') {
        _storageLocation = StorageLocation.externalCustom;
        _customExternalPath = savedCustomPath;
      } else {
        // Si no hay nada guardado, por defecto INTERNA
        _storageLocation = StorageLocation.appPrivate;
      }
      _darkMode = savedDarkMode;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storage_location', _storageLocation.name);
    await prefs.setString('external_custom_path', _customExternalPath ?? '');
    await prefs.setBool('dark_mode', _darkMode);
    await widget.themeProvider.toggleTheme(_darkMode);
  }

  Future<void> _launchPrivacyPolicy() async {
    final Uri url = Uri.parse(
      'https://sites.google.com/view/grabadorapz/p%C3%A1gina-principal',
    );
    if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace')),
        );
      }
    }
  }

  void _notifyChanges() {
    if (widget.onConfigChanged != null) {
      widget.onConfigChanged!(_selectedEncoder, _selectedBitRate);
    }
  }

  // --------------------------------------------------------------------------
  // DIÁLOGO INFORMATIVO
  // --------------------------------------------------------------------------
  void _showAppInfoDialog() {
    final isDark = widget.themeProvider.isDarkMode;
    final dialogBgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.deepPurpleAccent),
            const SizedBox(width: 10),
            Text("Acerca de la App", style: TextStyle(color: textColor)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Grabadora Pro PZ",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Versión 10.0.0 - Lanzada en Junio 2024",
                style: TextStyle(
                  color: textColor.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Funciones Principales:",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildBulletPoint(
                "🎤 Grabación de voz de alta calidad.",
                textColor,
              ),
              const SizedBox(height: 4),
              _buildBulletPoint(
                "📁 Organización de archivos en carpetas personalizadas.",
                textColor,
              ),
              const SizedBox(height: 4),
              _buildBulletPoint(
                "🎧 Reproductor de audio integrado con control deslizante.",
                textColor,
              ),
              const SizedBox(height: 4),
              _buildBulletPoint(
                "📤 Compartir grabaciones fácilmente.",
                textColor,
              ),
              const SizedBox(height: 4),
              _buildBulletPoint(
                "🌓 Interfaz adaptable (Modo Oscuro / Claro).",
                textColor,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Entendido",
              style: TextStyle(color: Colors.deepPurpleAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("• ", style: TextStyle(color: color, fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 14),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // INTERFAZ DE USUARIO (UI)
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeProvider.isDarkMode;
    final bgColor = isDark ? Colors.black : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;
    final iconColor = isDark ? Colors.deepPurpleAccent : Colors.deepPurple;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Configuración',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bgColor,
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle("Calidad de Audio", iconColor),
          const SizedBox(height: 10),

          _buildFormatSelector(cardColor, textColor, subtitleColor, iconColor),

          if (_selectedEncoder == AudioEncoder.aacLc)
            _buildBitrateSelector(
              cardColor,
              textColor,
              subtitleColor,
              iconColor,
            ),

          const SizedBox(height: 30),

          _buildSectionTitle("General", iconColor),
          const SizedBox(height: 10),

          if (Platform.isAndroid)
            _buildStorageSelector(cardColor, textColor, subtitleColor),

          if (Platform.isAndroid) const SizedBox(height: 10),

          _buildThemeSwitch(cardColor, textColor, subtitleColor, iconColor),

          const SizedBox(height: 30),

          _buildSectionTitle("Información", iconColor),
          const SizedBox(height: 10),

          _buildVersionInfo(cardColor, textColor, subtitleColor),
          const SizedBox(height: 10),

          _buildPrivacyPolicyButton(
            cardColor,
            textColor,
            subtitleColor,
            iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFormatSelector(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color iconColor,
  ) {
    return _buildSettingCard(
      cardColor: cardColor,
      textColor: textColor,
      subtitleColor: subtitleColor,
      icon: Icons.audiotrack,
      title: "Formato de Grabación",
      subtitle: _getEncoderName(_selectedEncoder),
      trailing: DropdownButton<AudioEncoder>(
        value: _selectedEncoder,
        dropdownColor: cardColor,
        style: TextStyle(color: textColor),
        iconEnabledColor: iconColor,
        onChanged: (AudioEncoder? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedEncoder = newValue;
              _selectedBitRate = (newValue == AudioEncoder.aacLc) ? 128000 : 0;
            });
            _notifyChanges();
          }
        },
        items: const [
          DropdownMenuItem(
            value: AudioEncoder.aacLc,
            child: Text("AAC (.m4a)"),
          ),
          DropdownMenuItem(
            value: AudioEncoder.pcm16bits,
            child: Text("WAV (.wav)"),
          ),
          DropdownMenuItem(
            value: AudioEncoder.flac,
            child: Text("FLAC (.flac)"),
          ),
        ],
      ),
    );
  }

  Widget _buildBitrateSelector(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color iconColor,
  ) {
    return _buildSettingCard(
      cardColor: cardColor,
      textColor: textColor,
      subtitleColor: subtitleColor,
      icon: Icons.high_quality,
      title: "Tasa de Bits (Bitrate)",
      subtitle: "${_selectedBitRate ~/ 1000} kbps",
      trailing: DropdownButton<int>(
        value: _selectedBitRate,
        dropdownColor: cardColor,
        style: TextStyle(color: textColor),
        iconEnabledColor: iconColor,
        onChanged: (int? newValue) {
          if (newValue != null) {
            setState(() => _selectedBitRate = newValue);
            _notifyChanges();
          }
        },
        items: const [
          DropdownMenuItem(value: 64000, child: Text("64 kbps")),
          DropdownMenuItem(value: 128000, child: Text("128 kbps")),
          DropdownMenuItem(value: 192000, child: Text("192 kbps")),
          DropdownMenuItem(value: 256000, child: Text("256 kbps")),
        ],
      ),
    );
  }

  // =========================================================================
  // SELECCIONADOR DE UBICACIÓN (CON PERMISOS SD)
  // =========================================================================

  Widget _buildStorageSelector(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    String subtitleText = "Memoria Interna de la App";

    if (_storageLocation == StorageLocation.externalCustom &&
        _customExternalPath != null) {
      var parts = _customExternalPath!.split(Platform.pathSeparator);
      var folderName = parts.isNotEmpty ? parts.last : "SD";
      subtitleText = "Personalizado: .../$folderName";
    } else if (_storageLocation == StorageLocation.externalCustom) {
      subtitleText = "Personalizado (Sin elegir)";
    }

    return _buildSettingCard(
      cardColor: cardColor,
      textColor: textColor,
      subtitleColor: subtitleColor,
      icon: Icons.folder,
      title: "Ubicación de Guardado",
      subtitle: subtitleText,
      trailing: _isScanningStorage
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.chevron_right, color: subtitleColor),
      onTap: () => _showLocationPicker(cardColor, textColor),
    );
  }

  Future<void> _showLocationPicker(Color cardColor, Color textColor) async {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text("Elegir Ubicación", style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        children: [
          // --- OPCIÓN 1: INTERNA (POR DEFECTO) ---
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _storageLocation = StorageLocation.appPrivate;
                _customExternalPath = null;
              });
              _savePreferences();
            },
            child: Row(
              children: [
                Icon(Icons.phone_android, color: textColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Memoria Interna",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "(Recomendado - Más rápido)",
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // --- OPCIÓN 2: TARJETA SD (SOLICITA PERMISOS) ---
          SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(context);

              // 1. Verificar Permisos
              bool hasPermission = await _checkAndRequestStoragePermission();

              if (hasPermission && mounted) {
                // 2. Si tiene permiso, escanear
                _scanAndShowRemovableDrives(cardColor, textColor);
              } else if (mounted) {
                // 3. Si no, mostrar error
                _showErrorDialog(
                  cardColor,
                  "Permiso Denegado",
                  "Necesitas habilitar el acceso completo a los archivos para usar la Tarjeta SD o Discos Duros externos.",
                );
              }
            },
            child: Row(
              children: [
                Icon(Icons.sd_card, color: Colors.deepPurpleAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Tarjeta SD / Memoria USB",
                        style: TextStyle(
                          color: Colors.deepPurpleAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Solicitar permisos y conectar",
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FUNCIÓN PARA VERIFICAR Y PEDIR PERMISOS
  // --------------------------------------------------------------------------
  Future<bool> _checkAndRequestStoragePermission() async {
    // Verificamos si ya tenemos el permiso de gestión total
    var status = await Permission.manageExternalStorage.status;

    if (status.isGranted) {
      return true;
    }

    // Si no está concedido, lo pedimos
    status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      return true;
    }

    // Si fue denegado permanentemente, abrimos configuración
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }

    return false;
  }

  // --------------------------------------------------------------------------
  // LÓGICA DE ESCANEO MEJORADA
  // --------------------------------------------------------------------------
  Future<void> _scanAndShowRemovableDrives(
    Color cardColor,
    Color textColor,
  ) async {
    setState(() => _isScanningStorage = true);

    List<String> paths = [];

    try {
      // Escaneamos todos los volúmenes externos
      paths = await ExternalPath.getExternalStorageDirectories() ?? [];
    } catch (e) {
      debugPrint("Error obteniendo rutas externas: $e");
    }

    setState(() => _isScanningStorage = false);

    if (!mounted) return;

    // Filtrar rutas vacías
    paths = paths.where((p) => p.isNotEmpty).toList();

    if (paths.isEmpty) {
      _showErrorDialog(
        cardColor,
        "No detectado",
        "No se encontraron tarjetas SD o memorias USB conectadas. Asegúrate de que estén insertadas.",
      );
      return;
    }

    // Mostrar lista de opciones
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("Seleccionar Memoria", style: TextStyle(color: textColor)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: paths.length,
            itemBuilder: (context, index) {
              String path = paths[index];

              // Intentar identificar nombre del volumen
              String volumeId = path.split(Platform.pathSeparator).last;
              String displayName = "Memoria Externa";
              if (volumeId.length > 4) {
                displayName = "Tarjeta SD ($volumeId)";
              } else {
                displayName = "Almacenamiento ($volumeId)";
              }

              return ListTile(
                leading: const Icon(
                  Icons.sd_card,
                  color: Colors.deepPurpleAccent,
                ),
                title: Text(
                  displayName,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  "Ruta: $path",
                  style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);

                  // IMPORTANTE: Creamos una carpeta específica dentro de la SD
                  final appFolder = Directory('$path/GrabadoraProPZ');

                  setState(() {
                    _storageLocation = StorageLocation.externalCustom;
                    _customExternalPath = appFolder.path;
                  });
                  _savePreferences();

                  // Feedback visual
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Configurado para guardar en: $displayName",
                      ),
                      backgroundColor: Colors.deepPurpleAccent,
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(Color bgColor, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RESTO DE WIDGETS
  // =========================================================================

  Widget _buildThemeSwitch(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color iconColor,
  ) {
    return _buildSettingCard(
      cardColor: cardColor,
      textColor: textColor,
      subtitleColor: subtitleColor,
      icon: _darkMode ? Icons.dark_mode : Icons.light_mode,
      title: "Modo Oscuro",
      subtitle: _darkMode ? "Activado" : "Desactivado",
      trailing: Switch(
        value: _darkMode,
        activeColor: iconColor,
        onChanged: (bool value) {
          setState(() => _darkMode = value);
          _savePreferences();
        },
      ),
    );
  }

  Widget _buildVersionInfo(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return _buildSettingCard(
      cardColor: cardColor,
      textColor: textColor,
      subtitleColor: subtitleColor,
      icon: Icons.info,
      title: "Versión de la App",
      subtitle: "Versión 10.0.0",
      trailing: const Icon(Icons.chevron_right, color: Colors.transparent),
      onTap: _showAppInfoDialog,
    );
  }

  Widget _buildPrivacyPolicyButton(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color iconColor,
  ) {
    return _buildSettingCard(
      cardColor: cardColor,
      textColor: textColor,
      subtitleColor: subtitleColor,
      icon: Icons.policy,
      title: "Políticas de Privacidad",
      subtitle: "Leer términos y condiciones",
      trailing: Icon(Icons.open_in_new, color: iconColor),
      onTap: _launchPrivacyPolicy,
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(color: textColor)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: subtitleColor, fontSize: 12),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  String _getEncoderName(AudioEncoder encoder) {
    switch (encoder) {
      case AudioEncoder.aacLc:
        return "AAC (.m4a)";
      case AudioEncoder.pcm16bits:
        return "WAV (.wav)";
      case AudioEncoder.flac:
        return "FLAC (.flac)";
      default:
        return "Desconocido";
    }
  }
}
