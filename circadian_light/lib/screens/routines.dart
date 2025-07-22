import 'package:flutter/material.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text('hi this is routines screen'),
      ),
    );
  }
}