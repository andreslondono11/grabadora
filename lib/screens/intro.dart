// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Importante para recordar
// import 'package:grabadora/screens/recordi_a.dart';

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
//   String _statusMessage = "Iniciando...";

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

//     // 2. Iniciar el flujo inteligente
//     _startSmartFlow();
//   }

//   // --------------------------------------------------------------------------
//   // FLUJO INTELIGENTE (VERIFICA PERMISOS ANTES DE MOLESTAR)
//   // --------------------------------------------------------------------------

//   Future<void> _startSmartFlow() async {
//     // Esperamos animación
//     await Future.delayed(const Duration(seconds: 2));

//     // Verificamos si ya tenemos los permisos concedidos
//     bool micOk = await Permission.microphone.isGranted;
//     bool storageOk = false;

//     if (Platform.isAndroid) {
//       storageOk = await Permission.manageExternalStorage.isGranted;
//     } else {
//       storageOk = await Permission.storage.isGranted;
//     }

//     // Verificamos si el usuario YA había visto y aceptado el aviso antes
//     final prefs = await SharedPreferences.getInstance();
//     final bool hasAcceptedDisclaimer =
//         prefs.getBool('user_accepted_disclaimer') ?? false;

//     // CASO 1: Si TENEMOS permisos Y YA aceptó el aviso -> IR DIRECTO A LA APP
//     if (micOk && storageOk && hasAcceptedDisclaimer) {
//       _navigateToHome();
//       return;
//     }

//     // CASO 2: Si NO tiene permisos (o es primera vez) -> Mostrar explicación
//     // Nota: Aunque tenga permisos pero sea la primera vez (hasAcceptedDisclaimer = false), mostramos el aviso.
//     if (!hasAcceptedDisclaimer) {
//       _showInitialDisclaimer();
//     } else {
//       // Si ya aceptó el aviso pero le quitó los permisos manualmente, pedimos permisos directamente
//       _requestPermissionsNow();
//     }
//   }

//   // --------------------------------------------------------------------------
//   // DIÁLOGO INICIAL (SOLO UNA VEZ EN LA VIDA)
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
//             "Para ofrecerte la mejor experiencia, Grabadora Pro PZ necesita acceso a los siguientes servicios:\n\n"
//             "1. 🎤 **Micrófono:** Para grabar audio de alta calidad.\n"
//             "2. 📁 **Almacenamiento:** Para guardar tus grabaciones en la carpeta 'GrabadoraProPZ' y gestionar tus archivos.\n\n"
//             "Sin estos permisos, la aplicación no podrá funcionar correctamente.",
//             style: TextStyle(color: Colors.white70, height: 1.5),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               SystemNavigator.pop();
//             },
//             child: const Text("Salir", style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);

//               // --- IMPORTANTE: GUARDAR QUE YA LO ACEPTÓ ---
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.setBool('user_accepted_disclaimer', true);

//               // Ahora sí pedimos permisos
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
//   // SOLICITUD DE PERMISOS AL SISTEMA
//   // --------------------------------------------------------------------------
//   Future<void> _requestPermissionsNow() async {
//     setState(() => _showLoading = true);
//     setState(() => _statusMessage = "Configurando Micrófono...");

//     // 1. Pedir Micrófono
//     var micStatus = await Permission.microphone.status;
//     if (!micStatus.isGranted) {
//       micStatus = await Permission.microphone.request();
//     }

//     if (!micStatus.isGranted) {
//       if (micStatus.isPermanentlyDenied) {
//         _showOpenSettingsDialog("Micrófono");
//       } else {
//         _showFatalError("Permiso de micrófono denegado.");
//       }
//       return;
//     }

//     // 2. Pedir Almacenamiento
//     setState(() => _statusMessage = "Configurando Almacenamiento...");

//     if (Platform.isAndroid) {
//       var storageStatus = await Permission.manageExternalStorage.status;
//       if (!storageStatus.isGranted) {
//         storageStatus = await Permission.manageExternalStorage.request();
//       }

//       if (!storageStatus.isGranted) {
//         if (storageStatus.isPermanentlyDenied) {
//           _showOpenSettingsDialog("Almacenamiento");
//         } else {
//           _showFatalError("Permiso de almacenamiento denegado.");
//         }
//         return;
//       }
//     } else {
//       var storageStatus = await Permission.storage.status;
//       if (!storageStatus.isGranted) {
//         storageStatus = await Permission.storage.request();
//       }
//       if (!storageStatus.isGranted) {
//         _showFatalError("Permiso de almacenamiento denegado.");
//         return;
//       }
//     }

//     _navigateToHome();
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
//           "Permiso Denegado",
//           style: TextStyle(color: Colors.redAccent),
//         ),
//         content: Text(
//           "Has denegado el acceso a $permName permanentemente.\n\n"
//           "Debes habilitarlo manualmente en la configuración de tu sistema.",
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
//             label: const Text("Ir a Ajustes"),
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
//         title: const Text("Error", style: TextStyle(color: Colors.red)),
//         content: Text(message, style: const TextStyle(color: Colors.white)),
//         actions: [
//           ElevatedButton(
//             onPressed: () => SystemNavigator.pop(),
//             child: const Text("Cerrar"),
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
//   // UI
//   // --------------------------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
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
//             decoration: BoxDecoration(
//               color: Colors.deepPurpleAccent,
//               shape: BoxShape.circle,
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grabadora/screens/recordi_a.dart';
import 'package:external_path/external_path.dart'; // <--- NUEVA IMPORTACIÓN

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
  String _statusMessage = "Iniciando...";

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

    // 2. Iniciar el flujo inteligente
    _startSmartFlow();
  }

  // --------------------------------------------------------------------------
  // FLUJO INTELIGENTE
  // --------------------------------------------------------------------------

  Future<void> _startSmartFlow() async {
    // Esperamos animación
    await Future.delayed(const Duration(seconds: 2));

    // Verificamos si ya tenemos los permisos concedidos
    bool micOk = await Permission.microphone.isGranted;
    bool storageOk = false;

    if (Platform.isAndroid) {
      // Verificamos manageExternalStorage (Cubre Interno + SD)
      storageOk = await Permission.manageExternalStorage.isGranted;
    } else {
      storageOk = await Permission.storage.isGranted;
    }

    // Verificamos si el usuario YA había visto y aceptado el aviso antes
    final prefs = await SharedPreferences.getInstance();
    final bool hasAcceptedDisclaimer =
        prefs.getBool('user_accepted_disclaimer') ?? false;

    // CASO 1: Si TENEMOS permisos Y YA aceptó el aviso -> IR DIRECTO A LA APP
    if (micOk && storageOk && hasAcceptedDisclaimer) {
      _navigateToHome();
      return;
    }

    // CASO 2: Si NO tiene permisos (o es primera vez) -> Mostrar explicación
    if (!hasAcceptedDisclaimer) {
      _showInitialDisclaimer();
    } else {
      // Si ya aceptó el aviso pero le quitó los permisos manualmente, pedimos permisos directamente
      _requestPermissionsNow();
    }
  }

  // --------------------------------------------------------------------------
  // DIÁLOGO INICIAL (ACTUALIZADO CON SD)
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
            "2. 📱 **Memoria del Teléfono:** Para guardar la app y configuraciones básicas.\n"
            "3. 💾 **Tarjeta SD (Memoria Externa):** Para guardar tus grabaciones directamente en tu tarjeta de memoria externa.\n\n"
            "Sin estos permisos, la aplicación no podrá gestionar tus archivos.",
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

              // --- IMPORTANTE: GUARDAR QUE YA LO ACEPTÓ ---
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('user_accepted_disclaimer', true);

              // Ahora sí pedimos permisos
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
  // SOLICITUD DE PERMISOS (ACTUALIZADO PARA SD)
  // --------------------------------------------------------------------------
  Future<void> _requestPermissionsNow() async {
    setState(() => _showLoading = true);
    setState(() => _statusMessage = "Configurando Micrófono...");

    // 1. Pedir Micrófono
    bool micGranted = await _requestMicrophone();
    if (!micGranted) return;

    // 2. Pedir Almacenamiento y SD
    setState(() => _statusMessage = "Configurando Almacenamiento y SD...");
    bool storageGranted = await _requestStorageAndSD();

    if (storageGranted) {
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
    if (Platform.isAndroid) {
      // En Android 11+ (SDK 30+), manageExternalStorage es el único camino real para la SD
      var storageStatus = await Permission.manageExternalStorage.status;

      if (!storageStatus.isGranted) {
        // Solicitamos el permiso "All files access"
        storageStatus = await Permission.manageExternalStorage.request();
      }

      if (!storageStatus.isGranted) {
        if (storageStatus.isPermanentlyDenied) {
          _showOpenSettingsDialog("Almacenamiento y SD");
        } else {
          _showFatalError("Permiso de almacenamiento y SD denegado.");
        }
        return false;
      } else {
        // Extra: Verificar si hay tarjeta SD insertada para dar feedback al usuario
        _checkSDCardPresence();
      }
    } else {
      // iOS
      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }
      if (!storageStatus.isGranted) {
        _showFatalError("Permiso de almacenamiento denegado.");
        return false;
      }
    }
    return true;
  }

  // Comprobación opcional para informar al usuario si detectamos una SD
  // Comprobación opcional para informar al usuario si detectamos una SD
  Future<void> _checkSDCardPresence() async {
    try {
      // external_path ayuda a listar los directorios disponibles
      // Usamos ?? [] para manejar si devuelve null
      List<String> paths =
          await ExternalPath.getExternalStorageDirectories() ?? [];

      // Si hay más de una ruta, asumimos que hay una tarjeta SD insertada
      if (paths.length > 1) {
        if (mounted) {
          setState(() => _statusMessage = "¡Tarjeta SD detectada!");
        }
      }
    } catch (e) {
      // Ignoramos errores en esta detección, no es crítica
      print("Error detectando SD: $e");
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
          "Permiso Denegado",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          "Has denegado el acceso a $permName permanentemente.\n\n"
          "Debes habilitarlo manualmente en la configuración de tu sistema.",
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
            label: const Text("Ir a Ajustes"),
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
        title: const Text("Error", style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text("Cerrar"),
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
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
