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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 55),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // const Text('Hi This is home Screen'),
              SizedBox(
                height: 250,
                child:
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationX(3.1416),
                    child: const Flutter3DViewer(src: 'assets/models/Textured_Lamp_Small.glb')
                    )
              ),
            ],
          ),
        ),
        
      ),
    );
  }
}