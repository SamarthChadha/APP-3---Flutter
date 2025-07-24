import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
// import 'package:flutter_gl/flutter_gl.dart';
// import 'package:flutter_3d_controller/'

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hi This is home Screen'),
            SizedBox(
              height: 400,
              width: 400,
            child: 
              Flutter3DViewer(src: 'assets/models/Textured_Lamp_Small.glb'),
            ),
          ],
        )
      ),
    );
  }
}