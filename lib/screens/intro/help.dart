// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:grabadora/screens/recordi_a.dart'; // Asegúrate de la ruta correcta

// class PermissionPage extends StatefulWidget {
//   const PermissionPage({super.key});

//   @override
//   State<PermissionPage> createState() => _PermissionPageState();
// }

// class _PermissionPageState extends State<PermissionPage> {
//   // Estados de los permisos
//   bool _micGranted = false;
//   bool _storageGranted = false;

//   // Para prevenir múltiples clicks
//   bool _isProcessing = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkInitialStatus();
//   }

//   // Verificar estado inicial al entrar
//   Future<void> _checkInitialStatus() async {
//     final mic = await Permission.microphone.status;
//     final storage = await Permission.manageExternalStorage.status;
//     final storageLegacy = await Permission.storage.status;

//     setState(() {
//       _micGranted = mic.isGranted;
//       _storageGranted = storage.isGranted || storageLegacy.isGranted;
//     });
//   }

//   // Verificar si todo está listo para habilitar el botón final
//   bool get _allPermissionsGranted => _micGranted && _storageGranted;

//   // --- ACCIONES ---

//   Future<void> _requestMic() async {
//     if (_isProcessing) return;
//     setState(() => _isProcessing = true);

//     final status = await Permission.microphone.request();

//     if (mounted) {
//       setState(() {
//         _micGranted = status.isGranted;
//         _isProcessing = false;
//       });
//     }
//   }

//   Future<void> _requestStorage() async {
//     if (_isProcessing) return;
//     setState(() => _isProcessing = true);

//     // Pedimos ambos para cubrir Android antiguo y nuevo
//     final statuses = await [
//       Permission.storage,
//       Permission.manageExternalStorage,
//     ].request();

//     final storageOk = statuses[Permission.storage]?.isGranted ?? false;
//     final manageOk =
//         statuses[Permission.manageExternalStorage]?.isGranted ?? false;

//     if (mounted) {
//       setState(() {
//         _storageGranted = storageOk || manageOk;
//         _isProcessing = false;
//       });
//     }
//   }

//   void _openSettings() {
//     openAppSettings().then((_) async {
//       // Cuando el usuario vuelve de ajustes, verificamos de nuevo
//       await _checkInitialStatus();
//     });
//   }

//   void _navigateToApp() {
//     if (_allPermissionsGranted) {
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(builder: (context) => const RecorderScreen()),
//       );
//     }
//   }

//   // --- UI ---

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.close, color: Colors.white),
//           onPressed: () => SystemNavigator.pop(),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 20),
//             const Text(
//               "Configuración Inicial",
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 10),
//             const Text(
//               "Para garantizar que la aplicación funcione correctamente, necesitamos acceso a los siguientes servicios:",
//               style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
//             ),
//             const SizedBox(height: 40),

//             // Tarjeta Micrófono
//             _buildPermissionCard(
//               icon: Icons.mic,
//               title: "Micrófono",
//               description: "Necesario para grabar audios.",
//               isGranted: _micGranted,
//               onTap: _requestMic,
//             ),

//             const SizedBox(height: 20),

//             // Tarjeta Almacenamiento
//             _buildPermissionCard(
//               icon: Icons.folder,
//               title: "Almacenamiento",
//               description: "Guarda archivos y accede a la SD.",
//               isGranted: _storageGranted,
//               onTap: _requestStorage,
//             ),

//             const SizedBox(height: 40),

//             // Mensaje de advertencia si faltan permisos
//             if (!_allPermissionsGranted)
//               const Padding(
//                 padding: EdgeInsets.only(bottom: 20),
//                 child: Text(
//                   "Debes activar todos los permisos para continuar.",
//                   style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
//                   textAlign: TextAlign.center,
//                 ),
//               ),

//             // Botón Final (Entrar a la App)
//             SizedBox(
//               width: double.infinity,
//               height: 55,
//               child: ElevatedButton(
//                 onPressed: _allPermissionsGranted ? _navigateToApp : null,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _allPermissionsGranted
//                       ? Colors.deepPurpleAccent
//                       : Colors.grey.shade800,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//                 child: Text(
//                   _allPermissionsGranted ? "CONTINUAR" : "PERMISOS PENDIENTES",
//                   style: TextStyle(
//                     color: _allPermissionsGranted
//                         ? Colors.white
//                         : Colors.grey.shade500,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 15),

//             // Botón de Ajustes (por si el usuario bloqueó permanentemente)
//             Center(
//               child: TextButton(
//                 onPressed: _openSettings,
//                 child: const Text(
//                   "Abrir configuración del sistema",
//                   style: TextStyle(color: Colors.grey, fontSize: 12),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPermissionCard({
//     required IconData icon,
//     required String title,
//     required String description,
//     required bool isGranted,
//     required VoidCallback onTap,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: isGranted ? Colors.green.withOpacity(0.1) : Colors.grey.shade900,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(
//           color: isGranted ? Colors.green : Colors.transparent,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(10),
//             decoration: BoxDecoration(
//               color: isGranted
//                   ? Colors.green.withOpacity(0.2)
//                   : Colors.grey.shade800,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(
//               icon,
//               color: isGranted ? Colors.green : Colors.grey,
//               size: 24,
//             ),
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.bold,
//                     fontSize: 16,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   description,
//                   style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
//                 ),
//               ],
//             ),
//           ),
//           if (isGranted)
//             const Icon(Icons.check_circle, color: Colors.green, size: 28)
//           else
//             ElevatedButton(
//               onPressed: onTap,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.deepPurpleAccent,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 8,
//                 ),
//               ),
//               child: const Text("Permitir", style: TextStyle(fontSize: 12)),
//             ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:grabadora/screens/recordi_a.dart'; // Asegúrate de que esta ruta sea correcta

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> {
  // Estados de los permisos
  bool _micGranted = false;
  bool _storageGranted = false;
  bool _notificationGranted = false; // NUEVO: Estado para notificaciones

  // Para prevenir múltiples clicks
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  // Verificar estado inicial al entrar
  Future<void> _checkInitialStatus() async {
    final mic = await Permission.microphone.status;
    final storage = await Permission.manageExternalStorage.status;
    final storageLegacy = await Permission.storage.status;
    final notifications = await Permission.notification.status; // NUEVO

    setState(() {
      _micGranted = mic.isGranted;
      _storageGranted = storage.isGranted || storageLegacy.isGranted;
      _notificationGranted = notifications.isGranted; // NUEVO
    });
  }

  // Verificar si todo está listo para habilitar el botón final
  // Ahora también requiere notificaciones
  bool get _allPermissionsGranted =>
      _micGranted && _storageGranted && _notificationGranted;

  // --- ACCIONES ---

  Future<void> _requestMic() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final status = await Permission.microphone.request();

    if (mounted) {
      setState(() {
        _micGranted = status.isGranted;
        _isProcessing = false;
      });
    }
  }

  Future<void> _requestStorage() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Pedimos ambos para cubrir Android antiguo y nuevo
    final statuses = await [
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();

    final storageOk = statuses[Permission.storage]?.isGranted ?? false;
    final manageOk =
        statuses[Permission.manageExternalStorage]?.isGranted ?? false;

    if (mounted) {
      setState(() {
        _storageGranted = storageOk || manageOk;
        _isProcessing = false;
      });
    }
  }

  // NUEVO: Acción para solicitar Notificaciones
  Future<void> _requestNotification() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final status = await Permission.notification.request();

    if (mounted) {
      setState(() {
        _notificationGranted = status.isGranted;
        _isProcessing = false;
      });
    }
  }

  void _openSettings() {
    openAppSettings().then((_) async {
      // Cuando el usuario vuelve de ajustes, verificamos de nuevo
      await _checkInitialStatus();
    });
  }

  void _navigateToApp() {
    if (_allPermissionsGranted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RecorderScreen()),
      );
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => SystemNavigator.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Configuración Inicial",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Para garantizar que la aplicación funcione correctamente, necesitamos acceso a los siguientes servicios:",
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 40),

            // Tarjeta Micrófono
            _buildPermissionCard(
              icon: Icons.mic,
              title: "Micrófono",
              description: "Necesario para grabar audios.",
              isGranted: _micGranted,
              onTap: _requestMic,
            ),

            const SizedBox(height: 20),

            // Tarjeta Almacenamiento
            _buildPermissionCard(
              icon: Icons.folder,
              title: "Almacenamiento",
              description: "Guarda archivos y accede a la SD.",
              isGranted: _storageGranted,
              onTap: _requestStorage,
            ),

            const SizedBox(height: 20),

            // NUEVA TARJETA: Notificaciones
            _buildPermissionCard(
              icon: Icons.notifications_active,
              title: "Notificaciones",
              description: "Muestra el control de grabación en segundo plano.",
              isGranted: _notificationGranted,
              onTap: _requestNotification,
            ),

            const SizedBox(height: 40),

            // Mensaje de advertencia si faltan permisos
            if (!_allPermissionsGranted)
              const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  "Debes activar todos los permisos para continuar.",
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),

            // Botón Final (Entrar a la App)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _allPermissionsGranted ? _navigateToApp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _allPermissionsGranted
                      ? Colors.deepPurpleAccent
                      : Colors.grey.shade800,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _allPermissionsGranted ? "CONTINUAR" : "PERMISOS PENDIENTES",
                  style: TextStyle(
                    color: _allPermissionsGranted
                        ? Colors.white
                        : Colors.grey.shade500,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Botón de Ajustes (por si el usuario bloqueó permanentemente)
            Center(
              child: TextButton(
                onPressed: _openSettings,
                child: const Text(
                  "Abrir configuración del sistema",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGranted ? Colors.green.withOpacity(0.1) : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? Colors.green : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isGranted ? Colors.green : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isGranted)
            const Icon(Icons.check_circle, color: Colors.green, size: 28)
          else
            ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text("Permitir", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
