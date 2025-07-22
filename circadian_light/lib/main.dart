import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/routines.dart';
import 'screens/settings.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();


}

class _MainAppState extends State<MainApp> {

  late final List<Widget> _screens;
  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const RoutinesScreen(),
      const SettingsScreen(),
    ];
  }
  int myIndex = 0;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        extendBody: true,
        body: _screens[myIndex],

        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              onTap: (index) => setState(() => myIndex = index),
              currentIndex: myIndex,
              showSelectedLabels: false,
              showUnselectedLabels: false,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'Routines',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 