import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grabadora/screens/recordi_a.dart'; // Asegúrate que esta ruta sea correcta
import 'package:external_path/external_path.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Estados de la UI
  bool _showLoading = true;
  String _statusMessage = "Verificando permisos...";

  @override
  void initState() {
    super.initState();

    // 1. Configuración de la animación
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    CurvedAnimation curvedAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);

    _mainController.forward();

    // 2. Iniciar el flujo INMEDIATAMENTE (sin espera forzada de 2 segundos)
    _startSmartFlow();
  }

  // --------------------------------------------------------------------------
  // FLUJO INTELIGENTE CORREGIDO
  // --------------------------------------------------------------------------

  Future<void> _startSmartFlow() async {
    // Leemos el estado del disclaimer
    final prefs = await SharedPreferences.getInstance();
    final bool hasAcceptedDisclaimer =
        prefs.getBool('user_accepted_disclaimer') ?? false;

    // Verificamos el estado ACTUAL de los permisos
    bool micOk = await Permission.microphone.isGranted;

    // Usamos una sola línea para verificar almacenamiento, permission_handler abstrae la plataforma
    bool storageOk =
        await Permission.manageExternalStorage.isGranted ||
        await Permission.storage.isGranted;

    // CASO 1: Si TENEMOS permisos concedidos -> IR DIRECTO A LA APP
    // No importa si hasAcceptedDisclaimer es true o false. Si tenemos permisos, entramos.
    if (micOk && storageOk) {
      // Pequeño delay solo visual para que se vea el logo, pero la lógica ya pasó
      if (mounted) _navigateToHome();
      return;
    }

    // CASO 2: Si NO tiene permisos -> Mostrar explicación (Disclaimer)
    if (!hasAcceptedDisclaimer) {
      _showInitialDisclaimer();
    } else {
      // CASO 3: Aceptó el disclaimer antes, pero revocó los permisos
      // Pedimos permisos directamente
      _requestPermissionsNow();
    }
  }

  // --------------------------------------------------------------------------
  // DIÁLOGO INICIAL
  // --------------------------------------------------------------------------
  void _showInitialDisclaimer() {
    setState(() => _showLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.deepPurpleAccent, size: 28),
            SizedBox(width: 10),
            Text("Permisos Necesarios", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "Para ofrecerte la mejor experiencia, Grabadora Pro PZ necesita acceso a los siguientes servicios:\n\n"
            "1. 🎤 **Micrófono:** Para grabar audio de alta calidad.\n"
            "2. 📱 **Memoria del Teléfono y SD:** Para guardar tus grabaciones de forma segura.\n\n"
            "Sin estos permisos, la aplicación no podrá funcionar.",
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            child: const Text("Salir", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // --- GUARDAR QUE ACEPTÓ EL AVISO ---
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('user_accepted_disclaimer', true);

              // Pedir permisos
              _requestPermissionsNow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
            ),
            child: const Text("Entendido, Aceptar"),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SOLICITUD DE PERMISOS
  // --------------------------------------------------------------------------
  Future<void> _requestPermissionsNow() async {
    setState(() => _showLoading = true);
    setState(() => _statusMessage = "Solicitando Micrófono...");

    // 1. Pedir Micrófono
    bool micGranted = await _requestMicrophone();
    if (!micGranted) return;

    // 2. Pedir Almacenamiento
    setState(() => _statusMessage = "Solicitando acceso a Almacenamiento...");
    bool storageGranted = await _requestStorageAndSD();

    if (storageGranted) {
      _checkSDCardPresence(); // Feedback opcional
      // Esperamos un momento para que el usuario vea el mensaje de éxito si se desea
      await Future.delayed(const Duration(milliseconds: 500));
      _navigateToHome();
    }
  }

  Future<bool> _requestMicrophone() async {
    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    if (!micStatus.isGranted) {
      if (micStatus.isPermanentlyDenied) {
        _showOpenSettingsDialog("Micrófono");
      } else {
        _showFatalError("Permiso de micrófono denegado.");
      }
      return false;
    }
    return true;
  }

  Future<bool> _requestStorageAndSD() async {
    // Intentar pedir ManageExternalStorage (Android 11+)
    // Nota: En algunos dispositivos Huawei, esto podría requerir lógica extra,
    // pero permission_handler suele manejar el caso estándar.

    Map<Permission, PermissionStatus> statuses = await [
      Permission.storage, // Fallback para Android < 11
      Permission.manageExternalStorage, // Para Android 11+ y SD
    ].request();

    bool storageOk = statuses[Permission.storage]?.isGranted ?? false;
    bool manageOk =
        statuses[Permission.manageExternalStorage]?.isGranted ?? false;

    // Aceptamos si tenemos cualquiera de los dos (el que aplique al SO)
    if (!storageOk && !manageOk) {
      // Verificar si fue denegado permanentemente para abrir ajustes
      if (statuses[Permission.manageExternalStorage]!.isPermanentlyDenied) {
        _showOpenSettingsDialog("Almacenamiento");
      } else {
        _showFatalError("Permiso de almacenamiento denegado.");
      }
      return false;
    }

    return true;
  }

  // Comprobación opcional SD
  Future<void> _checkSDCardPresence() async {
    try {
      List<String> paths =
          await ExternalPath.getExternalStorageDirectories() ?? [];
      if (paths.length > 1) {
        if (mounted) {
          setState(() => _statusMessage = "¡Tarjeta SD lista!");
        }
      }
    } catch (e) {
      print("Error SD: $e");
    }
  }

  // --------------------------------------------------------------------------
  // DIALOGOS DE ERROR
  // --------------------------------------------------------------------------

  void _showOpenSettingsDialog(String permName) {
    setState(() => _showLoading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Permiso Necesario",
          style: TextStyle(color: Colors.orange),
        ),
        content: Text(
          "Debes habilitar el acceso a $permName en los ajustes de tu teléfono para continuar.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text("Salir"),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await openAppSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text("Abrir Ajustes"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }

  void _showFatalError(String message) {
    setState(() => _showLoading = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Atención", style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text("Cerrar App"),
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RecorderScreen()),
      );
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Opacity(
              opacity: _showLoading ? 1.0 : 0.3,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Transform.rotate(
                          angle: 0.2,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurpleAccent.withOpacity(
                                    0.6,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                              image: const DecorationImage(
                                image: AssetImage('assets/logo.png'),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        "GRABADORA PRO PZ",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_showLoading) ...[
                      const SizedBox(height: 40),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      _buildLoadingDots(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingDots() {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return _AnimatedDot(index: index, controller: _mainController);
        }),
      ),
    );
  }
}

class _AnimatedDot extends StatelessWidget {
  final int index;
  final AnimationController controller;

  const _AnimatedDot({required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    double delay = index * 0.2;
    Animation<double> animation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(delay, delay + 0.2, curve: Curves.easeInOut),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.deepPurpleAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:grabadora/screens/recordi_a.dart';
// import 'package:external_path/external_path.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with TickerProviderStateMixin {
//   late AnimationController _mainController;
//   late Animation<double> _fadeAnimation;
//   late Animation<double> _scaleAnimation;

//   // Estados de la UI
//   bool _showLoading = true;
//   String _statusMessage = "Verificando permisos...";

//   @override
//   void initState() {
//     super.initState();

//     // 1. Configuración de la animación
//     _mainController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 2000),
//     );

//     CurvedAnimation curvedAnimation = CurvedAnimation(
//       parent: _mainController,
//       curve: Curves.easeOutBack,
//     );

//     _fadeAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(curvedAnimation);
//     _scaleAnimation = Tween<double>(
//       begin: 0.0,
//       end: 1.0,
//     ).animate(curvedAnimation);

//     _mainController.forward();

//     // 2. Iniciar el flujo
//     _startSmartFlow();
//   }

//   // --------------------------------------------------------------------------
//   // FLUJO INTELIGENTE
//   // --------------------------------------------------------------------------
//   Future<void> _startSmartFlow() async {
//     final prefs = await SharedPreferences.getInstance();
//     final bool hasAcceptedDisclaimer =
//         prefs.getBool('user_accepted_disclaimer') ?? false;

//     // Verificamos el estado ACTUAL de TODOS los permisos necesarios
//     bool micOk = await Permission.microphone.isGranted;
//     bool storageOk =
//         await Permission.manageExternalStorage.isGranted ||
//         await Permission.storage.isGranted;
//     bool overlayOk = await FlutterOverlayWindow.isPermissionGranted();

//     // CASO 1: Si TENEMOS TODOS los permisos -> IR DIRECTO A LA APP
//     if (micOk && storageOk && overlayOk) {
//       if (mounted) _navigateToHome();
//       return;
//     }

//     // CASO 2: Si NO tiene permisos -> Mostrar explicación
//     if (!hasAcceptedDisclaimer) {
//       _showInitialDisclaimer();
//     } else {
//       // CASO 3: Aceptó antes, pero falta algo
//       _requestPermissionsNow();
//     }
//   }

//   // --------------------------------------------------------------------------
//   // DIÁLOGO INICIAL
//   // --------------------------------------------------------------------------
//   void _showInitialDisclaimer() {
//     setState(() => _showLoading = false);
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.info_outline, color: Colors.deepPurpleAccent, size: 28),
//             SizedBox(width: 10),
//             Text("Permisos Necesarios", style: TextStyle(color: Colors.white)),
//           ],
//         ),
//         content: const SingleChildScrollView(
//           child: Text(
//             "Para ofrecerte la mejor experiencia, Grabadora Pro PZ necesita acceso a:\n\n"
//             "1. 🎤 **Micrófono:** Para grabar audio.\n"
//             "2. 📱 **Memoria:** Para guardar tus grabaciones.\n"
//             "3. 🫧 **Burbuja Flotante:** Para grabar mientras usas otras apps.\n\n"
//             "Sin estos permisos, la aplicación no podrá funcionar correctamente.",
//             style: TextStyle(color: Colors.white70, height: 1.5),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => SystemNavigator.pop(),
//             child: const Text("Salir", style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.setBool('user_accepted_disclaimer', true);
//               _requestPermissionsNow();
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.deepPurpleAccent,
//             ),
//             child: const Text("Entendido, Aceptar"),
//           ),
//         ],
//       ),
//     );
//   }

//   // --------------------------------------------------------------------------
//   // SOLICITUD DE PERMISOS
//   // --------------------------------------------------------------------------
//   Future<void> _requestPermissionsNow() async {
//     setState(() => _showLoading = true);
//     setState(() => _statusMessage = "Solicitando Micrófono...");

//     bool micGranted = await _requestMicrophone();
//     if (!micGranted) return;

//     setState(() => _statusMessage = "Solicitando acceso a Almacenamiento...");
//     bool storageGranted = await _requestStorageAndSD();
//     if (!storageGranted) return;

//     setState(() => _statusMessage = "Configurando Burbuja Flotante...");
//     bool overlayGranted = await _requestOverlayPermission();

//     if (overlayGranted) {
//       _checkSDCardPresence();
//       await Future.delayed(const Duration(milliseconds: 500));
//       _navigateToHome();
//     }
//   }

//   Future<bool> _requestOverlayPermission() async {
//     bool status = await FlutterOverlayWindow.isPermissionGranted();
//     if (status) return true;

//     try {
//       status = (await FlutterOverlayWindow.requestPermission())!;
//     } catch (e) {
//       debugPrint("Error solicitando overlay: $e");
//       return false;
//     }

//     if (!status) {
//       _showFatalError("El permiso de la Burbuja Flotante es necesario.");
//       return false;
//     }
//     return true;
//   }

//   Future<bool> _requestMicrophone() async {
//     var micStatus = await Permission.microphone.status;
//     if (!micStatus.isGranted) micStatus = await Permission.microphone.request();

//     if (!micStatus.isGranted) {
//       if (micStatus.isPermanentlyDenied) {
//         _showOpenSettingsDialog("Micrófono");
//       } else {
//         _showFatalError("Permiso de micrófono denegado.");
//       }
//       return false;
//     }
//     return true;
//   }

//   Future<bool> _requestStorageAndSD() async {
//     Map<Permission, PermissionStatus> statuses = await [
//       Permission.storage,
//       Permission.manageExternalStorage,
//     ].request();

//     bool storageOk = statuses[Permission.storage]?.isGranted ?? false;
//     bool manageOk =
//         statuses[Permission.manageExternalStorage]?.isGranted ?? false;

//     if (!storageOk && !manageOk) {
//       if (statuses[Permission.manageExternalStorage]!.isPermanentlyDenied) {
//         _showOpenSettingsDialog("Almacenamiento");
//       } else {
//         _showFatalError("Permiso de almacenamiento denegado.");
//       }
//       return false;
//     }
//     return true;
//   }

//   Future<void> _checkSDCardPresence() async {
//     try {
//       List<String> paths =
//           await ExternalPath.getExternalStorageDirectories() ?? [];
//       if (paths.length > 1) {
//         if (mounted) setState(() => _statusMessage = "¡Todo listo!");
//       }
//     } catch (e) {
//       print("Error SD: $e");
//     }
//   }

//   // --------------------------------------------------------------------------
//   // DIALOGOS DE ERROR
//   // --------------------------------------------------------------------------
//   void _showOpenSettingsDialog(String permName) {
//     setState(() => _showLoading = false);
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: const Text(
//           "Permiso Necesario",
//           style: TextStyle(color: Colors.orange),
//         ),
//         content: Text(
//           "Debes habilitar el acceso a $permName en los ajustes.",
//           style: const TextStyle(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => SystemNavigator.pop(),
//             child: const Text("Salir"),
//           ),
//           ElevatedButton.icon(
//             onPressed: () async {
//               await openAppSettings();
//             },
//             icon: const Icon(Icons.settings),
//             label: const Text("Abrir Ajustes"),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orangeAccent,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showFatalError(String message) {
//     setState(() => _showLoading = false);
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: const Text("Atención", style: TextStyle(color: Colors.red)),
//         content: Text(message, style: const TextStyle(color: Colors.white)),
//         actions: [
//           ElevatedButton(
//             onPressed: () => SystemNavigator.pop(),
//             child: const Text("Cerrar App"),
//           ),
//         ],
//       ),
//     );
//   }

//   void _navigateToHome() {
//     if (mounted) {
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (context) => const RecorderScreen()),
//       );
//     }
//   }

//   @override
//   void dispose() {
//     _mainController.dispose();
//     super.dispose();
//   }

//   // --------------------------------------------------------------------------
//   // UI (SIMPLIFICADA)
//   // --------------------------------------------------------------------------
//   @override
//   Widget build(BuildContext context) {
//     // Directamente devolvemos el Scaffold. Sin Navegadores manuales.
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Center(
//             child: Opacity(
//               opacity: _showLoading ? 1.0 : 0.3,
//               child: SingleChildScrollView(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     FadeTransition(
//                       opacity: _fadeAnimation,
//                       child: ScaleTransition(
//                         scale: _scaleAnimation,
//                         child: Transform.rotate(
//                           angle: 0.2,
//                           child: Container(
//                             width: 150,
//                             height: 150,
//                             decoration: BoxDecoration(
//                               shape: BoxShape.circle,
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.deepPurpleAccent.withOpacity(
//                                     0.6,
//                                   ),
//                                   blurRadius: 30,
//                                   spreadRadius: 5,
//                                 ),
//                               ],
//                               image: const DecorationImage(
//                                 image: AssetImage('assets/logo.png'),
//                                 fit: BoxFit.contain,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 50),
//                     FadeTransition(
//                       opacity: _fadeAnimation,
//                       child: const Text(
//                         "GRABADORA PRO PZ",
//                         style: TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                           letterSpacing: 2,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ),
//                     if (_showLoading) ...[
//                       const SizedBox(height: 40),
//                       Text(
//                         _statusMessage,
//                         style: const TextStyle(
//                           color: Colors.grey,
//                           fontSize: 12,
//                         ),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 20),
//                       _buildLoadingDots(),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildLoadingDots() {
//     return SizedBox(
//       height: 30,
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: List.generate(3, (index) {
//           return _AnimatedDot(index: index, controller: _mainController);
//         }),
//       ),
//     );
//   }
// }

// class _AnimatedDot extends StatelessWidget {
//   final int index;
//   final AnimationController controller;

//   const _AnimatedDot({required this.index, required this.controller});

//   @override
//   Widget build(BuildContext context) {
//     double delay = index * 0.2;
//     Animation<double> animation = Tween<double>(begin: 0.2, end: 1.0).animate(
//       CurvedAnimation(
//         parent: controller,
//         curve: Interval(delay, delay + 0.2, curve: Curves.easeInOut),
//       ),
//     );

//     return AnimatedBuilder(
//       animation: animation,
//       builder: (context, child) {
//         return Opacity(
//           opacity: animation.value,
//           child: Container(
//             margin: const EdgeInsets.symmetric(horizontal: 5),
//             width: 12,
//             height: 12,
//             decoration: const BoxDecoration(
//               color: Colors.deepPurpleAccent,
//               shape: BoxShape.circle,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
