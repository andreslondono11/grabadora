// package com.grabaplayer.co.grabadora

// import io.flutter.embedding.android.FlutterActivity

// class MainActivity : FlutterActivity()
package com.grabaplayer.co.grabadora
// CAMBIA ESTA LÍNEA POR TU PAQUETE REAL ENCONTRADO EN EL PASO 1


import android.content.ContentResolver
import android.os.Environment
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    
    // Asegúrate que este canal coincida con el que usas en Dart
    // Por defecto en el código que te di es 'com.tuapp.grabadora/storage'
    private val CHANNEL = "com.tuapp.grabadora/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            
            // DEBUG: Esto imprimirá en la consola 'Run' de VS Code / Android Studio
            Log.d("MAIN_ACTIVITY_DEBUG", "Canal invocado: ${call.method}")

            if (call.method == "moveFileUniversal") {
                val sourcePath = call.argument<String>("sourcePath")
                val targetPath = call.argument<String>("targetPath")

                Log.d("MAIN_ACTIVITY_DEBUG", "Origen: $sourcePath")
                Log.d("MAIN_ACTIVITY_DEBUG", "Destino: $targetPath")

                if (sourcePath != null && targetPath != null) {
                    val success = moveFileNative(sourcePath, targetPath)
                    if (success) {
                        Log.d("MAIN_ACTIVITY_DEBUG", "Movimiento EXITOSO")
                        result.success(true)
                    } else {
                        Log.e("MAIN_ACTIVITY_DEBUG", "Movimiento FALLÓ")
                        result.error("MOVE_FAILED", "Error moviendo archivo", null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Argumentos nulos", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun moveFileNative(sourcePath: String, targetPath: String): Boolean {
        return try {
            val source = File(sourcePath)
            val target = File(targetPath)

            // Crear directorios destino si no existen
            val parent = target.parentFile
            if (parent != null && !parent.exists()) {
                parent.mkdirs()
            }

            // COPIA BYTE A BYTE
            val fis = FileInputStream(source)
            val fos = FileOutputStream(target)
            
            val buffer = ByteArray(1024)
            var length: Int
            while (fis.read(buffer).also { length = it } > 0) {
                fos.write(buffer, 0, length)
            }
            
            fis.close()
            fos.close()

            // Intentar borrar el original
            val isDeleted = source.delete()
            Log.d("MAIN_ACTIVITY_DEBUG", "Original borrado: $isDeleted")

            // Notificar al sistema que cambió el archivo
            try {
                contentResolver.delete(android.net.Uri.fromFile(source), null, null)
            } catch (e: Exception) {
                Log.w("MAIN_ACTIVITY_DEBUG", "Error notificando MediaStore: $e")
            }
            
            true
        } catch (e: Exception) {
            Log.e("MAIN_ACTIVITY_DEBUG", "Excepción grave: ${e.message}")
            e.printStackTrace()
            false
        }
    }
}