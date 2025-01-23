import 'package:flutter/material.dart';

final theme = ThemeData().copyWith(
  scaffoldBackgroundColor: Colors.white70,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.lightGreenAccent,
  ),
);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: theme,
      home: ,
    );
  }
}

