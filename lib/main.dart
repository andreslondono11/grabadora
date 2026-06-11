import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grabadora/screens/intro.dart'; // Asegúrate que SplashScreen esté aquí o ajusta

import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

// --------------------------------------------------------------------------
// IMPORTA AQUÍ TUS PANTALLAS Y CLASES DE PROYECTO
// --------------------------------------------------------------------------
import 'package:grabadora/screens/tema.dart';

// --------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ELIMINAMOS el registro porque tu versión del paquete no lo usa así

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Grabadora Pro PZ',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme,
            home: const SplashScreen(), // Asegúrate que SplashScreen existe
          );
        },
      ),
    );
  }
}
// --------------------------------------------------------------------------
// PANTALLA DE CARGA (SPLASH SCREEN)
// --------------------------------------------------------------------------
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _navigateToHome();
//   }

//   Future<void> _navigateToHome() async {
//     // Simula una carga o realiza comprobaciones iniciales (permisos, etc.)
//     await Future.delayed(const Duration(seconds: 2));

//     if (!mounted) return;

//     // Navega a tu pantalla principal (asegúrate de que RecorderScreen esté importada o accesible)
//     // Nota: En el código anterior, RecorderScreen estaba en 'recordi_a.dart'.
//     // Si ese archivo contiene la clase RecorderScreen, impórtalo arriba.
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const RecorderScreen(),
//         // Asegúrate de importar RecorderScreen o cambiarlo por tu pantalla principal real.
//         // Ejemplo: import 'package:grabadora/screens/recordi_a.dart';
//         // asumiendo que RecorderScreen está ahí.
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // Puedes poner tu logo aquí
//             Icon(Icons.mic, size: 80, color: theme.colorScheme.primary),
//             const SizedBox(height: 20),
//             Text('Grabadora Pro PZ', style: theme.textTheme.headlineMedium),
//             const SizedBox(height: 40),
//             const CircularProgressIndicator(color: Colors.blueGrey),
//           ],
//         ),
//       ),
//     );
//   }
// }

// --------------------------------------------------------------------------
// SERVICIO AUXILIAR: AUDIO SENDER
// --------------------------------------------------------------------------
/// Clase estática para gestionar el envío de archivos a otras apps
class AudioSenderService {
  /// Envía el archivo de audio usando las aplicaciones del dispositivo
  static Future<void> sendAudioFile(
    BuildContext context,
    String filePath,
  ) async {
    final file = File(filePath);

    // Verifica si el archivo existe antes de intentar compartirlo
    if (!await file.exists()) {
      if (context.mounted) {
        _showSnackBar(context, "El archivo de audio no existe.");
      }
      return;
    }

    try {
      // Obtenemos el nombre del archivo
      final String fileName = filePath.split(Platform.pathSeparator).last;

      // Comparte el archivo usando el sistema nativo (WhatsApp, Telegram, etc.)
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Aquí tienes mi grabación: $fileName');
    } catch (e) {
      debugPrint("Error compartiendo archivo: $e");
      if (context.mounted) {
        _showSnackBar(context, "Error al compartir: ${e.toString()}");
      }
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
