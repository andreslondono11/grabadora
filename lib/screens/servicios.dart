// // import 'package:flutter/material.dart';
// // import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// // // EL NOMBRE DE ESTA CLASE ES MUY IMPORTANTE
// // class FloatingScreen extends StatelessWidget {
// //   const FloatingScreen({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     final size = MediaQuery.of(context).size;

// //     return Material(
// //       color: Colors.transparent,
// //       child: Container(
// //         width: size.width,
// //         height: size.height,
// //         alignment: Alignment.center,
// //         child: GestureDetector(
// //           onTap: () {
// //             // Al tocar la burbuja, cerramos el overlay y volvemos a la app
// //             FlutterOverlayWindow.closeOverlay();
// //           },
// //           child: Container(
// //             width: 60,
// //             height: 60,
// //             decoration: BoxDecoration(
// //               color: Colors.blueGrey[900], // 👈 burbuja en BlueGrey oscuro
// //               shape: BoxShape.circle,
// //               boxShadow: [
// //                 BoxShadow(
// //                   color: Colors.black.withOpacity(0.5),
// //                   blurRadius: 10,
// //                   spreadRadius: 2,
// //                 ),
// //               ],
// //               border: Border.all(color: Colors.white, width: 2),
// //             ),
// //             child: const Icon(Icons.mic, color: Colors.white, size: 30),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// import 'package:flutter/material.dart';
// import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// class FloatingScreen extends StatefulWidget {
//   const FloatingScreen({super.key});

//   @override
//   State<FloatingScreen> createState() => _FloatingScreenState();
// }

// class _FloatingScreenState extends State<FloatingScreen> {
//   // Dentro del initState de tu FloatingScreen (en floating_screen.dart):
//   bool _appIsRecording = false;

//   @override
//   void initState() {
//     super.initState();

//     // Escuchar lo que manda la app principal
//     FlutterOverlayWindow.overlayListener.listen((dynamic data) {
//       if (data == "started_recording") {
//         setState(() {
//           _appIsRecording = true;
//         });
//       } else if (data == "stopped_recording") {
//         setState(() {
//           _appIsRecording = false;
//         });
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors
//           .transparent, // Crucial para que no se vea un fondo cuadrado blanco/negro
//       child: Center(
//         // Envolvemos en Center para que el contenedor no se estire a toda la pantalla
//         child: Container(
//           width: 70, // Es buena práctica definir un tamaño fijo para la burbuja
//           height: 70,
//           decoration: BoxDecoration(
//             color: Colors.red[700],
//             shape: BoxShape.circle,
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.5),
//                 blurRadius: 10,
//                 spreadRadius: 2,
//               ),
//             ],
//             border: Border.all(color: Colors.white, width: 2),
//           ),
//           child: InkWell(
//             // InkWell o GestureDetector, pero InkWell da feedback visual de toque
//             customBorder: const CircleBorder(),
//             onTap: () async {
//               // 1. Notificar a la app principal ANTES de cerrar (por si el isolate se destruye rápido)
//               // Enviamos un mensaje simple que la app principal pueda capturar
//               await FlutterOverlayWindow.shareData("burbuja_cerrada");

//               // 2. Cerrar la burbuja visualmente
//               await FlutterOverlayWindow.closeOverlay();
//             },
//             child: const Icon(Icons.mic, color: Colors.white, size: 35),
//           ),
//         ),
//       ),
//     );
//   }
// }
