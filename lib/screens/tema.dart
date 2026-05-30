import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clase encargada de gestionar el estado del tema (Claro / Oscuro)
/// y persistir la elección del usuario.
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode;
  static const String _prefKey = 'is_dark_mode';

  ThemeProvider({bool isDarkMode = true}) : _isDarkMode = isDarkMode {
    _loadThemeFromPrefs();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeData get currentTheme {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  /// Carga la preferencia guardada al iniciar la app.
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_prefKey) ?? true;
    notifyListeners();
  }

  /// Cambia el tema y guarda el estado en SharedPreferences.
  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, _isDarkMode);
    notifyListeners();
  }

  // =========================================================================
  // DEFINICIÓN DE TEMAS
  // =========================================================================

  /// Tema Oscuro (Estilo Premium)
  static final ThemeData _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color de fondo principal de la app
    scaffoldBackgroundColor: Colors.black,

    colorScheme: const ColorScheme.dark(
      primary: Colors.deepPurpleAccent, // Color primario vibrante
      secondary: Colors.blueAccent, // Color secundario
      surface: Color(0xFF121212), // Color de tarjetas/listas (gris muy oscuro)
      onSurface: Colors.white, // Texto sobre tarjetas
      error: Colors.redAccent,
    ),

    // Estilo específico para las tarjetas
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E), // Gris oscuro para las tarjetas
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // Estilo de los iconos
    iconTheme: const IconThemeData(color: Colors.white),

    // Color de divisoria
    dividerColor: Colors.white24,

    // Estilo de la barra superior (AppBar)
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle:
          SystemUiOverlayStyle.light, // Iconos de estado blancos
    ),

    // Estilos de texto globales
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      labelSmall: TextStyle(color: Colors.grey),
    ),

    // Estilo de los botones elevados
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  /// Tema Claro
  static final ThemeData _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Fondo general (blanco grisáceo suave)
    scaffoldBackgroundColor: Colors.grey[50],

    colorScheme: ColorScheme.light(
      primary: Colors.deepPurpleAccent, // Mantenemos el acento vibrante
      secondary: Colors.deepPurple, // El púrpura oscuro para contraste
      surface: Colors.white, // Tarjetas blancas
      onSurface: Colors.black87, // Texto oscuro
      error: Colors.red,
    ),

    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    iconTheme: const IconThemeData(color: Colors.black87), // Iconos oscuros
    dividerColor: Colors.black12,

    appBarTheme: AppBarTheme(
      backgroundColor:
          Colors.grey[50], // Fondo del appBar igual que el scaffold
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark, // Iconos de estado oscuros
      iconTheme: const IconThemeData(color: Colors.black87),
      titleTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      labelSmall: TextStyle(color: Colors.grey),
    ),

    // Botones en modo claro
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurpleAccent, // Fondo púrpura
        foregroundColor: Colors.white, // Texto blanco
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
