import 'dart:io';
import 'package:flutter/material.dart';
import 'package:grabadora/screens/tema.dart';
import 'package:provider/provider.dart'; // 1. Importar provider
import 'package:grabadora/screens/intro.dart';
import 'package:grabadora/screens/recordi_a.dart';
import 'package:share_plus/share_plus.dart';

// IMPORTANTE: Asegúrate de que ThemeProvider esté accesible.
// Si lo dejaste en 'recordi_a.dart', no necesitas importarlo aquí si usas MultiProvider o lo pasas,
// pero lo ideal es tenerlo en un archivo separado (ej. config/theme_provider.dart) o importarlo aquí.
// Asumiré que ThemeProvider está definido en 'recordi_a.dart' según el código anterior.
import 'package:grabadora/screens/recordi_a.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // 2. Crear y proveer la instancia del ThemeProvider
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Grabadora Pro Dark',
            debugShowCheckedModeBanner: false,

            // 3. Usamos el tema dinámico del provider
            theme: themeProvider.currentTheme,

            // Eliminamos la configuración estática de arriba, ya que 'currentTheme' maneja todo.
            // 'currentTheme' internamente decide si usar el esquema oscuro o claro.
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

// =========================================================================
// // MODELO DE DATOS PARA PERSISTENCIA
// // =========================================================================
// class Recording {
//   String path;
//   String name;
//   final String date;

//   Recording({required this.path, required this.name, required this.date});

//   Map<String, dynamic> toMap() => {'path': path, 'name': name, 'date': date};

//   factory Recording.fromMap(Map<String, dynamic> map) =>
//       Recording(path: map['path'], name: map['name'], date: map['date'] ?? '');
// }

// =========================================================================
// CLASE PARA ENVIAR Y GESTIONAR LAS GRABACIONES (ALMACENAMIENTO/COMPARTIR)
// =========================================================================
class AudioSenderService {
  /// Envía el archivo de audio usando las aplicaciones del dispositivo
  /// (WhatsApp, Gmail, Guardar en Archivos, etc.)
  static Future<void> sendAudioFile(
    BuildContext context,
    String filePath,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      _showSnackBar(context, "El archivo de audio no existe.");
      return;
    }

    try {
      // Obtenemos el nombre del archivo de la ruta completa
      final String fileName = filePath.split('/').last;

      // Despliega la hoja nativa para compartir el archivo o guardarlo en el dispositivo
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Te comparto mi grabación de audio: $fileName');
    } catch (e) {
      _showSnackBar(context, "Error al intentar enviar el archivo: $e");
    }
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
