import 'package:flutter/material.dart';

void main() {
  runApp(const CarPresenceApp());
}

class CarPresenceApp extends StatelessWidget {
  const CarPresenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('CAR PRESENCE'),
        ),
      ),
    );
  }
}
