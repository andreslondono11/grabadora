// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:grabadora/screens/recordi_a.dart'; // Tu pantalla principal
// import 'package:grabadora/screens/intro/help.dart'; // Tu pantalla de ayuda
// // import 'package:grabadora/screens/permission_page.dart'; // La página de tarjetas
// import 'package:external_path/external_path.dart';

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

//   Future<void> _startSmartFlow() async {
//     // Verificar Disclaimer Legal
//     final prefs = await SharedPreferences.getInstance();
//     final bool hasAcceptedDisclaimer =
//         prefs.getBool('user_accepted_disclaimer') ?? false;

//     // Verificar Permisos Técnicos
//     bool micOk = await Permission.microphone.isGranted;
//     bool storageOk =
//         await Permission.manageExternalStorage.isGranted ||
//         await Permission.storage.isGranted;

//     // CASO 1: Todo OK -> IR A LA APP
//     if (micOk && storageOk) {
//       if (mounted) _navigateToHome();
//       return;
//     }

//     // CASO 2: Faltan permisos y no ha aceptado el Legal -> Mostrar Legal con Opciones
//     if (!hasAcceptedDisclaimer) {
//       _showLegalDisclaimer();
//     } else {
//       // CASO 3: Ya aceptó Legal, pero faltan permisos -> IR A PANTALLA VISUAL
//       if (mounted) _navigateToPermissionPage();
//     }
//   }

//   // --------------------------------------------------------------------------
//   // DIÁLOGO LEGAL ACTUALIZADO
//   // --------------------------------------------------------------------------
//   void _showLegalDisclaimer() {
//     setState(() => _showLoading = false);

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         title: const Row(
//           children: [
//             Icon(Icons.security, color: Colors.deepPurpleAccent, size: 28),
//             SizedBox(width: 10),
//             Text("Aviso Legal", style: TextStyle(color: Colors.white)),
//           ],
//         ),
//         content: const SingleChildScrollView(
//           child: Text(
//             "Al usar esta aplicación, aceptas que eres el único responsable del contenido que grabes. "
//             "Los desarrolladores no se hacen responsables del uso indebido de esta herramienta de grabación.\n\n"
//             "Para continuar, necesitamos acceso al Micrófono y Almacenamiento.",
//             style: TextStyle(color: Colors.white70, height: 1.5),
//           ),
//         ),
//         actions: [
//           // Botón Salir
//           TextButton(
//             onPressed: () => SystemNavigator.pop(),
//             child: const Text("Salir", style: TextStyle(color: Colors.grey)),
//           ),

//           const SizedBox(height: 10),

//           // OPCIÓN A: Automático
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               // Guardar aceptación
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.setBool('user_accepted_disclaimer', true);

//               // Intentar pedir permisos directo
//               bool success = await _tryRequestPermissionsAuto();

//               if (success) {
//                 if (mounted) _navigateToHome();
//               } else {
//                 // Si falla o requiere intervención manual, ir a pantalla de permisos
//                 if (mounted) _navigateToPermissionPage();
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.deepPurpleAccent,
//               minimumSize: const Size(double.infinity, 45), // Ancho completo
//             ),
//             child: const Text(
//               "Aceptar y Dar Permisos",
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//           ),

//           const SizedBox(height: 5),

//           // OPCIÓN B: Manual
//           OutlinedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               // Guardar aceptación
//               final prefs = await SharedPreferences.getInstance();
//               await prefs.setBool('user_accepted_disclaimer', true);
//               // Enviar directo a la pantalla de verificación manual
//               if (mounted) _navigateToPermissionPage();
//             },
//             style: OutlinedButton.styleFrom(
//               side: const BorderSide(color: Colors.orangeAccent),
//               minimumSize: const Size(double.infinity, 45),
//             ),
//             child: const Text(
//               "Configurar Manualmente",
//               style: TextStyle(
//                 color: Colors.orangeAccent,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Intenta pedir permisos de forma automática
//   Future<bool> _tryRequestPermissionsAuto() async {
//     try {
//       // Pedir Micrófono
//       var micStatus = await Permission.microphone.request();
//       if (!micStatus.isGranted) return false;

//       // Pedir Almacenamiento (ambos tipos)
//       Map<Permission, PermissionStatus> statuses = await [
//         Permission.storage,
//         Permission.manageExternalStorage,
//       ].request();

//       bool storageOk = statuses[Permission.storage]?.isGranted ?? false;
//       bool manageOk =
//           statuses[Permission.manageExternalStorage]?.isGranted ?? false;

//       return storageOk || manageOk;
//     } catch (e) {
//       return false;
//     }
//   }

//   // --------------------------------------------------------------------------
//   // NAVEGACIÓN
//   // --------------------------------------------------------------------------
//   void _navigateToPermissionPage() {
//     Navigator.of(context).pushReplacement(
//       MaterialPageRoute(builder: (context) => const PermissionPage()),
//     );
//   }

//   void _navigateToHome() {
//     if (mounted) {
//       // Pequeño delay para ver el logo antes de salir
//       Future.delayed(const Duration(milliseconds: 800), () {
//         Navigator.of(context).pushReplacement(
//           MaterialPageRoute(builder: (context) => const RecorderScreen()),
//         );
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _mainController.dispose();
//     super.dispose();
//   }

//   // --------------------------------------------------------------------------
//   // UI (Tu diseño original)
//   // --------------------------------------------------------------------------
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: Opacity(
//           opacity: _showLoading ? 1.0 : 0.3,
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 FadeTransition(
//                   opacity: _fadeAnimation,
//                   child: ScaleTransition(
//                     scale: _scaleAnimation,
//                     child: Transform.rotate(
//                       angle: 0.2,
//                       child: Container(
//                         width: 150,
//                         height: 150,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.deepPurpleAccent.withOpacity(0.6),
//                               blurRadius: 30,
//                               spreadRadius: 5,
//                             ),
//                           ],
//                           image: const DecorationImage(
//                             image: AssetImage('assets/logo.png'),
//                             fit: BoxFit.contain,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 50),
//                 FadeTransition(
//                   opacity: _fadeAnimation,
//                   child: const Text(
//                     "GRABADORA PRO PZ",
//                     style: TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 2,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//                 if (_showLoading) ...[
//                   const SizedBox(height: 40),
//                   Text(
//                     _statusMessage,
//                     style: const TextStyle(color: Colors.grey, fontSize: 12),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 20),
//                   _buildLoadingDots(),
//                 ],
//               ],
//             ),
//           ),
//         ),
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

// // --------------------------------------------------------------------------
// // WIDGET AUXILIAR (Animación)
// // --------------------------------------------------------------------------
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

import 'dart:async';
// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grabadora/screens/recordi_a.dart'; // Tu pantalla principal
import 'package:grabadora/screens/intro/help.dart'; // Tu pantalla de ayuda (si la usas en otro lado)
// import 'package:grabadora/screens/permission_page.dart'; // Importamos la página visual
// import 'package:external_path/external_path.dart'; // No necesario aquí

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

    // 2. Iniciar el flujo lógico
    _startSmartFlow();
  }

  Future<void> _startSmartFlow() async {
    // Verificar Disclaimer Legal
    final prefs = await SharedPreferences.getInstance();
    final bool hasAcceptedDisclaimer =
        prefs.getBool('user_accepted_disclaimer') ?? false;

    // Verificar Permisos Técnicos (Incluye Notificaciones ahora)
    bool micOk = await Permission.microphone.isGranted;
    bool storageOk = await Permission.manageExternalStorage.isGranted;
    bool notificationsOk = await Permission.notification.isGranted;

    // Si storageOk es falso, chequeamos el legacy por si acaso (Android < 11)
    if (!storageOk) {
      storageOk = await Permission.storage.isGranted;
    }

    // CASO 1: Todo OK -> IR A LA APP
    if (micOk && storageOk && notificationsOk) {
      if (mounted) _navigateToHome();
      return;
    }

    // CASO 2: Faltan permisos y no ha aceptado el Legal -> Mostrar Legal con Opciones
    if (!hasAcceptedDisclaimer) {
      _showLegalDisclaimer();
    } else {
      // CASO 3: Ya aceptó Legal, pero faltan permisos -> IR A PANTALLA VISUAL
      if (mounted) _navigateToPermissionPage();
    }
  }

  // --------------------------------------------------------------------------
  // DIÁLOGO LEGAL ACTUALIZADO
  // --------------------------------------------------------------------------
  void _showLegalDisclaimer() {
    // Ocultamos el loader para que se vea el diálogo claramente
    setState(() => _showLoading = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.deepPurpleAccent, size: 28),
            SizedBox(width: 10),
            Text("Aviso Legal", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "Al usar esta aplicación, aceptas que eres el único responsable del contenido que grabes. "
            "Los desarrolladores no se hacen responsables del uso indebido de esta herramienta de grabación.\n\n"
            "Para continuar, necesitamos acceso al Micrófono, Almacenamiento y Notificaciones.",
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        actions: [
          // Botón Salir
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text("Salir", style: TextStyle(color: Colors.grey)),
          ),

          const SizedBox(height: 10),

          // OPCIÓN A: Automático (Intenta pedir todo al vuelo)
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Mostrar loader de nuevo para feedback visual
              setState(() {
                _showLoading = true;
                _statusMessage = "Configurando permisos...";
              });

              // Guardar aceptación legal
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('user_accepted_disclaimer', true);

              // Intentar pedir permisos directo
              bool success = await _tryRequestPermissionsAuto();

              if (success) {
                if (mounted) _navigateToHome();
              } else {
                // Si falla o requiere intervención manual, ir a pantalla de permisos
                if (mounted) _navigateToPermissionPage();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text(
              "Aceptar y Dar Permisos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 5),

          // OPCIÓN B: Manual
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Guardar aceptación
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('user_accepted_disclaimer', true);
              // Enviar directo a la pantalla de verificación manual
              if (mounted) _navigateToPermissionPage();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orangeAccent),
              minimumSize: const Size(double.infinity, 45),
            ),
            child: const Text(
              "Configurar Manualmente",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Intenta pedir permisos de forma automática (Mic, Storage, Notifications)
  Future<bool> _tryRequestPermissionsAuto() async {
    try {
      // 1. Pedir Micrófono
      var micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) return false;

      // 2. Pedir Notificaciones (Android 13+)
      var notifStatus = await Permission.notification.request();
      // Nota: Si el usuario dice "Solo una vez", sigue siendo isGranted = true para el flujo

      // 3. Pedir Almacenamiento
      // Estrategia: Pedir ManageExternalStorage primero (mejor para apps de grabación)
      var manageStatus = await Permission.manageExternalStorage.request();

      if (!manageStatus.isGranted) {
        // Fallback a Storage simple (legacy)
        var storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) return false;
      }

      // Si llegamos aquí, asumimos que tenemos lo básico para funcionar
      return true;
    } catch (e) {
      debugPrint("Error auto-requesting permissions: $e");
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // NAVEGACIÓN
  // --------------------------------------------------------------------------
  void _navigateToPermissionPage() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const PermissionPage()),
    );
  }

  void _navigateToHome() {
    if (mounted) {
      // Pequeño delay para ver el logo antes de salir
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RecorderScreen()),
        );
      });
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
      body: Center(
        child: Opacity(
          // Si no mostramos loading (porque salió el diálogo), bajamos opacidad
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
                              color: Colors.deepPurpleAccent.withOpacity(0.6),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
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

// --------------------------------------------------------------------------
// WIDGET AUXILIAR (Animación)
// --------------------------------------------------------------------------
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
