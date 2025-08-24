import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:flutter/rendering.dart';

void main() {
  debugPaintSizeEnabled = false; 
  runApp(const ESGApp());
}

class ESGApp extends StatelessWidget {
  const ESGApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Score',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5C94F7), //0xFF5C94F7
        useMaterial3: true,
        fontFamily: 'HelveticaNeue', //
      ),
      home: const HomeScreen(),
    );
  }
}
